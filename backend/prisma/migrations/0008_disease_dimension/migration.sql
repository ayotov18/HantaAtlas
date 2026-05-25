-- Disease dimension across the live signal pipeline, so Ebola ingests and
-- renders at full parity with Hantavirus. Existing rows backfill to
-- 'hantavirus' via the column DEFAULT. Forward-only.

-- ── Signal: per-row disease tag + query indexes ──────────────────────────
ALTER TABLE "Signal" ADD COLUMN "disease" TEXT NOT NULL DEFAULT 'hantavirus';
CREATE INDEX "Signal_disease_publishedAt_idx" ON "Signal"("disease", "publishedAt" DESC);
CREATE INDEX "Signal_disease_countryISO_publishedAt_idx" ON "Signal"("disease", "countryISO", "publishedAt" DESC);

-- ── CountrySignalAggregate: rollup per (country, disease) ────────────────
ALTER TABLE "CountrySignalAggregate" ADD COLUMN "disease" TEXT NOT NULL DEFAULT 'hantavirus';
ALTER TABLE "CountrySignalAggregate" DROP CONSTRAINT "CountrySignalAggregate_pkey";
ALTER TABLE "CountrySignalAggregate" ADD CONSTRAINT "CountrySignalAggregate_pkey" PRIMARY KEY ("countryISO", "disease");
CREATE INDEX "CountrySignalAggregate_disease_idx" ON "CountrySignalAggregate"("disease");

-- ── CountryClassification: one per (country, disease) ────────────────────
ALTER TABLE "CountryClassification" ADD COLUMN "disease" TEXT NOT NULL DEFAULT 'hantavirus';
ALTER TABLE "CountryClassification" DROP CONSTRAINT "CountryClassification_pkey";
ALTER TABLE "CountryClassification" ADD CONSTRAINT "CountryClassification_pkey" PRIMARY KEY ("countryISO", "disease");
CREATE INDEX "CountryClassification_disease_idx" ON "CountryClassification"("disease");

-- ── CountryClassificationChange: audit rows carry disease ────────────────
ALTER TABLE "CountryClassificationChange" ADD COLUMN "disease" TEXT NOT NULL DEFAULT 'hantavirus';
CREATE INDEX "CountryClassificationChange_disease_changedAt_idx" ON "CountryClassificationChange"("disease", "changedAt" DESC);
