CREATE TYPE "ConfidenceLevel" AS ENUM ('OFFICIAL_STRUCTURED_DATA', 'OFFICIAL_ALERT', 'MEDIA_SIGNAL', 'NO_RECENT_PUBLIC_DATA');
CREATE TYPE "AlertSeverity" AS ENUM ('LOW', 'MEDIUM', 'HIGH');
CREATE TYPE "GuideSectionKind" AS ENUM ('PREVENTION', 'SYMPTOMS', 'URGENT_CARE');

CREATE TABLE "CountryRegion" (
  "id" TEXT PRIMARY KEY,
  "name" TEXT NOT NULL UNIQUE
);

CREATE TABLE "Country" (
  "id" TEXT PRIMARY KEY,
  "isoCode" TEXT NOT NULL UNIQUE,
  "name" TEXT NOT NULL,
  "regionId" TEXT REFERENCES "CountryRegion"("id"),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "Source" (
  "id" TEXT PRIMARY KEY,
  "slug" TEXT NOT NULL UNIQUE,
  "organisation" TEXT NOT NULL,
  "url" TEXT NOT NULL,
  "sourceType" TEXT NOT NULL,
  "lastSuccessfulFetchAt" TIMESTAMP(3),
  "lastFailureAt" TIMESTAMP(3),
  "lastFailureReason" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "SourceDocument" (
  "id" TEXT PRIMARY KEY,
  "sourceId" TEXT NOT NULL REFERENCES "Source"("id"),
  "title" TEXT NOT NULL,
  "url" TEXT NOT NULL,
  "reportedAt" TIMESTAMP(3),
  "publishedAt" TIMESTAMP(3),
  "fetchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" TEXT,
  "rawMetadata" JSONB
);

CREATE TABLE "CountrySnapshot" (
  "id" TEXT PRIMARY KEY,
  "countryId" TEXT NOT NULL REFERENCES "Country"("id"),
  "sourceId" TEXT NOT NULL REFERENCES "Source"("id"),
  "cases" INTEGER,
  "deaths" INTEGER,
  "confidenceLevel" "ConfidenceLevel" NOT NULL,
  "reportingPeriodLabel" TEXT NOT NULL,
  "reportedAt" TIMESTAMP(3),
  "publishedAt" TIMESTAMP(3),
  "lastCheckedAt" TIMESTAMP(3) NOT NULL,
  "sourceUrl" TEXT NOT NULL,
  "summary" TEXT NOT NULL,
  "virusType" TEXT NOT NULL,
  "limitations" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "OfficialAlert" (
  "id" TEXT PRIMARY KEY,
  "externalId" TEXT UNIQUE,
  "title" TEXT NOT NULL,
  "countryName" TEXT NOT NULL,
  "regionName" TEXT NOT NULL,
  "sourceId" TEXT NOT NULL REFERENCES "Source"("id"),
  "severity" "AlertSeverity" NOT NULL,
  "confidenceLevel" "ConfidenceLevel" NOT NULL,
  "reportedAt" TIMESTAMP(3) NOT NULL,
  "publishedAt" TIMESTAMP(3) NOT NULL,
  "summary" TEXT NOT NULL,
  "sourceUrl" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "GuideArticle" (
  "id" TEXT PRIMARY KEY,
  "slug" TEXT NOT NULL UNIQUE,
  "title" TEXT NOT NULL,
  "summary" TEXT,
  "publishedAt" TIMESTAMP(3),
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "GuideSection" (
  "id" TEXT PRIMARY KEY,
  "articleId" TEXT NOT NULL REFERENCES "GuideArticle"("id"),
  "kind" "GuideSectionKind" NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "order" INTEGER NOT NULL
);

CREATE TABLE "MapMetricSnapshot" (
  "id" TEXT PRIMARY KEY,
  "countryId" TEXT NOT NULL REFERENCES "Country"("id"),
  "metricDate" TIMESTAMP(3) NOT NULL,
  "cases" INTEGER,
  "alerts" INTEGER NOT NULL,
  "confidenceLevel" "ConfidenceLevel" NOT NULL,
  "colourKey" TEXT NOT NULL,
  UNIQUE ("countryId", "metricDate")
);

CREATE TABLE "DeviceInstallation" (
  "id" TEXT PRIMARY KEY,
  "installationId" TEXT NOT NULL UNIQUE,
  "platform" TEXT NOT NULL,
  "locale" TEXT,
  "timezone" TEXT,
  "pushTokenHash" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "WatchlistCountry" (
  "id" TEXT PRIMARY KEY,
  "deviceInstallationId" TEXT NOT NULL REFERENCES "DeviceInstallation"("id"),
  "countryId" TEXT NOT NULL REFERENCES "Country"("id"),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE ("deviceInstallationId", "countryId")
);

CREATE TABLE "Itinerary" (
  "id" TEXT PRIMARY KEY,
  "deviceInstallationId" TEXT NOT NULL REFERENCES "DeviceInstallation"("id"),
  "name" TEXT NOT NULL,
  "startsAt" TIMESTAMP(3),
  "endsAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "ItineraryCountry" (
  "id" TEXT PRIMARY KEY,
  "itineraryId" TEXT NOT NULL REFERENCES "Itinerary"("id"),
  "countryId" TEXT NOT NULL REFERENCES "Country"("id"),
  "order" INTEGER NOT NULL,
  UNIQUE ("itineraryId", "countryId")
);

CREATE TABLE "AppConfig" (
  "id" TEXT PRIMARY KEY,
  "key" TEXT NOT NULL UNIQUE,
  "value" JSONB NOT NULL,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

CREATE TABLE "Entitlement" (
  "id" TEXT PRIMARY KEY,
  "deviceInstallationId" TEXT NOT NULL REFERENCES "DeviceInstallation"("id"),
  "productId" TEXT NOT NULL,
  "transactionId" TEXT UNIQUE,
  "active" BOOLEAN NOT NULL DEFAULT TRUE,
  "purchasedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "CountrySnapshot_countryId_lastCheckedAt_idx" ON "CountrySnapshot"("countryId", "lastCheckedAt");
CREATE INDEX "CountrySnapshot_confidenceLevel_idx" ON "CountrySnapshot"("confidenceLevel");
CREATE INDEX "OfficialAlert_publishedAt_idx" ON "OfficialAlert"("publishedAt");
CREATE INDEX "OfficialAlert_severity_idx" ON "OfficialAlert"("severity");

