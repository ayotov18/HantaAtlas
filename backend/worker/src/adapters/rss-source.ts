// Generic RSS 2.0 + Atom adapter for hantavirus signals.
//
// Used by every "official aggregator" source we add to the worker:
// ECDC, CDC HAN, PAHO, ProMED, and any future RSS feed. Each concrete
// adapter is just a thin config wrapper around this base — feed URL,
// source bucket id, and an optional topic-filter regex applied to the
// title (because some feeds are general-disease, not hantavirus-only).
//
// We deliberately reuse the country-detection + post-type classifier from
// the existing pipeline so the new sources land in the same Signal table
// with the same fields the iOS map expects.

import { detectCountry } from "../country-detection.js";
import { classify, classifyPostType } from "../classifier.js";
import { detectDisease, type DiseaseTag } from "../disease-detection.js";
import type { NormalisedSignal } from "./hantavirusmap-feed.js";

export interface RssSourceConfig {
    sourceId: string;        // unique stable id, used in source-attribution
    sourceBucket: string;    // tag stored on the Signal row (e.g. "ECDC-CDT", "ProMED")
    feedUrl: string;
    /// Optional regex/keyword filter — applied to the item's title + summary
    /// before we ingest. Pass `undefined` to ingest every item (useful when
    /// the feed is already topic-scoped). For general-disease feeds (ECDC
    /// threats, ProMED), pass the union `TOPIC_FILTER_ANY` so we only ingest
    /// items mentioning a tracked disease.
    topicFilter?: RegExp;
    /// When set, every item from this feed is tagged with this disease (the
    /// feed is disease-scoped, e.g. a Google-News "ebola" search or the MEDISYS
    /// Ebola edition). When unset, each item's disease is inferred per-item via
    /// `detectDisease`, and items that match neither disease are dropped.
    forcedDisease?: DiseaseTag;
}

export class RssSourceAdapter {
    constructor(private readonly cfg: RssSourceConfig) {}

    get sourceId(): string { return this.cfg.sourceId; }
    get url(): string { return this.cfg.feedUrl; }

    async fetch(): Promise<NormalisedSignal[]> {
        const res = await globalThis.fetch(this.cfg.feedUrl, {
            headers: {
                "user-agent": "HantaAtlas-worker/1.0 (+https://api.thehantaapp.com)",
                "accept": "application/rss+xml, application/atom+xml, application/xml, text/xml"
            }
        });
        if (!res.ok) {
            throw new Error(`${this.cfg.sourceId} RSS fetch failed: ${res.status} ${res.statusText}`);
        }
        const xml = await res.text();
        const raw = parseFeed(xml);
        const filter = this.cfg.topicFilter;
        const matched = filter ? raw.filter((r) => filter.test(r.title + " " + (r.description ?? ""))) : raw;

        const signals: NormalisedSignal[] = [];
        for (const item of matched) {
            const summary = item.description ?? null;
            // Disease tag: forced for disease-scoped feeds, otherwise inferred
            // per item. A `null` inference (ambiguous / off-topic) drops the
            // item rather than mis-filing it under a disease.
            const disease = this.cfg.forcedDisease ?? detectDisease(item.title, summary, this.cfg.sourceBucket);
            if (!disease) continue;

            // Pass both title and description to country detection. WHO /
            // HealthMap / MEDISYS items frequently put the country name in
            // the body rather than the headline ("WHO confirms cluster" →
            // "...in Argentina's Río Negro province"); title-only matching
            // dropped these into the null-country bucket and the map UI
            // had nowhere to pin them.
            const countryISO = detectCountry(item.title, this.cfg.sourceBucket, summary);
            const { category, severity } = classify(item.title, summary ?? undefined);
            const postType = classifyPostType(item.title, summary, category);
            signals.push({
                id: `${this.cfg.sourceId}::${item.guid ?? item.link}`,
                title: item.title,
                summary,
                url: item.link,
                sourceBucket: this.cfg.sourceBucket,
                publishedAt: item.pubDate,
                countryISO,
                disease,
                category,
                severity,
                postType,
                raw: item
            });
        }
        return signals;
    }
}

interface RawItem {
    title: string;
    link: string;
    pubDate: Date;
    description: string | null;
    guid: string | null;
    mediaUrl: string | null;
    mediaThumbnailUrl: string | null;
    mediaType: string | null;
    mediaWidth: number | null;
    mediaHeight: number | null;
}

function parseFeed(xml: string): RawItem[] {
    // Tries RSS 2.0 first (<item>), then Atom (<entry>). Same minimal-but-
    // robust approach as the existing WHO DON adapter.
    const items: RawItem[] = [];
    const isAtom = /<feed[\s>]/i.test(xml) && !/<rss[\s>]/i.test(xml);
    const blockRegex = isAtom
        ? /<entry\b[\s\S]*?<\/entry>/g
        : /<item\b[\s\S]*?<\/item>/g;
    const matches = xml.match(blockRegex) ?? [];
    for (const block of matches) {
        const title = stripCdata(extract(block, "title"));
        const link = isAtom
            ? (extractAttr(block, "link", "href") ?? stripCdata(extract(block, "link")))
            : stripCdata(extract(block, "link"));
        const pubRaw = isAtom
            ? stripCdata(extract(block, "updated") || extract(block, "published"))
            : stripCdata(extract(block, "pubDate") || extract(block, "dc:date"));
        const description = stripCdata(
            extract(block, "description") || extract(block, "summary") || extract(block, "content")
        ) || null;
        const guid = stripCdata(extract(block, "guid") || extract(block, "id")) || null;
        const enclosureUrl = extractAttr(block, "enclosure", "url");
        const enclosureType = extractAttr(block, "enclosure", "type");
        const mediaContentUrl = extractAttr(block, "media:content", "url") ?? extractAttr(block, "content", "url");
        const mediaContentType = extractAttr(block, "media:content", "type") ?? extractAttr(block, "content", "type");
        const mediaThumbnailUrl = extractAttr(block, "media:thumbnail", "url") ?? extractAttr(block, "thumbnail", "url");
        const mediaWidth = parseOptionalInt(
            extractAttr(block, "media:content", "width") ?? extractAttr(block, "content", "width")
        );
        const mediaHeight = parseOptionalInt(
            extractAttr(block, "media:content", "height") ?? extractAttr(block, "content", "height")
        );
        if (!title || !link) continue;
        const pubDate = pubRaw ? new Date(pubRaw) : new Date();
        items.push({
            title,
            link,
            pubDate,
            description,
            guid,
            mediaUrl: mediaContentUrl ?? enclosureUrl ?? mediaThumbnailUrl,
            mediaThumbnailUrl,
            mediaType: mediaContentType ?? enclosureType,
            mediaWidth,
            mediaHeight
        });
    }
    return items;
}

function extract(block: string, tag: string): string {
    const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`));
    return m ? m[1].trim() : "";
}

function extractAttr(block: string, tag: string, attr: string): string | null {
    const escapedTag = tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const escapedAttr = attr.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const m = block.match(new RegExp(`<${escapedTag}[^>]*\\b${escapedAttr}\\s*=\\s*("([^"]+)"|'([^']+)'|([^\\s>]+))`, "i"));
    return m ? (m[2] ?? m[3] ?? m[4] ?? null) : null;
}

function stripCdata(s: string): string {
    return s.replace(/^<!\[CDATA\[/, "").replace(/\]\]>$/, "").trim();
}

function parseOptionalInt(raw: string | null): number | null {
    if (!raw) return null;
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
}
