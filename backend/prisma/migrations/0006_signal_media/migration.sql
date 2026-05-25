CREATE TYPE "SignalMediaType" AS ENUM ('IMAGE', 'VIDEO', 'EMBED');

ALTER TABLE "Signal"
ADD COLUMN "mediaType" "SignalMediaType",
ADD COLUMN "mediaUrl" TEXT,
ADD COLUMN "mediaThumbnailUrl" TEXT,
ADD COLUMN "mediaProvider" TEXT,
ADD COLUMN "mediaSourceUrl" TEXT,
ADD COLUMN "mediaWidth" INTEGER,
ADD COLUMN "mediaHeight" INTEGER,
ADD COLUMN "mediaFetchedAt" TIMESTAMP(3),
ADD COLUMN "mediaStatus" TEXT;

CREATE INDEX "Signal_mediaStatus_idx" ON "Signal" ("mediaStatus");
