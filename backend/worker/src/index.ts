import pino from "pino";
import { PrismaClient } from "@prisma/client";
import { HantavirusMapFeedAdapter } from "./adapters/hantavirusmap-feed.js";
import { WhoDonAdapter } from "./adapters/who-don.js";
import { RssSourceAdapter } from "./adapters/rss-source.js";
import { severityRank, type EmergencyClassificationLevel } from "./alerts-classifier.js";
import { detectCountry } from "./country-detection.js";
import {
    detectDisease,
    EBOLA_FILTER,
    HANTA_FILTER,
    TOPIC_FILTER_ANY,
    type DiseaseTag
} from "./disease-detection.js";
import {
    enrichSignalMedia,
    extractMediaFromRaw,
    type SignalMediaResult
} from "./media-enrichment.js";

const log = pino({ level: process.env.LOG_LEVEL ?? "info" });
const prisma = new PrismaClient();
const MEDIA_ENRICH_MAX_PER_RUN = Math.max(0, Number(process.env.MEDIA_ENRICH_MAX_PER_RUN ?? 40));
let mediaEnrichedThisRun = 0;

const adapter = new HantavirusMapFeedAdapter();
const whoDon = new WhoDonAdapter();

// Free public RSS sources, all hantavirus-filtered. Adding new ones is just
// a new entry in this array — the generic RssSourceAdapter handles parsing,
// country detection, classification, and post-type assignment. The country-
// detection step infers `countryISO` from item titles / summaries via the
// existing keyword table; regional sources help when an outbreak in a
// less-WHO-frequent country gets picked up by its regional authority before
// the global WHO Disease Outbreak News bulletin lands.
//
// **Topic filter**: the regex below stays the same — Hantaviridae is the
// only family we want from these generic-disease feeds. Note that some
// regions use different spellings (Portuguese: "hantavírus"; Hungarian:
// "hantavirál"). HPS = Hantavirus Pulmonary Syndrome; HCPS = Hantavirus
// Cardiopulmonary Syndrome; HFRS = Haemorrhagic Fever with Renal Syndrome.
// The species names cover the four big serotypes endemic to different
// continents.
//
// **Coverage we ship today**:
//
// Global / multi-region:
//   - ECDC-CDT       — EU/EEA Communicable Disease Threats Report (feed)
//   - PAHO           — Pan American Health Org news feed (Americas)
//   - ProMED         — global member-curated outbreak digest
//   - HealthMap      — academic disease-news aggregator (covers languages /
//                      regions both ECDC and ProMED miss; Tier 2 per the
//                      OSINT proposal in the project notes)
//   - MEDISYS        — EU JRC multilingual media-surveillance system, with
//                      a hantavirus-specific topic feed (HANT). Different
//                      cadence and language coverage from ECDC + ProMED.
//
// National / regional health authority alerts:
//   - CDC HAN        — US Health Alert Network
//   - Africa CDC     — African Union public-health agency news feed
//                      (fills the major Africa gap in WHO DON cadence)
//   - WHO EMRO       — WHO Regional Office for the Eastern Mediterranean
//   - WHO SEARO      — WHO Regional Office for South-East Asia
//   - MoH Argentina  — Argentina hosts the highest density of Andes-virus
//                      hantavirus cases globally; the Ministry of Health
//                      issues regional bulletins long before they reach
//                      WHO DON
//   - MoH Chile      — second-highest Andes-virus burden country
//   - MoH Brazil     — sporadic but recurring HPS clusters in rural
//                      south/southeast regions
//
// All feeds parse as RSS 2.0 or Atom (the adapter sniffs the format). Each
// source URL is env-var-overrideable so we can swap when a publisher
// changes their feed path without redeploying code — and so an operator
// can disable a flaky feed by setting its env var to an empty string,
// which the filter below drops.
//
// Disease scoping: general feeds use the union `TOPIC_FILTER_ANY` and infer
// each item's disease via `detectDisease`; disease-scoped feeds (declared with
// `disease`) use that disease's filter and force-tag every item. The
// per-disease keyword filters live in `disease-detection.ts`.

