export type ConfidenceLevel =
  | "OFFICIAL_STRUCTURED_DATA"
  | "OFFICIAL_ALERT"
  | "MEDIA_SIGNAL"
  | "NO_RECENT_PUBLIC_DATA";

export type Severity = "LOW" | "MEDIUM" | "HIGH";
export type MapMetric = "cases" | "alerts" | "confidence";
export type DiseaseId = "both" | "hantavirus" | "ebola";

export interface DiseaseModeDto {
  id: DiseaseId;
  title: string;
  sourceFocus: string;
}

export interface SourceDto {
  id: string;
  organisation: string;
  url: string;
}

export interface CountrySnapshotDto {
  isoCode: string;
  countryName: string;
  regionName: string;
  cases: number | null;
  deaths: number | null;
  confidenceLevel: ConfidenceLevel;
  reportingPeriodLabel: string;
  reportedAt: string | null;
  publishedAt: string | null;
  lastCheckedAt: string;
  source: SourceDto;
  sourceUrl: string;
  summary: string;
  virusType: string;
  limitations: string;
}

export interface OfficialAlertDto {
  id: string;
  title: string;
  countryName: string;
  regionName: string;
  source: SourceDto;
  severity: Severity;
  confidenceLevel: ConfidenceLevel;
  reportedAt: string;
  publishedAt: string;
  summary: string;
}

export interface SummaryDto {
  checkedAt: string;
  countryCount: number;
  officialAlertCount: number;
  savedCountSeed: number;
  latestAlert: OfficialAlertDto;
}

export interface MapCountryDto {
  isoCode: string;
  name: string;
  confidenceLevel: ConfidenceLevel;
  cases: number | null;
  alerts: number;
  colourKey: ConfidenceLevel | "CASE_LOW" | "CASE_HIGH" | "ALERT_PRESENT";
  polygons: Array<Array<{ x: number; y: number }>>;
}

export interface GuideArticleDto {
  id: string;
  section: "prevention" | "symptoms" | "urgentCare";
  title: string;
  body: string;
  symbolName: string;
}

// ─────────────────────────────────────────────────────────────────────────
// Live signal types — mirror the upstream feed (hantavirusmap.com/feed.json)
// after normalisation, classification, and country detection.

export type SignalCategory = "LOCAL" | "IMPORTED" | "RESPONSE" | "MEDIA";
export type CountryActiveLevel = "ENDEMIC" | "ACTIVE" | "IMPORTED" | "RESPONSE" | "NONE";
export type SignalTimeRange = "30d" | "6m" | "1y" | "all";

// 7-bucket post-type taxonomy for the world map. Two groups:
//   Ground truth — DEATH, CASE_CONFIRMED, CASE_SUSPECTED, CASE_IMPORTED
//   Discourse    — OFFICIAL_RESPONSE, EXPERT_VOICE, PUBLIC_DISCOURSE
export type SignalPostType =
  | "DEATH"
  | "CASE_CONFIRMED"
  | "CASE_SUSPECTED"
  | "CASE_IMPORTED"
  | "OFFICIAL_RESPONSE"
  | "EXPERT_VOICE"
  | "PUBLIC_DISCOURSE";

export type SignalMediaType = "IMAGE" | "VIDEO" | "EMBED";

export interface SignalMediaDto {
  type: SignalMediaType;
  url: string;
  thumbnailUrl: string | null;
  provider: string | null;
  sourceUrl: string | null;
  width: number | null;
  height: number | null;
}

export interface SignalDto {
  id: string;
  title: string;
  summary: string | null;
  url: string;
  sourceBucket: string;
  publishedAt: string;     // ISO-8601
  countryISO: string | null;
  category: SignalCategory;
  severity: Severity;
  postType: SignalPostType | null;  // null on legacy rows until next worker tick
  primaryMedia?: SignalMediaDto | null;
}

export interface CountrySignalAggregateDto {
  countryISO: string;
  last30dCount: number;
  last6mCount: number;
  last1yCount: number;
  allTimeCount: number;
  activeLevel: CountryActiveLevel;
  lastSignalAt: string | null;
}

export interface AppStatsDto {
  updatedAt: string;
  signalsTotal: number;
  signalsLast30d: number;
  countriesActive: number;
  topSources: Array<{ bucket: string; count: number }>;
}

// ─────────────────────────────────────────────────────────────────────────
// Alerts feature — emergency classifications per country + audit log.

export type EmergencyClassificationLevel =
  | "NONE"
  | "ADVISORY"
  | "OUTBREAK"
  | "NATIONAL_EMERGENCY"
  | "INTERNATIONAL_CONCERN";

export interface CountryClassificationDto {
  countryISO: string;
  countryName: string;
  level: EmergencyClassificationLevel;
  sourceOrganisation: string;
  sourceUrl: string;
  declaredAt: string;     // ISO-8601
  summary: string;
}

export interface ClassificationChangeDto {
  id: string;
  countryISO: string;
  countryName: string;
  fromLevel: EmergencyClassificationLevel;
  toLevel: EmergencyClassificationLevel;
  changedAt: string;
  sourceOrganisation: string;
  sourceUrl: string;
}
