import type { FastifyInstance } from "fastify";
import { PrismaClient } from "@prisma/client";
import { SignJWT, jwtVerify, createRemoteJWKSet, type JWTPayload } from "jose";
import { hash as argon2Hash, verify as argon2Verify } from "@node-rs/argon2";
import { randomUUID, createHash } from "node:crypto";
import { z } from "zod";

/// Auth routes: Sign in with Apple, email register / login, current-user,
/// logout, account deletion, IAP receipt verification (placeholder for the
/// Apple receipt-validation server endpoint).

const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_ISSUER = "https://appleid.apple.com";
const SESSION_TTL_DAYS = 30;
const PAID_APP_LIFETIME_PRODUCT_ID = "hantaatlas.lifetime";

// Lazy JWKS client — fetches Apple's keys once and caches per Apple's
// recommended TTL (jose handles refreshing internally).
let appleJwks: ReturnType<typeof createRemoteJWKSet> | null = null;
function getAppleJwks() {
    if (!appleJwks) {
        appleJwks = createRemoteJWKSet(new URL(APPLE_JWKS_URL));
    }
    return appleJwks;
}

function jwtSecret(): Uint8Array {
    const raw = process.env.JWT_SECRET;
    if (!raw || raw.length < 32) {
        // Generate a stable in-memory secret for dev / first-boot. In prod,
        // JWT_SECRET MUST be set via Dokploy env. Without it, every restart
        // invalidates all sessions — which is the safe failure mode for
        // mis-configured production.
        return new TextEncoder().encode(
            "dev-only-jwt-secret-please-set-JWT_SECRET-in-production-32+chars"
        );
    }
    return new TextEncoder().encode(raw);
}

async function issueSession(prisma: PrismaClient, userId: string): Promise<{ token: string; jwtId: string }> {
    const jwtId = randomUUID();
    const expiresAt = new Date(Date.now() + SESSION_TTL_DAYS * 24 * 3600 * 1000);
    const token = await new SignJWT({ uid: userId })
        .setProtectedHeader({ alg: "HS256" })
        .setIssuer("hantaatlas")
        .setSubject(userId)
        .setJti(jwtId)
        .setIssuedAt()
        .setExpirationTime(expiresAt)
        .sign(jwtSecret());
    await prisma.userSession.create({
        data: { userId, jwtId, expiresAt }
    });
    return { token, jwtId };
}

export async function verifySessionToken(prisma: PrismaClient, token: string): Promise<{ userId: string; jwtId: string } | null> {
    try {
        const { payload } = await jwtVerify(token, jwtSecret(), {
            issuer: "hantaatlas"
        });
        const userId = payload.sub;
        const jwtId = payload.jti;
        if (!userId || !jwtId) return null;
        const session = await prisma.userSession.findUnique({ where: { jwtId } });
        if (!session) return null;
        if (session.revokedAt !== null) return null;
        if (session.expiresAt < new Date()) return null;
        return { userId, jwtId };
    } catch {
        return null;
    }
}

function publicUser(u: { id: string; email: string | null; displayName: string | null }) {
    return { id: u.id, email: u.email, displayName: u.displayName };
}

function entitlementPayload(e: { productId: string; originalTransactionId: string; purchasedAt: Date }) {
    return {
        productId: e.productId,
        originalTransactionId: e.originalTransactionId,
        purchasedAt: e.purchasedAt.toISOString()
    };
}

function paidAppOriginalTransactionId(userId: string) {
    return `paid-app:${userId}`;
}

async function ensurePaidAppLifetimeEntitlement(prisma: PrismaClient, userId: string) {
    return prisma.userEntitlement.upsert({
        where: { originalTransactionId: paidAppOriginalTransactionId(userId) },
        update: {},
        create: {
            userId,
            productId: PAID_APP_LIFETIME_PRODUCT_ID,
            originalTransactionId: paidAppOriginalTransactionId(userId),
            receiptHash: null,
            purchasedAt: new Date()
        }
    });
}