interface RssSourceConfig {
    sourceId: string;
    sourceBucket: string;
    defaultUrl: string;
    envKey: string;
    /// Some sources are already topic-scoped (e.g. MEDISYS's HANT/EBOL alert
    /// editions, or a Google-News disease search, publish only on-topic items,
    /// so re-filtering would drop items we want). Setting this to false
    /// bypasses the topic filter for that source.
    applyTopicFilter?: boolean;
    /// When set, the feed is disease-scoped: items are tagged with this disease
    /// and the topic filter (when applied) is that disease's filter. When unset
    /// the feed is general — it ingests either disease via the union filter and
    /// `RssSourceAdapter` infers each item's disease per-item.
    disease?: DiseaseTag;
}

const rssSourceConfigs: RssSourceConfig[] = [
    // ── Global / multi-region aggregators ─────────────────────────────────
    {
        sourceId:     "ecdc-cdt",
        sourceBucket: "ECDC-CDT",
        defaultUrl:   "https://www.ecdc.europa.eu/en/taxonomy/term/65000/feed",
        envKey:       "ECDC_CDT_FEED_URL"
    },
    {
        sourceId:     "paho",
        sourceBucket: "PAHO",
        defaultUrl:   "https://www.paho.org/en/rss.xml",
        envKey:       "PAHO_FEED_URL"
    },
    {
        // WHO global news (English). The dedicated Disease Outbreak News RSS
        // was retired; this general feed is the working WHO source and, via
        // the union filter + per-item detectDisease, contributes both Ebola
        // and Hantavirus signals.
        sourceId:     "who-news",
        sourceBucket: "WHO",
        defaultUrl:   "https://www.who.int/rss-feeds/news-english.xml",
        envKey:       "WHO_NEWS_FEED_URL"
    },
    {
        sourceId:     "promed",
        sourceBucket: "ProMED",
        defaultUrl:   "https://promedmail.org/feed/",
        envKey:       "PROMED_FEED_URL"
    },
    {
        // HealthMap aggregates disease news across hundreds of sources in
        // multiple languages. Covers regional outbreaks that take days to
        // reach WHO DON. Tier-2 per the OSINT proposal in the project
        // notes; ingested as MEDIA_SIGNAL (the classifier defaults to that
        // for non-government feeds).
        sourceId:     "healthmap",
        sourceBucket: "HealthMap",
        defaultUrl:   "https://www.healthmap.org/getAlerts.php?range=30&search=hantavirus&output=rss",
        envKey:       "HEALTHMAP_FEED_URL",
        disease:      "hantavirus"   // URL is hantavirus-scoped
    },
    {
        // MEDISYS publishes per-disease alert editions; this URL is the
        // hantavirus-specific feed ("HANT") in English. The feed is
        // already topic-scoped, so we bypass our global TOPIC_FILTER for
        // this source so we don't drop items whose titles use only the
        // English short-form ("Hanta", or species-only names).
        sourceId:        "medisys-hant",
        sourceBucket:    "MEDISYS",
        defaultUrl:      "https://medisys.newsbrief.eu/medisys/alertedition/disease/HANT/en/.xml",
        envKey:          "MEDISYS_FEED_URL",
        applyTopicFilter: false,
        disease:          "hantavirus"
    },

    // ── Ebola OSINT sources ────────────────────────────────────────────────
    // Disease-scoped feeds: query-based aggregators + an open-news layer, so
    // Ebola gets the same breadth of coverage as Hantavirus. WHO DON, ProMED,
    // ECDC, PAHO, Africa CDC and the WHO regional offices are general feeds
    // (declared below / above without a `disease`) and pick up Ebola items via
    // the union topic filter + per-item disease inference.
    {
        // HealthMap, scoped to Ebola.
        sourceId:     "healthmap-ebola",
        sourceBucket: "HealthMap",
        defaultUrl:   "https://www.healthmap.org/getAlerts.php?range=30&search=ebola&output=rss",
        envKey:       "HEALTHMAP_EBOLA_FEED_URL",
        disease:      "ebola"
    },
    {
        // MEDISYS Ebola alert edition (EBOL). Pre-scoped — bypass the filter.
        sourceId:        "medisys-ebol",
        sourceBucket:    "MEDISYS",
        defaultUrl:      "https://medisys.newsbrief.eu/medisys/alertedition/disease/EBOL/en/.xml",
        envKey:          "MEDISYS_EBOLA_FEED_URL",
        applyTopicFilter: false,
        disease:          "ebola"
    },
    {
        // ReliefWeb — UN OCHA humanitarian reporting, Ebola-scoped. Strong for
        // DRC/Uganda/Guinea field updates that precede WHO DON.
        sourceId:     "reliefweb-ebola",
        sourceBucket: "ReliefWeb",
        // ReliefWeb 406s API requests without an `appname` identifier.
        defaultUrl:   "https://reliefweb.int/updates/rss.xml?search=ebola&appname=thehantaapp.com",
        envKey:       "RELIEFWEB_EBOLA_FEED_URL",
        applyTopicFilter: false,
        disease:          "ebola"
    },
    {
        // Open-news layer (English): Google News RSS search, recency-bounded.
        // The broadest OSINT net — local outlets that never reach official
        // channels. Classified MEDIA_SIGNAL by the post-type classifier.
        sourceId:        "googlenews-ebola-en",
        sourceBucket:    "GoogleNews-Ebola",
        defaultUrl:      "https://news.google.com/rss/search?q=ebola%20outbreak%20when%3A30d&hl=en-US&gl=US&ceid=US:en",
        envKey:          "GOOGLENEWS_EBOLA_EN_FEED_URL",
        applyTopicFilter: false,
        disease:          "ebola"
    },
    {
        // Open-news layer (French): the major Ebola-endemic states (DRC,
        // Guinea) report first in French; this catches them before the
        // English wires pick them up.
        sourceId:        "googlenews-ebola-fr",
        sourceBucket:    "GoogleNews-Ebola-FR",
        defaultUrl:      "https://news.google.com/rss/search?q=%C3%A9pid%C3%A9mie%20ebola%20when%3A30d&hl=fr&gl=FR&ceid=FR:fr",
        envKey:          "GOOGLENEWS_EBOLA_FR_FEED_URL",
        applyTopicFilter: false,
        disease:          "ebola"
    },

    // ── National / regional health authority alerts ───────────────────────
    {
        sourceId:     "cdc-han",
        sourceBucket: "CDC-HAN",
        defaultUrl:   "https://emergency.cdc.gov/han/han_rss.xml",
        envKey:       "CDC_HAN_FEED_URL"
    },
    {
        // Africa CDC — the African Union's public-health agency. Closes the
        // largest regional gap in WHO DON cadence. Hantavirus cases in
        // Africa (mostly Dobrava/Belgrade-virus exposures in Central Europe
        // travellers returning through African transit hubs) are rare but
        // historically under-reported in WHO DON's first week.
        sourceId:     "africa-cdc",
        sourceBucket: "Africa-CDC",
        defaultUrl:   "https://africacdc.org/feed/",
        envKey:       "AFRICA_CDC_FEED_URL"
    },
    {
        // WHO Eastern Mediterranean Regional Office. Picks up clusters
        // in countries whose Ministries of Health route through EMRO before
        // global WHO DON.
        sourceId:     "who-emro",
        sourceBucket: "WHO-EMRO",
        defaultUrl:   "https://www.emro.who.int/rss-feeds/news/index.xml",
        envKey:       "WHO_EMRO_FEED_URL"
    },
    {
        // WHO South-East Asia Regional Office. Covers Bangladesh, India,
        // Indonesia, Myanmar, Thailand — Seoul-virus and Thailand-virus
        // serotype regions.
        sourceId:     "who-searo",
        sourceBucket: "WHO-SEARO",
        defaultUrl:   "https://www.who.int/southeastasia/rss-feeds/news",
        envKey:       "WHO_SEARO_FEED_URL"
    },
    {
        // Argentina hosts the world's highest sustained Andes-virus
        // hantavirus case rate. The Ministerio de Salud publishes regional
        // case bulletins (especially Patagonia clusters) well before they
        // reach WHO DON or PAHO general news.
        sourceId:     "moh-ar",
        sourceBucket: "MoH-Argentina",
        defaultUrl:   "https://www.argentina.gob.ar/salud/comunicacion/feed",
        envKey:       "MOH_AR_FEED_URL"
    },
    {
        // Chile — second-highest Andes-virus burden globally. MINSAL
        // publishes weekly Epidemiología y Vigilancia notes.
        sourceId:     "moh-cl",
        sourceBucket: "MoH-Chile",
        defaultUrl:   "https://www.minsal.cl/feed/",
        envKey:       "MOH_CL_FEED_URL"
    },
    {
        // Brazil — sporadic but recurring HPS clusters in rural south /
        // southeast regions. Ministério da Saúde news feed.
        sourceId:     "moh-br",
        sourceBucket: "MoH-Brazil",
        defaultUrl:   "https://www.gov.br/saude/pt-br/assuntos/noticias/RSS",
        envKey:       "MOH_BR_FEED_URL"
    }
];

