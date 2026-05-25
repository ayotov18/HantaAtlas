-- User accounts + sessions + per-user entitlements for the auth feature.

CREATE TABLE "User" (
    "id"             TEXT          NOT NULL,
    "email"          TEXT,
    "displayName"    TEXT,
    "appleSubject"   TEXT,
    "passwordHash"   TEXT,
    "createdAt"      TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"      TIMESTAMP(3)  NOT NULL,
    "deletedAt"      TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
CREATE UNIQUE INDEX "User_appleSubject_key" ON "User"("appleSubject");
CREATE INDEX "User_appleSubject_idx" ON "User"("appleSubject");
CREATE INDEX "User_email_idx" ON "User"("email");

CREATE TABLE "UserSession" (
    "id"                   TEXT         NOT NULL,
    "userId"               TEXT         NOT NULL,
    "jwtId"                TEXT         NOT NULL,
    "deviceInstallationId" TEXT,
    "createdAt"            TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt"            TIMESTAMP(3) NOT NULL,
    "revokedAt"            TIMESTAMP(3),

    CONSTRAINT "UserSession_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "UserSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "UserSession_jwtId_key" ON "UserSession"("jwtId");
CREATE INDEX "UserSession_userId_idx" ON "UserSession"("userId");
CREATE INDEX "UserSession_expiresAt_idx" ON "UserSession"("expiresAt");

CREATE TABLE "UserEntitlement" (
    "id"                    TEXT         NOT NULL,
    "userId"                TEXT         NOT NULL,
    "productId"             TEXT         NOT NULL,
    "originalTransactionId" TEXT         NOT NULL,
    "receiptHash"           TEXT,
    "purchasedAt"           TIMESTAMP(3) NOT NULL,
    "createdAt"             TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserEntitlement_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "UserEntitlement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "UserEntitlement_originalTransactionId_key" ON "UserEntitlement"("originalTransactionId");
CREATE INDEX "UserEntitlement_userId_idx" ON "UserEntitlement"("userId");
CREATE INDEX "UserEntitlement_productId_idx" ON "UserEntitlement"("productId");
