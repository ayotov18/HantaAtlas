export const sourceSchema = {
  type: "object",
  required: ["id", "organisation", "url"],
  properties: {
    id: { type: "string" },
    organisation: { type: "string" },
    url: { type: "string", format: "uri" }
  }
} as const;

export const confidenceEnum = ["OFFICIAL_STRUCTURED_DATA", "OFFICIAL_ALERT", "MEDIA_SIGNAL", "NO_RECENT_PUBLIC_DATA"] as const;

export const countrySnapshotSchema = {
  type: "object",
  required: [
    "isoCode",
    "countryName",
    "regionName",
    "cases",
    "deaths",
    "confidenceLevel",
    "reportingPeriodLabel",
    "reportedAt",
    "publishedAt",
    "lastCheckedAt",
    "source",
    "sourceUrl",
    "summary",
    "virusType",
    "limitations"
  ],
  properties: {
    isoCode: { type: "string" },
    countryName: { type: "string" },
    regionName: { type: "string" },
    cases: { anyOf: [{ type: "number" }, { type: "null" }] },
    deaths: { anyOf: [{ type: "number" }, { type: "null" }] },
    confidenceLevel: { type: "string", enum: confidenceEnum },
    reportingPeriodLabel: { type: "string" },
    reportedAt: { anyOf: [{ type: "string", format: "date-time" }, { type: "null" }] },
    publishedAt: { anyOf: [{ type: "string", format: "date-time" }, { type: "null" }] },
    lastCheckedAt: { type: "string", format: "date-time" },
    source: sourceSchema,
    sourceUrl: { type: "string", format: "uri" },
    summary: { type: "string" },
    virusType: { type: "string" },
    limitations: { type: "string" }
  }
} as const;