/// Resolve each config to an active `RssSourceAdapter`. Setting an env var
/// to the empty string `""` disables that source without requiring a code
/// change — useful when a publisher's feed is briefly down and we want to
/// stop logging failure warnings until it's back. Sources with the empty
/// string are filtered out here.
const rssSources = rssSourceConfigs
    .map((cfg) => {
        const url = process.env[cfg.envKey] ?? cfg.defaultUrl;
        if (!url || url.trim() === "") return null;
        // Disease-scoped feed → that disease's filter; general feed → the
        // union filter so it catches either disease (then per-item inference).
        // `applyTopicFilter: false` bypasses filtering for pre-scoped feeds.
        const topicFilter = cfg.applyTopicFilter === false
            ? undefined
            : cfg.disease === "ebola" ? EBOLA_FILTER
            : cfg.disease === "hantavirus" ? HANTA_FILTER
            : TOPIC_FILTER_ANY;
        return new RssSourceAdapter({
            sourceId:      cfg.sourceId,
            sourceBucket:  cfg.sourceBucket,
            feedUrl:       url,
            topicFilter,
            forcedDisease: cfg.disease
        });
    })
    .filter((adapter): adapter is RssSourceAdapter => adapter !== null);

/**
 * Retroactively detect a country for signals already in the DB whose
 * `countryISO` is null. Runs once per worker tick, capped at 1 000 rows
 * to keep the tick from ballooning. Within a few ticks every historic
 * null-country row is processed.
 *
 * Background: `detectCountry()` was tightened in this commit's parent
 * (53ebfff — description-aware matching, national-source fallback,
 * broader alias table). Rows ingested before that deploy carry the old
 * detection result, so a one-time backfill is needed to bring them up
 * to date. Rather than ship a separate one-shot script the operator
 * has to SSH in and run, the backfill rides inside the regular worker
 * tick: it's idempotent (signals whose `countryISO` is already set are
 * never touched), self-terminating (once no null-country rows remain
 * the function does no work), and bounded (BATCH_SIZE = 1 000 per
 * tick).
 *
 * The function NEVER writes a null over an existing non-null code —
 * detection failures leave the row as-is. So this is strictly an
 * additive pass; it can't regress data.
 */
