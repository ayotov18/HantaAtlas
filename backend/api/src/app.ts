import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import Fastify from "fastify";
import { PrismaClient } from "@prisma/client";
import { FixtureRepository, type SurveillanceRepository } from "./repository.js";
import { PrismaSignalsRepository } from "./prisma-repository.js";
import { registerAuthRoutes } from "./auth-routes.js";
import { registerPreferencesRoutes } from "./preferences-routes.js";
import { countrySnapshotSchema } from "./schemas.js";
import {
  fixtureAggregatesForDisease,
  fixtureSignalsForDisease,
  fixtureStatsForDisease,
  mergeAggregates,
  mergeSignals,
  mergeStats,
  normaliseDisease
} from "./fixtures.js";
import type { DiseaseId, MapMetric, Severity, SignalCategory, SignalDto, SignalTimeRange } from "./types.js";

export interface BuildAppDeps {
  repository?: SurveillanceRepository;
  prisma?: PrismaClient;
}

export function buildApp(deps: BuildAppDeps | SurveillanceRepository = {}) {
  // Backwards-compat: previous signature took the repository directly.
  const opts: BuildAppDeps =
    deps instanceof FixtureRepository ? { repository: deps } : (deps as BuildAppDeps);
  const repository = opts.repository ?? new FixtureRepository();

  // Eager Prisma init when DATABASE_URL is set. Required so auth routes
  // (which need prisma at app-build time) can register. Tests still
  // bypass it by passing `{ repository: fixture }` and no DATABASE_URL.
  //
  // Bug fix: previously `prisma` was lazily created only inside
  // `getSignals()` when the first signal request hit, but the auth
  // route registration ran at build time when `prisma` was still
  // null — so /v1/auth/* never got mounted in production (404).
  let prisma: PrismaClient | null = opts.prisma ?? null;
  if (!prisma && process.env.DATABASE_URL) {
    try {
      prisma = new PrismaClient();
    } catch {
      prisma = null;
    }
  }
  let signals: PrismaSignalsRepository | null = prisma ? new PrismaSignalsRepository(prisma) : null;
  function getSignals(): PrismaSignalsRepository | null {
    if (signals) return signals;
    if (!process.env.DATABASE_URL) return null;
    try {
      prisma = prisma ?? new PrismaClient();
      signals = new PrismaSignalsRepository(prisma);
      return signals;
    } catch {
      return null;
    }
  }
  function fixtureSignals(disease: DiseaseId, query: {
    country?: string;
    category?: SignalCategory;
    limit?: string | number;
    minSeverity?: Severity;
  }): SignalDto[] {
    let rows = fixtureSignalsForDisease(disease);
    if (query.country) {
      rows = rows.filter((signal) => signal.countryISO?.toLowerCase() === query.country?.toLowerCase());
    }
    if (query.category) {
      rows = rows.filter((signal) => signal.category === query.category);
    }
    if (query.minSeverity) {
      const rank = { LOW: 0, MEDIUM: 1, HIGH: 2 };
      rows = rows.filter((signal) => rank[signal.severity] >= rank[query.minSeverity as Severity]);
    }
    const rawLimit = query.limit ? Number(query.limit) : undefined;
    const limit = rawLimit && Number.isFinite(rawLimit) ? Math.max(1, Math.trunc(rawLimit)) : undefined;
    return typeof limit === "number" ? rows.slice(0, limit) : rows;
  }
  const app = Fastify({
    logger: {
      level: process.env.LOG_LEVEL ?? "info"
    },
    // Trust only the loopback reverse proxy (nginx). nginx is
    // configured to set X-Forwarded-For from the verified Cloudflare
    // Real-IP (CF-Connecting-IP), so request.ip is the real client.
    trustProxy: "127.0.0.1",
    // Cap inbound body. nginx already enforces 1 MB; double-defence here.
    bodyLimit: 256 * 1024
  });

  // CORS: explicit allowlist only. Default to no origins so a misconfigured
  // production env is blocked, not wildcarded. iOS (URLSession) does not
  // require CORS — only browser-based clients do.
  const corsRaw = process.env.CORS_ORIGIN ?? "";
  const corsOrigins = corsRaw
    .split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  void app.register(cors, {
    origin: corsOrigins.length === 0 ? false : corsOrigins,
    methods: ["GET", "HEAD", "OPTIONS"],
    credentials: false,
    maxAge: 86_400
  });

  // Hardening headers — defence in depth alongside the reverse proxy. Most
  // are also set by nginx, but duplicating them keeps the API safe if it is
  // ever exposed without a proxy in staging or local dev.
  app.addHook("onSend", async (_request, reply) => {
    reply.header("X-Content-Type-Options", "nosniff");
    reply.header("X-Frame-Options", "DENY");
    reply.header("Referrer-Policy", "no-referrer");
    reply.header("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
    if (process.env.NODE_ENV === "production") {
      reply.header("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload");
    }
  });

  void app.register(swagger, {
    openapi: {
      info: {
        title: "HantaAtlas API",
        version: "0.1.0",
        description: "Official-source outbreak surveillance API."
      }
    }
  });

  // Swagger UI is intentionally NOT registered in production. The
  // OpenAPI JSON is still available at /openapi.json for tooling.
  if (process.env.NODE_ENV !== "production") {
    void app.register(swaggerUi, {
      routePrefix: "/docs"
    });
  }

  // Expose the OpenAPI spec at /openapi.json for tooling. Default route
  // from @fastify/swagger is /documentation/json, which we shadow here.
  app.get("/openapi.json", async (request) => request.server.swagger());

  app.get("/health", async () => ({ status: "ok" }));
  app.get("/ready", async () => ({ status: "ready" }));

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/diseases", async () => repository.diseases());

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/summary", async (request) =>
    repository.summary(normaliseDisease(request.query.disease))
  );

  app.get<{
    Querystring: { metric?: MapMetric; disease?: DiseaseId | string };
  }>("/v1/map", async (request) => repository.map(request.query.metric ?? "confidence", normaliseDisease(request.query.disease)));

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/feed", async (request) =>
    repository.feed(normaliseDisease(request.query.disease))
  );

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/countries", async (request) =>
    repository.countries(normaliseDisease(request.query.disease))
  );

  app.get<{
    Params: { isoCode: string };
    Querystring: { disease?: DiseaseId | string };
  }>("/v1/countries/:isoCode", {
    schema: {
      response: {
        200: countrySnapshotSchema
      }
    }
  }, async (request, reply) => {
    const country = await repository.country(request.params.isoCode, normaliseDisease(request.query.disease));
    if (!country) {
      return reply.code(404).send({ error: "not_found", message: `No country found for ${request.params.isoCode}` });
    }
    return country;
  });

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/guide", async (request) =>
    repository.guide(normaliseDisease(request.query.disease))
  );
  app.get("/v1/app-config", async () => repository.appConfig());

  // ── Signals (live ingestion for Hantavirus, fixtures for Ebola v1) ────────
  // Paths are intentionally additive — legacy /v1/feed still serves the
  // OfficialAlert shape used by older app versions.

  app.get<{
    Querystring: {
      since?: SignalTimeRange;
      country?: string;
      category?: SignalCategory;
      limit?: string;
      disease?: DiseaseId | string;
    };
  }>("/v1/signals", async (request) => {
    const disease = normaliseDisease(request.query.disease);
    const s = getSignals();
    const opts = {
      range: request.query.since,
      country: request.query.country,
      category: request.query.category,
      limit: request.query.limit ? Number(request.query.limit) : undefined
    };
    if (!s) return disease === "hantavirus" ? [] : fixtureSignals(disease, request.query);
    if (disease === "ebola") {
      const live = (await s.hasAnyData("ebola")) ? await s.signals({ ...opts, disease: "ebola" }) : [];
      return live.length ? live : fixtureSignals("ebola", request.query);
    }
    if (disease === "hantavirus") {
      return (await s.hasAnyData("hantavirus")) ? await s.signals({ ...opts, disease: "hantavirus" }) : [];
    }
    // both: live across diseases; add Ebola fixtures only until Ebola ingests.
    const live = (await s.hasAnyData()) ? await s.signals({ ...opts, disease: "both" }) : [];
    return (await s.hasAnyData("ebola")) ? live : mergeSignals(live, fixtureSignals("ebola", request.query));
  });

  app.get<{
    Querystring: {
      days?: string;
      country?: string;
      category?: SignalCategory;
      minSeverity?: Severity;
      limit?: string;
      disease?: DiseaseId | string;
    };
  }>("/v1/signals/deck", async (request) => {
    const disease = normaliseDisease(request.query.disease);
    const s = getSignals();

    const rawDays = request.query.days ? Number(request.query.days) : 30;
    const days = Number.isFinite(rawDays) ? Math.max(1, Math.min(Math.trunc(rawDays), 90)) : 30;
    const sinceDate = new Date(Date.now() - days * 24 * 3600 * 1000);
    const opts = {
      sinceDate,
      country: request.query.country,
      category: request.query.category,
      minSeverity: request.query.minSeverity,
      limit: request.query.limit ? Number(request.query.limit) : 250,
      includeMedia: true
    };
    if (!s) return disease === "hantavirus" ? [] : fixtureSignals(disease, request.query);
    if (disease === "ebola") {
      const live = (await s.hasAnyData("ebola")) ? await s.signals({ ...opts, disease: "ebola" }) : [];
      return live.length ? live : fixtureSignals("ebola", request.query);
    }
    if (disease === "hantavirus") {
      return (await s.hasAnyData("hantavirus")) ? await s.signals({ ...opts, disease: "hantavirus" }) : [];
    }
    const live = (await s.hasAnyData()) ? await s.signals({ ...opts, disease: "both" }) : [];
    return (await s.hasAnyData("ebola")) ? live : mergeSignals(live, fixtureSignals("ebola", request.query));
  });

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/map-aggregates", async (request) => {
    const disease = normaliseDisease(request.query.disease);
    const s = getSignals();
    if (!s) return disease === "hantavirus" ? [] : fixtureAggregatesForDisease(disease);
    if (disease === "ebola") {
      const live = (await s.hasAnyData("ebola")) ? await s.aggregates("ebola") : [];
      return live.length ? live : fixtureAggregatesForDisease("ebola");
    }
    if (disease === "hantavirus") {
      return (await s.hasAnyData("hantavirus")) ? await s.aggregates("hantavirus") : [];
    }
    const live = (await s.hasAnyData()) ? await s.aggregates("both") : [];
    return (await s.hasAnyData("ebola")) ? live : mergeAggregates(live, fixtureAggregatesForDisease("ebola"));
  });

  app.get<{ Querystring: { disease?: DiseaseId | string } }>("/v1/stats", async (request) => {
    const disease = normaliseDisease(request.query.disease);
    const empty = {
      updatedAt: new Date().toISOString(),
      signalsTotal: 0,
      signalsLast30d: 0,
      countriesActive: 0,
      topSources: []
    };
    const s = getSignals();
    if (!s) return disease === "hantavirus" ? empty : fixtureStatsForDisease(disease);
    if (disease === "ebola") {
      return (await s.hasAnyData("ebola")) ? await s.stats("ebola") : fixtureStatsForDisease("ebola");
    }
    if (disease === "hantavirus") {
      return (await s.hasAnyData("hantavirus")) ? await s.stats("hantavirus") : empty;
    }
    const liveStats = (await s.hasAnyData()) ? await s.stats("both") : empty;
    return (await s.hasAnyData("ebola")) ? liveStats : mergeStats(liveStats, fixtureStatsForDisease("ebola"));
  });

  // Alerts feature — returns [] when worker hasn't yet populated, so the iOS
  // client can fall back to its on-device derivation cleanly.
  app.get<{ Querystring: { country?: string; disease?: DiseaseId | string } }>("/v1/alerts/classifications", async (request) => {
    const s = getSignals();
    if (!s) return [];
    return s.classifications({
      country: request.query.country,
      disease: normaliseDisease(request.query.disease)
    });
  });

  app.get<{ Querystring: { since?: string; country?: string; limit?: string; disease?: DiseaseId | string } }>(
    "/v1/alerts/changes",
    async (request) => {
      const s = getSignals();
      if (!s) return [];
      const since = request.query.since ? new Date(request.query.since) : undefined;
      return s.classificationChanges({
        since: since && !Number.isNaN(since.getTime()) ? since : undefined,
        country: request.query.country,
        limit: request.query.limit ? Number(request.query.limit) : undefined,
        disease: normaliseDisease(request.query.disease)
      });
    }
  );

  // Auth + per-user preferences routes — only mounted when we have a real
  // Prisma client (in tests / fixture-only mode we skip; both need the DB).
  if (prisma) {
    registerAuthRoutes(app, prisma);
    registerPreferencesRoutes(app, prisma);
  }

  app.addHook("onClose", async () => {
    if (prisma) await prisma.$disconnect();
  });

  return app;
}
