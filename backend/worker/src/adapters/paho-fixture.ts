import type { OfficialSourceAdapter, SourceFetchResult } from "../source-adapter.js";

export class PahoFixtureAdapter implements OfficialSourceAdapter {
  readonly sourceId = "paho";

  async fetch(): Promise<SourceFetchResult> {
    return {
      sourceId: this.sourceId,
      fetchedAt: "2026-05-08T09:41:00+03:00",
      snapshots: [
        {
          isoCode: "AR",
          cases: 18,
          deaths: 4,
          confidenceLevel: "OFFICIAL_ALERT",
          reportingPeriodLabel: "Recent official alert",
          reportedAt: "2026-05-05T12:00:00Z",
          publishedAt: "2026-05-07T12:00:00Z",
          sourceUrl: "https://www.paho.org/",
          summary: "Official regional alert with confirmed cases and rural prevention guidance.",
          virusType: "Andes virus",
          limitations: "Alert-led public data; comparable national table not assumed."
        }
      ]
    };
  }
}

