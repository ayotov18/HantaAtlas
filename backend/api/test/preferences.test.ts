import { describe, expect, it, beforeAll } from "vitest";
import { SignJWT } from "jose";
import type { PrismaClient } from "@prisma/client";
import { buildApp } from "../src/app.js";

// verifySessionToken reads JWT_SECRET via jwtSecret(); pin it before signing
// any token so the test-issued token verifies against the same key.
const TEST_SECRET = "test-jwt-secret-please-keep-32-plus-characters-long";
beforeAll(() => {
    process.env.JWT_SECRET = TEST_SECRET;
});

const USER_ID = "user_test_1";
const JWT_ID = "jwt_test_1";

async function signToken(opts: { sub?: string; jti?: string } = {}): Promise<string> {
    return new SignJWT({})
        .setProtectedHeader({ alg: "HS256" })
        .setIssuer("hantaatlas")
        .setSubject(opts.sub ?? USER_ID)
        .setJti(opts.jti ?? JWT_ID)
        .setIssuedAt()
        .setExpirationTime(new Date(Date.now() + 3600 * 1000))
        .sign(new TextEncoder().encode(TEST_SECRET));
}

// Minimal in-memory Prisma double — only the methods the preferences routes
// (and the shared verifySessionToken/requireUserId guard) touch.
function makeFakePrisma() {
    let prefsRow: Record<string, unknown> | null = null;
    return {
        userSession: {
            findUnique: async ({ where: { jwtId } }: { where: { jwtId: string } }) =>
                jwtId === JWT_ID
                    ? { jwtId, userId: USER_ID, revokedAt: null, expiresAt: new Date(Date.now() + 3600 * 1000) }
                    : null
        },
        user: {
            findUnique: async ({ where: { id } }: { where: { id: string } }) =>
                id === USER_ID ? { id: USER_ID, email: null, displayName: null, deletedAt: null } : null
        },
        userPreferences: {
            findUnique: async () => prefsRow,
            upsert: async ({ create, update }: { create: Record<string, unknown>; update: Record<string, unknown> }) => {
                prefsRow = { ...(prefsRow ?? create), ...(prefsRow ? update : create), updatedAt: new Date() };
                return prefsRow;
            }
        },
        $disconnect: async () => {}
    } as unknown as PrismaClient;
}

function validBody() {
    return {
        savedCountries: ["us", "AR", "us"],
        trackAllCountries: false,
        selectedDiseaseMode: "both",
        lastSelectedMetric: "confidence",
        officialNoticeAlerts: true,
        itineraryAlerts: true,
        trackedCountryCaseAlerts: true,
        trackedCountryNewsBurstAlerts: false,
        alertFrequency: "daily",
        minAlertLevel: "OUTBREAK",
        quietHoursEnabled: true,
        quietHoursStart: 22,
        quietHoursEnd: 7
    };
}

describe("preferences routes", () => {
    it("rejects requests without a bearer token", async () => {
        const app = buildApp({ prisma: makeFakePrisma() });
        const response = await app.inject({ method: "GET", url: "/v1/me/preferences" });
        expect(response.statusCode).toBe(401);
        expect(response.json().error).toBe("missing_token");
        await app.close();
    });

    it("stores and returns preferences, canonicalising saved countries", async () => {
        const app = buildApp({ prisma: makeFakePrisma() });
        const token = await signToken();

        const put = await app.inject({
            method: "PUT",
            url: "/v1/me/preferences",
            headers: { authorization: `Bearer ${token}` },
            payload: validBody()
        });
        expect(put.statusCode).toBe(200);
        const saved = put.json().preferences;
        // Uppercased + de-duped + sorted.
        expect(saved.savedCountries).toEqual(["AR", "US"]);
        expect(saved.alertFrequency).toBe("daily");
        expect(typeof saved.updatedAt).toBe("string");

        const get = await app.inject({
            method: "GET",
            url: "/v1/me/preferences",
            headers: { authorization: `Bearer ${token}` }
        });
        expect(get.statusCode).toBe(200);
        expect(get.json().exists).toBe(true);
        expect(get.json().preferences.minAlertLevel).toBe("OUTBREAK");
        await app.close();
    });

    it("returns defaults with exists=false before any profile is saved", async () => {
        const app = buildApp({ prisma: makeFakePrisma() });
        const token = await signToken();
        const get = await app.inject({
            method: "GET",
            url: "/v1/me/preferences",
            headers: { authorization: `Bearer ${token}` }
        });
        expect(get.statusCode).toBe(200);
        expect(get.json().exists).toBe(false);
        expect(get.json().preferences.selectedDiseaseMode).toBe("both");
        await app.close();
    });

    it("rejects an invalid body", async () => {
        const app = buildApp({ prisma: makeFakePrisma() });
        const token = await signToken();
        const bad = { ...validBody(), quietHoursStart: 99, minAlertLevel: "NOT_A_LEVEL" };
        const response = await app.inject({
            method: "PUT",
            url: "/v1/me/preferences",
            headers: { authorization: `Bearer ${token}` },
            payload: bad
        });
        expect(response.statusCode).toBe(400);
        expect(response.json().error).toBe("invalid_body");
        await app.close();
    });
});
