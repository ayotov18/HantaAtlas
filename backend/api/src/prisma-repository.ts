import { PrismaClient } from "@prisma/client";
import type {
    AppStatsDto,
    ClassificationChangeDto,
    CountryClassificationDto,
    CountrySignalAggregateDto,
    DiseaseId,
    Severity,
    SignalCategory,
    SignalDto,
    SignalTimeRange
} from "./types.js";

/**
 * Prisma-backed reads for live Signal data. Stateless aside from the shared
 * client. Falls back gracefully when tables are empty (worker hasn't run yet);
 * the caller decides whether to substitute fixtures.
 *
 * Every read accepts an optional `disease` filter. `undefined` / `"both"` reads
 * across diseases; a specific disease scopes the query so Ebola and Hantavirus
 * are served at parity from one code path.
 */
export class PrismaSignalsRepository {
    private static readonly DEFAULT_SIGNAL_LIMIT = 500;
    private static readonly MAX_SIGNAL_LIMIT = 5_000;

    constructor(private readonly prisma: PrismaClient) {}

    /// Prisma `where` fragment for a disease filter. `both`/undefined → no
    /// filter (read across diseases).
    private diseaseWhere(disease?: DiseaseId): { disease?: string } {
        return disease && disease !== "both" ? { disease } : {};
    }

    private rangeStart(range: SignalTimeRange): Date | undefined {
        const now = Date.now();
        switch (range) {
            case "30d": return new Date(now -  30 * 24 * 3600 * 1000);
            case "6m":  return new Date(now - 182 * 24 * 3600 * 1000);
            case "1y":  return new Date(now - 365 * 24 * 3600 * 1000);
            case "all": return undefined;
        }
    }

    async signals(opts: {
        range?: SignalTimeRange;
        sinceDate?: Date;
        country?: string;
        category?: SignalCategory;
        minSeverity?: Severity;
        limit?: number;
        includeMedia?: boolean;
        disease?: DiseaseId;
    } = {}): Promise<SignalDto[]> {
        const since = opts.sinceDate ?? this.rangeStart(opts.range ?? "1y");
        const requestedLimit = Number.isFinite(opts.limit)
            ? Math.trunc(opts.limit!)
            : PrismaSignalsRepository.DEFAULT_SIGNAL_LIMIT;
        const limit = Math.max(1, Math.min(requestedLimit, PrismaSignalsRepository.MAX_SIGNAL_LIMIT));
        const severityOrder: Severity[] = ["LOW", "MEDIUM", "HIGH"];
        const minSeverityIndex = opts.minSeverity ? severityOrder.indexOf(opts.minSeverity) : -1;
        const severityFilter = minSeverityIndex > 0
            ? { severity: { in: severityOrder.slice(minSeverityIndex) } }
            : {};

        const rows = await this.prisma.signal.findMany({
            where: {
                ...this.diseaseWhere(opts.disease),
                ...(since ? { publishedAt: { gte: since } } : {}),
                ...(opts.country ? { countryISO: opts.country.toUpperCase() } : {}),
                ...(opts.category ? { category: opts.category } : {}),
                ...severityFilter
            },
            orderBy: { publishedAt: "desc" },
            take: limit
        });

        return rows.map((r) => ({
            id: r.id,
            title: r.title,
            summary: r.summary,
            url: r.url,
            sourceBucket: r.sourceBucket,
            publishedAt: r.publishedAt.toISOString(),
            countryISO: r.countryISO,
            category: r.category,
            severity: r.severity,
            postType: r.postType,
            ...(opts.includeMedia ? {
                primaryMedia: r.mediaUrl ? {
                    type: r.mediaType ?? "IMAGE",
                    url: r.mediaUrl,
                    thumbnailUrl: r.mediaThumbnailUrl,
                    provider: r.mediaProvider,
                    sourceUrl: r.mediaSourceUrl,
                    width: r.mediaWidth,
                    height: r.mediaHeight
                } : null
            } : {})
        }));
    }

    private static readonly ACTIVE_LEVEL_RANK: Record<string, number> = {
        NONE: 0, RESPONSE: 1, IMPORTED: 2, ACTIVE: 3, ENDEMIC: 4
    };

