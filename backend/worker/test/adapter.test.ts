import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { HantavirusMapFeedAdapter } from "../src/adapters/hantavirusmap-feed.js";

const sampleFeed = {
    title: "HantavirusMap — Hantavirus signals",
    items: [
        {
            id: "https://example/1",
            url: "https://news.example/1",
            title: "Health Ministry: 8 hantavirus cases confirmed in Argentina, 3 deaths",
            content_text: "An outbreak investigation in Patagonia continues.",
            date_published: "2026-05-08T11:44:03+00:00",
            tags: ["GoogleNews-en-AR", "hantavirus"],
            _hantavirusmap: { source: "GoogleNews-en-AR", virus: "hantavirus", locations: [] }
        },
        {
            id: "https://example/2",
            url: "https://news.example/2",
            title: "Travel advisory issued for return travellers from affected regions",
            date_published: "2026-05-08T10:00:00+00:00",
            tags: ["GoogleNews-en-US", "hantavirus"],
            _hantavirusmap: { source: "GoogleNews-en-US", virus: "hantavirus", locations: [] }
        }
    ]
};

describe("HantavirusMapFeedAdapter", () => {
    let originalFetch: typeof globalThis.fetch;

    beforeEach(() => {
        originalFetch = globalThis.fetch;
        globalThis.fetch = vi.fn(async () => new Response(JSON.stringify(sampleFeed), {
            status: 200,
            headers: { "Content-Type": "application/feed+json" }
        }));
    });

    afterEach(() => {
        globalThis.fetch = originalFetch;
    });

    it("normalises feed items into Signals", async () => {
        const result = await new HantavirusMapFeedAdapter().fetch();
        expect(result.signals).toHaveLength(2);
    });

    it("classifies a high-severity local case", async () => {
        const result = await new HantavirusMapFeedAdapter().fetch();
        const argentine = result.signals.find((s) => /argentina/i.test(s.title));
        expect(argentine).toBeDefined();
        expect(argentine!.category).toBe("LOCAL");
        expect(argentine!.severity).toBe("HIGH");
        expect(argentine!.countryISO).toBe("AR");
    });

    it("classifies travel advisory as RESPONSE", async () => {
        const result = await new HantavirusMapFeedAdapter().fetch();
        const advisory = result.signals.find((s) => /advisory/i.test(s.title));
        expect(advisory).toBeDefined();
        expect(advisory!.category).toBe("RESPONSE");
    });
});