async function backfillNullCountries(): Promise<void> {
    const BATCH_SIZE = 1_000;
    const candidates = await prisma.signal.findMany({
        where: { countryISO: null },
        select: { id: true, title: true, summary: true, sourceBucket: true },
        take: BATCH_SIZE,
        orderBy: { publishedAt: "desc" }
    });
    if (candidates.length === 0) return;

    let updated = 0;
    for (const row of candidates) {
        const detected = detectCountry(row.title, row.sourceBucket, row.summary);
        if (!detected) continue;
        try {
            await prisma.signal.update({
                where: { id: row.id },
                data: { countryISO: detected }
            });
            updated += 1;
        } catch (err) {
            log.warn({ err, id: row.id }, "country backfill update failed (non-fatal)");
        }
    }
    log.info(
        { scanned: candidates.length, updated, batchSize: BATCH_SIZE },
        "country backfill pass"
    );
}

/**
 * Reconcile the `disease` tag on existing signals against their own content.
 *
 * Background: a signal's disease is set at ingest — forced for disease-scoped
 * feeds, inferred via `detectDisease` for general feeds. But `Signal.disease`
 * carries a Prisma `@default("hantavirus")`, so any historical row created by
 * a code path that omitted `disease` was silently stored as Hantavirus. That
 * was the GoogleNews-Ebola ingest bug (the RSS upsert's `create` block didn't
 * set `disease`): Ebola headlines landed under Hantavirus. The forward fix
 * only self-heals rows whose source feed re-serves them — open-news items roll
 * out of the publisher's window within days and are never re-fetched, so they
 * stay mis-filed and surface Ebola stories in the Hantavirus feed forever.
 *
 * This pass re-derives each row's disease from its title + summary with the
 * same `detectDisease` classifier the ingest path uses, and corrects the
 * column only when BOTH hold: the classifier is confident (non-null) and the
 * currently-stored disease has *no* supporting keyword anywhere in the text.
 * That second guard means we only ever rewrite a row that was mis-defaulted —
 * a genuinely disease-scoped row (its own disease's keyword present, even in a
 * cross-mention) is left untouched, so we never override a legitimate forced
 * tag. Idempotent (a row that already agrees is never rewritten), bounded at
 * 1 000 rows/tick like the country backfill, newest-first so the user-visible
 * feed reconciles first. Runs before `recomputeAggregates`, so corrected rows
 * roll up into the right per-(country,disease) aggregate the same tick.
 */
