// Pulls https://hantavirusmap.com/feed.json (JSON Feed 1.1) and normalises
// each item into a Signal record. Designed for Type=oneshot use behind a
// systemd timer (see infra/systemd/hantaatlas-worker.timer).

import { detectCountry } from "../country-detection.js";
import { classify, classifyPostType, type SignalPostType } from "../classifier.js";
import type { DiseaseTag } from "../disease-detection.js";

export interface NormalisedSignal {
    id: string;
    title: string;
    summary: string | null;
    url: string;
    sourceBucket: string;
    publishedAt: Date;
    countryISO: string | null;
    disease: DiseaseTag;
    category: "LOCAL" | "IMPORTED" | "RESPONSE" | "MEDIA";
    severity: "LOW" | "MEDIUM" | "HIGH";
    postType: SignalPostType;
    raw: unknown;
}

export interface FeedFetchResult {
    sourceId: string;
    fetchedAt: Date;
    signals: NormalisedSignal[];
}

interface FeedItem {
    id: string;
    url: string;
    title: string;
    content_text?: string;
    summary?: string;
    date_published: string;
    tags?: string[];
    _hantavirusmap?: {
        source?: string;
        virus?: string;
        locations?: Array<{ iso?: string; country?: string }>;
    };
}

interface FeedRoot {
    title?: string;
    items?: FeedItem[];
}

export class HantavirusMapFeedAdapter {
    readonly sourceId = "hantavirusmap-feed";
    readonly url = process.env.HANTAVIRUSMAP_FEED_URL ?? "https://hantavirusmap.com/feed.json";

    async fetch(): Promise<FeedFetchResult> {
        const res = await globalThis.fetch(this.url, {
            headers: {
                "user-agent": "HantaAtlas-worker/1.0 (+https://api.thehantaapp.com)",
                "accept": "application/feed+json, application/json"
            }
        });
        if (!res.ok) {
            throw new Error(`feed fetch failed: ${res.status} ${res.statusText}`);
        }
        const json = (await res.json()) as FeedRoot;
        const items = json.items ?? [];

        const signals: NormalisedSignal[] = items.map((it) => {
            const sourceBucket = it._hantavirusmap?.source ?? (it.tags ?? [])[0] ?? "unknown";
            const summary = it.summary ?? it.content_text ?? null;

            // Prefer explicit ISO codes from the feed; fall back to title heuristic.
            let countryISO: string | null = null;
            const ihm = it._hantavirusmap;
            if (ihm?.locations && ihm.locations.length > 0) {
                const first = ihm.locations.find((l) => l.iso) ?? ihm.locations[0];
                if (first?.iso) countryISO = first.iso.toUpperCase();
            }
            if (!countryISO) {
                countryISO = detectCountry(it.title, sourceBucket);
            }

            const { category, severity } = classify(it.title, summary ?? undefined);
            const postType = classifyPostType(it.title, summary, category);

            return {
                id: it.id,
                title: it.title,
                summary,
                url: it.url,
                sourceBucket,
                publishedAt: new Date(it.date_published),
                countryISO,
                // The hantavirusmap.com feed is, by definition, hantavirus-only.
                disease: "hantavirus" as DiseaseTag,
                category,
                severity,
                postType,
                raw: it
            };
        });

        return {
            sourceId: this.sourceId,
            fetchedAt: new Date(),
            signals
        };
    }
}
