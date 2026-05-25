export type ConfidenceLevel =
  | "OFFICIAL_STRUCTURED_DATA"
  | "OFFICIAL_ALERT"
  | "MEDIA_SIGNAL"
  | "NO_RECENT_PUBLIC_DATA";

export interface NormalisedSnapshot {
  isoCode: string;
  cases: number | null;
  deaths: number | null;
  confidenceLevel: ConfidenceLevel;
  reportingPeriodLabel: string;
  reportedAt: string | null;
  publishedAt: string | null;
  sourceUrl: string;
  summary: string;
  virusType: string;
  limitations: string;
}

export interface SourceFetchResult {
  sourceId: string;
  fetchedAt: string;
  snapshots: NormalisedSnapshot[];
}

export interface OfficialSourceAdapter {
  readonly sourceId: string;
  fetch(): Promise<SourceFetchResult>;
}