    async aggregates(disease?: DiseaseId): Promise<CountrySignalAggregateDto[]> {
        const rows = await this.prisma.countrySignalAggregate.findMany({
            where: this.diseaseWhere(disease),
            orderBy: { last30dCount: "desc" }
        });

        // A specific disease has at most one row per country — pass through.
        if (disease && disease !== "both") {
            return rows.map((r) => ({
                countryISO: r.countryISO,
                last30dCount: r.last30dCount,
                last6mCount: r.last6mCount,
                last1yCount: r.last1yCount,
                allTimeCount: r.allTimeCount,
                activeLevel: r.activeLevel,
                lastSignalAt: r.lastSignalAt?.toISOString() ?? null
            }));
        }

        // "both": merge the per-disease rows back into one entry per country —
        // sum the counts, take the most severe activeLevel + latest signal.
        const merged = new Map<string, CountrySignalAggregateDto>();
        const rank = PrismaSignalsRepository.ACTIVE_LEVEL_RANK;
        for (const r of rows) {
            const prev = merged.get(r.countryISO);
            const lastSignalAt = r.lastSignalAt?.toISOString() ?? null;
            if (!prev) {
                merged.set(r.countryISO, {
                    countryISO: r.countryISO,
                    last30dCount: r.last30dCount,
                    last6mCount: r.last6mCount,
                    last1yCount: r.last1yCount,
                    allTimeCount: r.allTimeCount,
                    activeLevel: r.activeLevel,
                    lastSignalAt
                });
            } else {
                prev.last30dCount += r.last30dCount;
                prev.last6mCount += r.last6mCount;
                prev.last1yCount += r.last1yCount;
                prev.allTimeCount += r.allTimeCount;
                if ((rank[r.activeLevel] ?? 0) > (rank[prev.activeLevel] ?? 0)) prev.activeLevel = r.activeLevel;
                if (lastSignalAt && (!prev.lastSignalAt || lastSignalAt > prev.lastSignalAt)) prev.lastSignalAt = lastSignalAt;
            }
        }
        return [...merged.values()].sort((a, b) => b.last30dCount - a.last30dCount);
    }

    async stats(disease?: DiseaseId): Promise<AppStatsDto> {
        const since30 = this.rangeStart("30d")!;
        const dWhere = this.diseaseWhere(disease);

        const [total, last30, countriesActive, latest, topSourcesRaw] = await Promise.all([
            this.prisma.signal.count({ where: dWhere }),
            this.prisma.signal.count({ where: { ...dWhere, publishedAt: { gte: since30 } } }),
            this.prisma.countrySignalAggregate.count({ where: { ...dWhere, activeLevel: { not: "NONE" } } }),
            this.prisma.signal.findFirst({ where: dWhere, orderBy: { fetchedAt: "desc" }, select: { fetchedAt: true } }),
            this.prisma.signal.groupBy({
                by: ["sourceBucket"],
                where: dWhere,
                _count: { sourceBucket: true },
                orderBy: { _count: { sourceBucket: "desc" } },
                take: 5
            })
        ]);

        return {
            updatedAt: (latest?.fetchedAt ?? new Date()).toISOString(),
            signalsTotal: total,
            signalsLast30d: last30,
            countriesActive,
            topSources: topSourcesRaw.map((g: { sourceBucket: string; _count: { sourceBucket: number } }) => ({ bucket: g.sourceBucket, count: g._count.sourceBucket }))
        };
    }

    async hasAnyData(disease?: DiseaseId): Promise<boolean> {
        return (await this.prisma.signal.count({ where: this.diseaseWhere(disease) })) > 0;
    }

    // MARK: - Alerts (classifications + changes)

    async classifications(opts: { country?: string; disease?: DiseaseId } = {}): Promise<CountryClassificationDto[]> {
        const rows = await this.prisma.countryClassification.findMany({
            where: {
                ...this.diseaseWhere(opts.disease),
                ...(opts.country ? { countryISO: opts.country.toUpperCase() } : {})
            },
            orderBy: [{ level: "desc" }, { updatedAt: "desc" }]
        });
        return rows.map((r) => ({
            countryISO: r.countryISO,
            countryName: r.countryName,
            level: r.level,
            sourceOrganisation: r.sourceOrganisation,
            sourceUrl: r.sourceUrl,
            declaredAt: r.declaredAt.toISOString(),
            summary: r.summary
        }));
    }

    async classificationChanges(opts: { since?: Date; country?: string; limit?: number; disease?: DiseaseId } = {}): Promise<ClassificationChangeDto[]> {
        const limit = Math.max(1, Math.min(opts.limit ?? 50, 200));
        const rows = await this.prisma.countryClassificationChange.findMany({
            where: {
                ...this.diseaseWhere(opts.disease),
                ...(opts.since ? { changedAt: { gte: opts.since } } : {}),
                ...(opts.country ? { countryISO: opts.country.toUpperCase() } : {})
            },
            orderBy: { changedAt: "desc" },
            take: limit
        });
        return rows.map((r) => ({
            id: r.id,
            countryISO: r.countryISO,
            countryName: r.countryName,
            fromLevel: r.fromLevel,
            toLevel: r.toLevel,
            changedAt: r.changedAt.toISOString(),
            sourceOrganisation: r.sourceOrganisation,
            sourceUrl: r.sourceUrl
        }));
    }
}
