-- Alerts feature — emergency classifications per country plus an audit log of
-- changes that drives in-app inbox + local notification scheduling on iOS.

CREATE TYPE "EmergencyClassification" AS ENUM (
    'NONE',
    'ADVISORY',
    'OUTBREAK',
    'NATIONAL_EMERGENCY',
    'INTERNATIONAL_CONCERN'
);

CREATE TABLE "CountryClassification" (
    "countryISO"         TEXT                       NOT NULL,
    "countryName"        TEXT                       NOT NULL,
    "level"              "EmergencyClassification"  NOT NULL DEFAULT 'NONE',
    "sourceOrganisation" TEXT                       NOT NULL,
    "sourceUrl"          TEXT                       NOT NULL,
    "declaredAt"         TIMESTAMP(3)               NOT NULL,
    "summary"            TEXT                       NOT NULL,
    "updatedAt"          TIMESTAMP(3)               NOT NULL,

    CONSTRAINT "CountryClassification_pkey" PRIMARY KEY ("countryISO")
);

CREATE INDEX "CountryClassification_level_idx" ON "CountryClassification"("level");
CREATE INDEX "CountryClassification_updatedAt_idx" ON "CountryClassification"("updatedAt" DESC);

CREATE TABLE "CountryClassificationChange" (
    "id"                  TEXT                       NOT NULL,
    "countryISO"          TEXT                       NOT NULL,
    "countryName"         TEXT                       NOT NULL,
    "fromLevel"           "EmergencyClassification"  NOT NULL,
    "toLevel"             "EmergencyClassification"  NOT NULL,
    "changedAt"           TIMESTAMP(3)               NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sourceOrganisation"  TEXT                       NOT NULL,
    "sourceUrl"           TEXT                       NOT NULL,

    CONSTRAINT "CountryClassificationChange_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "CountryClassificationChange_changedAt_idx" ON "CountryClassificationChange"("changedAt" DESC);
CREATE INDEX "CountryClassificationChange_country_changed_idx" ON "CountryClassificationChange"("countryISO", "changedAt" DESC);