async function backfillDiseaseTags(): Promise<void> {
    const BATCH_SIZE = 1_000;
    const candidates = await prisma.signal.findMany({
        select: { id: true, title: true, summary: true, disease: true },
        take: BATCH_SIZE,
        orderBy: { publishedAt: "desc" }
    });
    if (candidates.length === 0) return;

    let corrected = 0;
    for (const row of candidates) {
        const detected = detectDisease(row.title, row.summary);
        if (!detected || detected === row.disease) continue;
        // Only correct a mis-defaulted tag — never override a tag the content
        // itself supports. If the stored disease's keywords appear at all, the
        // row is plausibly a real (forced) assignment, so leave it alone.
        const storedFilter = row.disease === "ebola" ? EBOLA_FILTER : HANTA_FILTER;
        if (storedFilter.test(`${row.title} ${row.summary ?? ""}`)) continue;
        try {
            await prisma.signal.update({
                where: { id: row.id },
                data: { disease: detected }
            });
            corrected += 1;
        } catch (err) {
            log.warn({ err, id: row.id }, "disease backfill update failed (non-fatal)");
        }
    }
    log.info(
        { scanned: candidates.length, corrected, batchSize: BATCH_SIZE },
        "disease backfill pass"
    );
}

async function recomputeAggregates(): Promise<void> {
    const now = new Date();
    const since30d = new Date(now.getTime() - 30 * 24 * 3600 * 1000);
    const since6m  = new Date(now.getTime() - 182 * 24 * 3600 * 1000);
    const since1y  = new Date(now.getTime() - 365 * 24 * 3600 * 1000);

    // Pull all distinct (country, disease) pairs that have at least one signal,
    // so Ebola and Hantavirus carry independent per-country rollups.
    const pairs = await prisma.signal.findMany({
        where: { countryISO: { not: null } },
        select: { countryISO: true, disease: true },
        distinct: ["countryISO", "disease"]
    });

    for (const { countryISO, disease } of pairs) {
        if (!countryISO) continue;
        const base = { countryISO, disease };

        const [last30, last6m, last1y, all, latest] = await Promise.all([
            prisma.signal.count({ where: { ...base, publishedAt: { gte: since30d } } }),
            prisma.signal.count({ where: { ...base, publishedAt: { gte: since6m  } } }),
            prisma.signal.count({ where: { ...base, publishedAt: { gte: since1y  } } }),
            prisma.signal.count({ where: base }),
            prisma.signal.findFirst({
                where: base,
                orderBy: { publishedAt: "desc" },
                select: { publishedAt: true, category: true }
            })
        ]);

        // Determine activeLevel by precedence — most severe wins.
        let level: "ENDEMIC" | "ACTIVE" | "IMPORTED" | "RESPONSE" | "NONE" = "NONE";
        const recentLocal    = await prisma.signal.findFirst({ where: { ...base, category: "LOCAL",    publishedAt: { gte: since30d } } });
        const recentImported = await prisma.signal.findFirst({ where: { ...base, category: "IMPORTED", publishedAt: { gte: since30d } } });
        const recentResponse = await prisma.signal.findFirst({ where: { ...base, category: "RESPONSE", publishedAt: { gte: since30d } } });

        if      (recentLocal)    level = "ACTIVE";
        else if (recentImported) level = "IMPORTED";
        else if (recentResponse) level = "RESPONSE";

        await prisma.countrySignalAggregate.upsert({
            where: { countryISO_disease: { countryISO, disease } },
            create: {
                countryISO,
                disease,
                last30dCount: last30,
                last6mCount: last6m,
                last1yCount: last1y,
                allTimeCount: all,
                activeLevel: level,
                lastSignalAt: latest?.publishedAt ?? null
            },
            update: {
                last30dCount: last30,
                last6mCount: last6m,
                last1yCount: last1y,
                allTimeCount: all,
                activeLevel: level,
                lastSignalAt: latest?.publishedAt ?? null
            }
        });
    }

    // Drop rollups no longer backed by any signal. The upsert loop above only
    // visits (country, disease) pairs that currently have signals, so a pair
    // that lost all of them — e.g. a country whose only "Hantavirus" rows were
    // re-tagged to Ebola by `backfillDiseaseTags` — would otherwise keep its
    // stale rollup and stay lit on the wrong disease's map. Deleting orphans
    // here keeps the map in lock-step with the signal table.
    const validKeys = new Set(
        pairs.filter((p) => p.countryISO).map((p) => `${p.countryISO}::${p.disease}`)
    );
    const existingAggregates = await prisma.countrySignalAggregate.findMany({
        select: { countryISO: true, disease: true }
    });
    for (const a of existingAggregates) {
        if (validKeys.has(`${a.countryISO}::${a.disease}`)) continue;
        try {
            await prisma.countrySignalAggregate.delete({
                where: { countryISO_disease: { countryISO: a.countryISO, disease: a.disease } }
            });
        } catch (err) {
            log.warn({ err, countryISO: a.countryISO, disease: a.disease }, "orphan aggregate delete failed (non-fatal)");
        }
    }
}

