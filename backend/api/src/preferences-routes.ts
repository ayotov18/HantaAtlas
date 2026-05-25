import type { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import { PrismaClient } from "@prisma/client";
import { z } from "zod";
import { verifySessionToken } from "./auth-routes.js";

/// Per-user preferences sync: GET / PUT /v1/me/preferences. Backs the iOS
/// contextual-auth feature — saved countries + personalization/alert settings
/// follow the signed-in account across devices. Storage is `UserPreferences`
/// (1:1 with User). Last-write-wins on `updatedAt`; the client decides whether
/// to push local up (first sign-in to an empty profile) or pull server down.

const ISO_CODE = z.string().regex(/^[A-Za-z]{2}$/);

// Full-replace (PUT) body — the client always holds and sends the complete
// preference set. Enum-like strings mirror the iOS raw values exactly.
const preferencesSchema = z.object({
    savedCountries: z.array(ISO_CODE).max(500),
    trackAllCountries: z.boolean(),
    selectedDiseaseMode: z.enum(["both", "hantavirus", "ebola"]),
    lastSelectedMetric: z.enum(["confidence", "cases", "alerts"]),
    officialNoticeAlerts: z.boolean(),
    itineraryAlerts: z.boolean(),
    trackedCountryCaseAlerts: z.boolean(),
    trackedCountryNewsBurstAlerts: z.boolean(),
    alertFrequency: z.enum(["realtime", "daily", "weekly", "off"]),
    minAlertLevel: z.enum([
        "NONE",
        "ADVISORY",
        "OUTBREAK",
        "NATIONAL_EMERGENCY",
        "INTERNATIONAL_CONCERN"
    ]),
    quietHoursEnabled: z.boolean(),
    quietHoursStart: z.number().int().min(0).max(23),
    quietHoursEnd: z.number().int().min(0).max(23)
});

type PreferencesInput = z.infer<typeof preferencesSchema>;

// Server-side defaults — must match the Prisma model + iOS LocalPreferences
// defaults. `updatedAt: null` signals "no server profile yet" so the client
// knows to push its local prefs up on first sign-in.
function defaultPreferences() {
    return {
        savedCountries: [] as string[],
        trackAllCountries: false,
        selectedDiseaseMode: "both",
        lastSelectedMetric: "confidence",
        officialNoticeAlerts: true,
        itineraryAlerts: true,
        trackedCountryCaseAlerts: true,
        trackedCountryNewsBurstAlerts: true,
        alertFrequency: "realtime",
        minAlertLevel: "ADVISORY",
        quietHoursEnabled: false,
        quietHoursStart: 22,
        quietHoursEnd: 7,
        updatedAt: null as string | null
    };
}

function publicPreferences(p: {
    savedCountries: string[];
    trackAllCountries: boolean;
    selectedDiseaseMode: string;
    lastSelectedMetric: string;
    officialNoticeAlerts: boolean;
    itineraryAlerts: boolean;
    trackedCountryCaseAlerts: boolean;
    trackedCountryNewsBurstAlerts: boolean;
    alertFrequency: string;
    minAlertLevel: string;
    quietHoursEnabled: boolean;
    quietHoursStart: number;
    quietHoursEnd: number;
    updatedAt: Date;
}) {
    return {
        savedCountries: p.savedCountries,
        trackAllCountries: p.trackAllCountries,
        selectedDiseaseMode: p.selectedDiseaseMode,
        lastSelectedMetric: p.lastSelectedMetric,
        officialNoticeAlerts: p.officialNoticeAlerts,
        itineraryAlerts: p.itineraryAlerts,
        trackedCountryCaseAlerts: p.trackedCountryCaseAlerts,
        trackedCountryNewsBurstAlerts: p.trackedCountryNewsBurstAlerts,
        alertFrequency: p.alertFrequency,
        minAlertLevel: p.minAlertLevel,
        quietHoursEnabled: p.quietHoursEnabled,
        quietHoursStart: p.quietHoursStart,
        quietHoursEnd: p.quietHoursEnd,
        updatedAt: p.updatedAt.toISOString()
    };
}

// Canonicalise saved ISO codes: uppercase + dedupe + stable order, so two
// devices that saved the same set in different casing/order converge.
function normaliseSavedCountries(codes: string[]): string[] {
    return Array.from(new Set(codes.map((c) => c.toUpperCase()))).sort();
}

export function registerPreferencesRoutes(app: FastifyInstance, prisma: PrismaClient) {
    // Resolve the bearer token to a live, non-deleted user. Sends the error
    // response and returns null on failure so the caller can early-return.
    async function requireUserId(request: FastifyRequest, reply: FastifyReply): Promise<string | null> {
        const auth = request.headers.authorization;
        if (!auth?.startsWith("Bearer ")) {
            reply.status(401).send({ error: "missing_token" });
            return null;
        }
        const token = auth.slice("Bearer ".length).trim();
        const session = await verifySessionToken(prisma, token);
        if (!session) {
            reply.status(401).send({ error: "invalid_token" });
            return null;
        }
        const user = await prisma.user.findUnique({ where: { id: session.userId } });
        if (!user || user.deletedAt) {
            reply.status(404).send({ error: "user_not_found" });
            return null;
        }
        return session.userId;
    }

    // ─────────────────────────────────────────────────────────────────────
    // GET /v1/me/preferences — returns the user's prefs, or defaults if the
    // profile has none yet (exists=false tells the client to push local up).

    app.get("/v1/me/preferences", async (request, reply) => {
        const userId = await requireUserId(request, reply);
        if (!userId) return;
        const row = await prisma.userPreferences.findUnique({ where: { userId } });
        if (!row) {
            return { preferences: defaultPreferences(), exists: false };
        }
        return { preferences: publicPreferences(row), exists: true };
    });

    // ─────────────────────────────────────────────────────────────────────
    // PUT /v1/me/preferences — full-replace upsert of the user's prefs.

    app.put("/v1/me/preferences", async (request, reply) => {
        const userId = await requireUserId(request, reply);
        if (!userId) return;

        const parsed = preferencesSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: "invalid_body", detail: parsed.error.flatten() });
        }
        const data: PreferencesInput = parsed.data;
        const savedCountries = normaliseSavedCountries(data.savedCountries);
        const fields = { ...data, savedCountries };

        const row = await prisma.userPreferences.upsert({
            where: { userId },
            update: fields,
            create: { userId, ...fields }
        });
        return { preferences: publicPreferences(row), exists: true };
    });
}
