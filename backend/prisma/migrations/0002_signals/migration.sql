-- CreateEnum
CREATE TYPE "SignalCategory" AS ENUM ('LOCAL', 'IMPORTED', 'RESPONSE', 'MEDIA');

-- CreateEnum
CREATE TYPE "CountryActiveLevel" AS ENUM ('ENDEMIC', 'ACTIVE', 'IMPORTED', 'RESPONSE', 'NONE');

-- CreateTable
CREATE TABLE "Signal" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "summary" TEXT,
    "url" TEXT NOT NULL,
    "sourceBucket" TEXT NOT NULL,
    "publishedAt" TIMESTAMP(3) NOT NULL,
    "fetchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "countryISO" TEXT,
    "category" "SignalCategory" NOT NULL,
    "severity" "AlertSeverity" NOT NULL,
    "raw" JSONB,

    CONSTRAINT "Signal_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Signal_publishedAt_idx" ON "Signal" ("publishedAt" DESC);

-- CreateIndex
CREATE INDEX "Signal_countryISO_publishedAt_idx" ON "Signal" ("countryISO", "publishedAt" DESC);

-- CreateIndex
CREATE INDEX "Signal_category_idx" ON "Signal" ("category");

-- CreateTable
CREATE TABLE "CountrySignalAggregate" (
    "countryISO" TEXT NOT NULL,
    "last30dCount" INTEGER NOT NULL DEFAULT 0,
    "last6mCount" INTEGER NOT NULL DEFAULT 0,
    "last1yCount" INTEGER NOT NULL DEFAULT 0,
    "allTimeCount" INTEGER NOT NULL DEFAULT 0,
    "activeLevel" "CountryActiveLevel" NOT NULL DEFAULT 'NONE',
    "lastSignalAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CountrySignalAggregate_pkey" PRIMARY KEY ("countryISO")
);