/// Pull WHO DON, group by country, take the highest-severity classification
/// per country, upsert into CountryClassification. If the level changed vs
/// what's currently stored, write an audit row to CountryClassificationChange
/// (drives the iOS Alerts inbox + local-notification scheduling).
async function refreshClassificationsFromWho(): Promise<void> {
    const items = await whoDon.fetch();
    log.info({ count: items.length }, "WHO DON items fetched");

    // Group by (country, disease): a WHO DON is tagged Ebola when its text
    // matches the Ebola filter, otherwise it falls into the default
    // (hantavirus) bucket — preserving the prior behaviour where non-Ebola
    // DONs surface under the default disease while Ebola gets its own track.
    const byKey = new Map<string, { iso: string; disease: DiseaseTag; item: typeof items[number] }>();
    for (const item of items) {
        if (!item.countryISO) continue;
        const disease: DiseaseTag = EBOLA_FILTER.test(`${item.title} ${item.description}`)
            ? "ebola"
            : "hantavirus";
        const key = `${item.countryISO}::${disease}`;
        const existing = byKey.get(key);
        if (!existing || severityRank(item.level) > severityRank(existing.item.level)) {
            byKey.set(key, { iso: item.countryISO, disease, item });
        }
    }

    for (const { iso, disease, item } of byKey.values()) {
        const previous = await prisma.countryClassification.findUnique({
            where: { countryISO_disease: { countryISO: iso, disease } }
        });
        const previousLevel: EmergencyClassificationLevel = previous?.level ?? "NONE";

        await prisma.countryClassification.upsert({
            where: { countryISO_disease: { countryISO: iso, disease } },
            create: {
                countryISO: iso,
                disease,
                countryName: item.title,  // best available; backend has no country-name table yet
                level: item.level,
                sourceOrganisation: "WHO",
                sourceUrl: item.link,
                declaredAt: item.pubDate,
                summary: item.description.slice(0, 500)
            },
            update: {
                level: item.level,
                sourceOrganisation: "WHO",
                sourceUrl: item.link,
                declaredAt: item.pubDate,
                summary: item.description.slice(0, 500)
            }
        });

        if (previousLevel !== item.level) {
            await prisma.countryClassificationChange.create({
                data: {
                    countryISO: iso,
                    disease,
                    countryName: item.title,
                    fromLevel: previousLevel,
                    toLevel: item.level,
                    sourceOrganisation: "WHO",
                    sourceUrl: item.link
                }
            });
        }
    }
}

