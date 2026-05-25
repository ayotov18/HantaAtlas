// WHO news RSS adapter (classification source).
//
// WHO retired the dedicated Disease Outbreak News RSS
// (www.who.int/feeds/entity/csr/don/en/rss.xml — now 404), so we pull the
// working global WHO news feed and map each entry to a country + emergency
// classification level. `classifyEmergency` keeps non-outbreak items at NONE,
// and the orchestrator takes the highest-severity item per (country, disease),
// so general news doesn't drown out real outbreak signals. Override with
// WHO_DON_FEED_URL if a dedicated DON feed returns.
//
// Deliberately minimal RSS parsing (no external XML library): the DON feed is
// stable and small. If the format changes we'll see it in the worker logs and
// can adapt.

import { detectCountry } from "../country-detection.js";
import type { EmergencyClassificationLevel } from "../alerts-classifier.js";
import { classifyEmergency } from "../alerts-classifier.js";

export interface WhoDonItem {
    title: string;
    link: string;
    pubDate: Date;
    description: string;
    countryISO: string | null;
    level: EmergencyClassificationLevel;
}

export class WhoDonAdapter {
    readonly sourceId = "who-don";
    readonly url = process.env.WHO_DON_FEED_URL ?? "https://www.who.int/rss-feeds/news-english.xml";

    async fetch(): Promise<WhoDonItem[]> {
        const res = await globalThis.fetch(this.url, {
            headers: {
                "user-agent": "HantaAtlas-worker/1.0 (+https://api.thehantaapp.com)",
                "accept": "application/rss+xml, application/xml, text/xml"
            }
        });
        if (!res.ok) {
            throw new Error(`WHO DON fetch failed: ${res.status} ${res.statusText}`);
        }
        const xml = await res.text();
        return parseDonRss(xml).map((raw) => {
            const country = detectCountry(raw.title, "WHO-DON");
            const level = classifyEmergency(raw.title, raw.description);
            return { ...raw, countryISO: country, level };
        });
    }
}

interface RawDonItem {
    title: string;
    link: string;
    pubDate: Date;
    description: string;
}

function parseDonRss(xml: string): RawDonItem[] {
    // Minimal RSS 2.0 parser. Splits on <item>...</item> and pulls the four
    // tags we care about. Robust enough for WHO's stable feed; intentionally
    // not a general-purpose parser.
    const items: RawDonItem[] = [];
    const itemRegex = /<item\b[\s\S]*?<\/item>/g;
    const matches = xml.match(itemRegex) ?? [];
    for (const block of matches) {
        const title = stripCdata(extract(block, "title"));
        const link = stripCdata(extract(block, "link"));
        const pubRaw = stripCdata(extract(block, "pubDate"));
        const description = stripCdata(extract(block, "description"));
        if (!title || !link) continue;
        const pubDate = pubRaw ? new Date(pubRaw) : new Date();
        items.push({ title, link, pubDate, description });
    }
    return items;
}

function extract(block: string, tag: string): string {
    const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`));
    return m ? m[1].trim() : "";
}

function stripCdata(s: string): string {
    return s.replace(/^<!\[CDATA\[/, "").replace(/\]\]>$/, "").trim();
}
