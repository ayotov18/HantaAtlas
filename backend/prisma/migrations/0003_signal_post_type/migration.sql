-- 7-bucket post-type taxonomy for the world map.
-- Nullable: legacy rows are filled by the worker on the next ingest tick.

CREATE TYPE "SignalPostType" AS ENUM (
    'DEATH',
    'CASE_CONFIRMED',
    'CASE_SUSPECTED',
    'CASE_IMPORTED',
    'OFFICIAL_RESPONSE',
    'EXPERT_VOICE',
    'PUBLIC_DISCOURSE'
);

ALTER TABLE "Signal"
    ADD COLUMN "postType" "SignalPostType";

CREATE INDEX "Signal_postType_idx" ON "Signal"("postType");