async function mediaUpdateForSignal(s: {
    id: string;
    url: string;
    raw: unknown;
}): Promise<Record<string, unknown>> {
    const rawMedia = extractMediaFromRaw(s.raw, s.url);
    if (rawMedia) return mediaToPrismaData(rawMedia);

    const existing = await prisma.signal.findUnique({
        where: { id: s.id },
        select: { mediaFetchedAt: true, mediaStatus: true }
    });
    if (existing?.mediaFetchedAt && existing.mediaStatus !== "FAILED") {
        return {};
    }
    if (mediaEnrichedThisRun >= MEDIA_ENRICH_MAX_PER_RUN) {
        return {};
    }

    mediaEnrichedThisRun += 1;
    const media = await enrichSignalMedia(s.url, s.raw);
    return mediaToPrismaData(media);
}

function mediaToPrismaData(media: SignalMediaResult): Record<string, unknown> {
    return {
        mediaType: media.type,
        mediaUrl: media.url,
        mediaThumbnailUrl: media.thumbnailUrl,
        mediaProvider: media.provider,
        mediaSourceUrl: media.sourceUrl,
        mediaWidth: media.width,
        mediaHeight: media.height,
        mediaFetchedAt: new Date(),
        mediaStatus: media.status
    };
}

try {
    log.info({ url: adapter.url }, "fetching feed");
    const result = await adapter.fetch();
    log.info({ count: result.signals.length, sourceId: result.sourceId }, "feed fetched");

    let inserted = 0;
    let skipped = 0;
    for (const s of result.signals) {
        try {
            const mediaData = await mediaUpdateForSignal(s);
            await prisma.signal.upsert({
                where: { id: s.id },
                create: {
                    id: s.id,
                    title: s.title,
                    summary: s.summary,
                    url: s.url,
                    sourceBucket: s.sourceBucket,
                    publishedAt: s.publishedAt,
                    countryISO: s.countryISO,
                    disease: s.disease,
                    category: s.category,
                    severity: s.severity,
                    postType: s.postType,
                    ...mediaData,
                    raw: s.raw as object
                },
                update: {
                    // Keep existing classification; only refresh title/summary
                    // in case the upstream changed. PostType is also refreshed
                    // on every tick so legacy rows (postType=null) get
                    // backfilled the first time the worker sees them again.
                    title: s.title,
                    summary: s.summary,
                    disease: s.disease,
                    postType: s.postType,
                    ...mediaData
                }
            });
            inserted += 1;
        } catch (err) {
            log.warn({ err, id: s.id }, "signal upsert failed");
            skipped += 1;
        }
    }
    log.info({ inserted, skipped }, "primary feed signals upserted");

    // Pull additional public RSS sources. Each is best-effort: a single feed
    // outage doesn't fail the whole run, and any fetch error is logged + the
    // run continues with whatever it already has.
    for (const src of rssSources) {
        try {
            const items = await src.fetch();
            log.info({ source: src.sourceId, count: items.length }, "rss source fetched");
            for (const s of items) {
                try {
                    const mediaData = await mediaUpdateForSignal(s);
                    await prisma.signal.upsert({
                        where: { id: s.id },
                        create: {
                            id: s.id,
                            title: s.title,
                            summary: s.summary,
                            url: s.url,
                            sourceBucket: s.sourceBucket,
                            publishedAt: s.publishedAt,
                            countryISO: s.countryISO,
                            disease: s.disease,
                            category: s.category,
                            severity: s.severity,
                            postType: s.postType,
                            ...mediaData,
                            raw: s.raw as object
                        },
                        update: {
                            title: s.title,
                            summary: s.summary,
                            disease: s.disease,
                            postType: s.postType,
                            ...mediaData
                        }
                    });
                } catch (err) {
                    log.warn({ err, id: s.id, source: src.sourceId }, "rss signal upsert failed");
                }
            }
        } catch (err) {
            log.warn({ err, source: src.sourceId, url: src.url }, "rss source fetch failed (non-fatal)");
        }
    }

    // Reconcile the disease tag on rows mis-defaulted to Hantavirus before the
    // ingest path set `disease` explicitly (e.g. the GoogleNews-Ebola rows that
    // surfaced Ebola stories under the Hantavirus feed). Runs every tick,
    // idempotent, capped at 1 000 rows; corrects only mis-defaulted tags.
    try {
        await backfillDiseaseTags();
    } catch (err) {
        log.warn({ err }, "disease backfill pass failed (non-fatal)");
    }

    // Retroactively re-detect country for any null-countryISO rows still
    // in the DB. Runs every tick, idempotent, capped at 1 000 rows per
    // tick. Eventually drains every legacy row left from before the
    // description-aware detection in 53ebfff.
    try {
        await backfillNullCountries();
    } catch (err) {
        log.warn({ err }, "country backfill pass failed (non-fatal)");
    }

    await recomputeAggregates();
    log.info("aggregates refreshed");

    // Pull WHO DON RSS and update country classifications + audit log.
    // Best-effort: any failure here is logged but doesn't fail the whole run,
    // because the signal-side of the pipeline is independent.
    try {
        await refreshClassificationsFromWho();
        log.info("classifications refreshed from WHO DON");
    } catch (err) {
        log.warn({ err }, "WHO DON classification refresh failed (non-fatal)");
    }
} catch (err) {
    log.error({ err }, "worker run failed");
    process.exitCode = 1;
} finally {
    await prisma.$disconnect();
}
