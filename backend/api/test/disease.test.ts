import { describe, it, expect } from "vitest";
import type { PrismaClient } from "@prisma/client";
import { buildApp } from "../src/app.js";

// Minimal Prisma double that honours the `where.disease` filter for the
// signal + aggregate reads the disease-aware repository performs.
function makeFakePrisma(opts: {
    signals?: any[];
    aggregates?: any[];
} = {}) {
    const signals = opts.signals ?? [];
    const aggregates = opts.aggregates ?? [];

    const matchSignal = (where: any, s: any): boolean => {
        if (!where) return true;
        if (where.disease && s.disease !== where.disease) return false;
        if (where.countryISO && s.countryISO !== where.countryISO) return false;
        if (where.category && s.category !== where.category) return false;
        if (where.publishedAt?.gte && s.publishedAt < where.publishedAt.gte) return false;
        return true;
    };

    return {
        signal: {
            count: async ({ where }: any = {}) => signals.filter((s) => matchSignal(where, s)).length,
            findMany: async ({ where, take }: any = {}) => {
                const rows = signals
                    .filter((s) => matchSignal(where, s))
                    .sort((a, b) => b.publishedAt.getTime() - a.publishedAt.getTime());
                return take ? rows.slice(0, take) : rows;
            },
            findFirst: async ({ where }: any = {}) => signals.filter((s) => matchSignal(where, s))[0] ?? null,
            groupBy: async () => []
        },
        countrySignalAggregate: {
            findMany: async ({ where }: any = {}) =>
                aggregates.filter((a) => !where?.disease || a.disease === where.disease),
            count: async () => aggregates.length
        },
        countryClassification: { findMany: async () => [] },
        countryClassificationChange: { findMany: async () => [] },
        $disconnect: async () => {}
    } as unknown as PrismaClient;
}

function signalRow(over: Partial<Record<string, unknown>>) {
    return {
        id: "x", title: "t", summary: null, url: "https://e", sourceBucket: "WHO",
        publishedAt: new Date(), countryISO: "CD", disease: "ebola",
        category: "LOCAL", severity: "HIGH", postType: null,
        mediaType: null, mediaUrl: null, mediaThumbnailUrl: null, mediaProvider: null,
        mediaSourceUrl: null, mediaWidth: null, mediaHeight: null,
        ...over
    };
}

describe("disease-filtered signals", () => {
    const rows = [
        signalRow({ id: "h1", title: "Hantavirus cluster", countryISO: "AR", disease: "hantavirus" }),
        signalRow({ id: "e1", title: "Ebola outbreak DRC", countryISO: "CD", disease: "ebola" })
    ];

    it("serves live Ebola signals (not fixtures) when the DB has them", async () => {
        const app = buildApp({ prisma: makeFakePrisma({ signals: rows }) });
        const res = await app.inject({ method: "GET", url: "/v1/signals?disease=ebola" });
        expect(res.statusCode).toBe(200);
        const ids = res.json().map((s: any) => s.id);
        expect(ids).toEqual(["e1"]);          // only the ebola row, live
        await app.close();
    });

    it("scopes hantavirus to its own rows", async () => {
        const app = buildApp({ prisma: makeFakePrisma({ signals: rows }) });
        const res = await app.inject({ method: "GET", url: "/v1/signals?disease=hantavirus" });
        expect(res.json().map((s: any) => s.id)).toEqual(["h1"]);
        await app.close();
    });

    it("returns both diseases for disease=both", async () => {
        const app = buildApp({ prisma: makeFakePrisma({ signals: rows }) });
        const res = await app.inject({ method: "GET", url: "/v1/signals?disease=both" });
        const ids = res.json().map((s: any) => s.id).sort();
        expect(ids).toEqual(["e1", "h1"]);
        await app.close();
    });

    it("falls back to Ebola fixtures when the DB has no Ebola rows yet", async () => {
        // Only a hanta row in the DB → ebola request falls back to fixtures (non-empty).
        const app = buildApp({ prisma: makeFakePrisma({ signals: [rows[0]] }) });
        const res = await app.inject({ method: "GET", url: "/v1/signals?disease=ebola" });
        expect(res.statusCode).toBe(200);
        expect(res.json().length).toBeGreaterThan(0);   // fixture fallback
        await app.close();
    });
});

describe("disease-filtered map aggregates", () => {
    it("merges per-disease rows into one entry per country for disease=both", async () => {
        const aggregates = [
            { countryISO: "CD", disease: "ebola", last30dCount: 5, last6mCount: 5, last1yCount: 5, allTimeCount: 5, activeLevel: "ACTIVE", lastSignalAt: new Date() },
            { countryISO: "CD", disease: "hantavirus", last30dCount: 2, last6mCount: 2, last1yCount: 2, allTimeCount: 2, activeLevel: "RESPONSE", lastSignalAt: new Date() }
        ];
        const app = buildApp({ prisma: makeFakePrisma({ signals: [signalRow({ id: "e1" })], aggregates }) });
        const res = await app.inject({ method: "GET", url: "/v1/map-aggregates?disease=both" });
        const body = res.json();
        const cd = body.filter((a: any) => a.countryISO === "CD");
        expect(cd.length).toBe(1);                 // merged to one row
        expect(cd[0].last30dCount).toBe(7);        // 5 + 2
        expect(cd[0].activeLevel).toBe("ACTIVE");  // most severe wins
        await app.close();
    });

    it("scopes aggregates to Ebola only", async () => {
        const aggregates = [
            { countryISO: "CD", disease: "ebola", last30dCount: 5, last6mCount: 5, last1yCount: 5, allTimeCount: 5, activeLevel: "ACTIVE", lastSignalAt: new Date() },
            { countryISO: "AR", disease: "hantavirus", last30dCount: 2, last6mCount: 2, last1yCount: 2, allTimeCount: 2, activeLevel: "RESPONSE", lastSignalAt: new Date() }
        ];
        const app = buildApp({ prisma: makeFakePrisma({ signals: [signalRow({ id: "e1" })], aggregates }) });
        const res = await app.inject({ method: "GET", url: "/v1/map-aggregates?disease=ebola" });
        const isos = res.json().map((a: any) => a.countryISO);
        expect(isos).toEqual(["CD"]);
        await app.close();
    });
});