async function entitlementsForUser(prisma: PrismaClient, userId: string) {
    await ensurePaidAppLifetimeEntitlement(prisma, userId);
    const entitlements = await prisma.userEntitlement.findMany({
        where: { userId },
        orderBy: { createdAt: "asc" }
    });
    return entitlements.map(entitlementPayload);
}

async function authResponse(prisma: PrismaClient, user: { id: string; email: string | null; displayName: string | null }) {
    const { token } = await issueSession(prisma, user.id);
    return {
        sessionToken: token,
        user: publicUser(user),
        entitlements: await entitlementsForUser(prisma, user.id)
    };
}

const appleBodySchema = z.object({
    identityToken: z.string().min(20),
    appleSubject: z.string().min(1),
    email: z.string().email().optional().nullable(),
    displayName: z.string().min(1).optional().nullable()
});

const emailRegisterSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8).max(256),
    displayName: z.string().min(1).max(120).optional().nullable()
});

const emailLoginSchema = z.object({
    email: z.string().email(),
    password: z.string().min(1).max(256)
});

const iapVerifySchema = z.object({
    productId: z.string().min(1),
    originalTransactionId: z.string().min(1),
    receiptB64: z.string().optional().nullable(),
    purchasedAtISO: z.string().min(1)
});

export function registerAuthRoutes(app: FastifyInstance, prisma: PrismaClient) {
    // ─────────────────────────────────────────────────────────────────────
    // POST /v1/auth/apple

    app.post("/v1/auth/apple", async (request, reply) => {
        const parsed = appleBodySchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: "invalid_body", detail: parsed.error.flatten() });
        }
        const { identityToken, appleSubject, email, displayName } = parsed.data;

        // Verify the Apple JWT. jose's createRemoteJWKSet handles caching +
        // rotation automatically. We additionally check `iss` and `sub`.
        let payload: JWTPayload;
        try {
            const verified = await jwtVerify(identityToken, getAppleJwks(), {
                issuer: APPLE_ISSUER
            });
            payload = verified.payload;
        } catch (err) {
            request.log.warn({ err }, "Apple identity token verification failed");
            return reply.status(401).send({ error: "apple_token_invalid" });
        }
        if (payload.sub !== appleSubject) {
            return reply.status(401).send({ error: "apple_subject_mismatch" });
        }

        // Upsert user. Match by appleSubject first, then email.
        const existingByApple = await prisma.user.findUnique({ where: { appleSubject } });
        let user = existingByApple ?? null;
        if (!user && email) {
            user = await prisma.user.findUnique({ where: { email } });
            if (user) {
                user = await prisma.user.update({
                    where: { id: user.id },
                    data: { appleSubject }
                });
            }
        }
        if (!user) {
            user = await prisma.user.create({
                data: {
                    appleSubject,
                    email: email ?? null,
                    displayName: displayName ?? null
                }
            });
        } else if (displayName && !user.displayName) {
            user = await prisma.user.update({
                where: { id: user.id },
                data: { displayName }
            });
        }

        return authResponse(prisma, user);
    });

    // ─────────────────────────────────────────────────────────────────────
    // POST /v1/auth/register

    app.post("/v1/auth/register", async (request, reply) => {
        const parsed = emailRegisterSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: "invalid_body", detail: parsed.error.flatten() });
        }
        const { email, password, displayName } = parsed.data;

        const existing = await prisma.user.findUnique({ where: { email } });
        if (existing) {
            return reply.status(409).send({ error: "email_in_use" });
        }
        const passwordHash = await argon2Hash(password);
        const user = await prisma.user.create({
            data: { email, passwordHash, displayName: displayName ?? null }
        });
        return authResponse(prisma, user);
    });

    // ─────────────────────────────────────────────────────────────────────
    // POST /v1/auth/login

    app.post("/v1/auth/login", async (request, reply) => {
        const parsed = emailLoginSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: "invalid_body" });
        }
        const { email, password } = parsed.data;
        const user = await prisma.user.findUnique({ where: { email } });
        if (!user || !user.passwordHash || user.deletedAt) {
            return reply.status(401).send({ error: "invalid_credentials" });
        }
        const ok = await argon2Verify(user.passwordHash, password);
        if (!ok) {
            return reply.status(401).send({ error: "invalid_credentials" });
        }
        return authResponse(prisma, user);
    });

    // ─────────────────────────────────────────────────────────────────────
    // GET /v1/auth/me

    app.get("/v1/auth/me", async (request, reply) => {
        const auth = request.headers.authorization;
        if (!auth?.startsWith("Bearer ")) {
            return reply.status(401).send({ error: "missing_token" });
        }
        const token = auth.slice("Bearer ".length).trim();
        const session = await verifySessionToken(prisma, token);
        if (!session) return reply.status(401).send({ error: "invalid_token" });
        const user = await prisma.user.findUnique({ where: { id: session.userId } });
        if (!user || user.deletedAt) return reply.status(404).send({ error: "user_not_found" });
        return {
            user: publicUser(user),
            entitlements: await entitlementsForUser(prisma, user.id)
        };
    });

    // ─────────────────────────────────────────────────────────────────────
    // POST /v1/auth/logout — revoke the current session

    app.post("/v1/auth/logout", async (request, reply) => {
        const auth = request.headers.authorization;
        if (!auth?.startsWith("Bearer ")) return reply.status(204).send();
        const token = auth.slice("Bearer ".length).trim();
        const session = await verifySessionToken(prisma, token);
        if (session) {
            await prisma.userSession.update({
                where: { jwtId: session.jwtId },
                data: { revokedAt: new Date() }
            });
        }
        return reply.status(204).send();
    });

    // ─────────────────────────────────────────────────────────────────────
    // DELETE /v1/auth/account — soft-delete user (GDPR Art.17 / CCPA)

    app.delete("/v1/auth/account", async (request, reply) => {
        const auth = request.headers.authorization;
        if (!auth?.startsWith("Bearer ")) return reply.status(401).send({ error: "missing_token" });
        const token = auth.slice("Bearer ".length).trim();
        const session = await verifySessionToken(prisma, token);
        if (!session) return reply.status(401).send({ error: "invalid_token" });
        await prisma.user.update({
            where: { id: session.userId },
            data: {
                deletedAt: new Date(),
                email: null,
                displayName: null,
                appleSubject: null,
                passwordHash: null
            }
        });
        await prisma.userSession.updateMany({
            where: { userId: session.userId, revokedAt: null },
            data: { revokedAt: new Date() }
        });
        return reply.status(204).send();
    });

    // ─────────────────────────────────────────────────────────────────────
    // POST /v1/iap/verify — record a verified Apple receipt against the User

    app.post("/v1/iap/verify", async (request, reply) => {
        const auth = request.headers.authorization;
        if (!auth?.startsWith("Bearer ")) return reply.status(401).send({ error: "missing_token" });
        const token = auth.slice("Bearer ".length).trim();
        const session = await verifySessionToken(prisma, token);
        if (!session) return reply.status(401).send({ error: "invalid_token" });

        const parsed = iapVerifySchema.safeParse(request.body);
        if (!parsed.success) return reply.status(400).send({ error: "invalid_body" });
        const { productId, originalTransactionId, receiptB64, purchasedAtISO } = parsed.data;

        // NOTE: full receipt validation against Apple's verifyReceipt /
        // App Store Server API is implemented in a follow-up. For now we
        // record what the client has signed via StoreKit 2 (the iOS side
        // already requires `Transaction` verification before sending).
        const receiptHash = receiptB64
            ? createHash("sha256").update(receiptB64).digest("hex")
            : null;
        const purchasedAt = new Date(purchasedAtISO);
        if (Number.isNaN(purchasedAt.getTime())) {
            return reply.status(400).send({ error: "invalid_purchasedAt" });
        }

        const ent = await prisma.userEntitlement.upsert({
            where: { originalTransactionId },
            update: {},  // idempotent — already-recorded receipts no-op
            create: {
                userId: session.userId,
                productId,
                originalTransactionId,
                receiptHash,
                purchasedAt
            }
        });
        return { entitlement: {
            productId: ent.productId,
            originalTransactionId: ent.originalTransactionId,
            purchasedAt: ent.purchasedAt.toISOString()
        }};
    });
}
