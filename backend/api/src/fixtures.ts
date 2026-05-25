import type {
  AppStatsDto,
  CountrySignalAggregateDto,
  CountrySnapshotDto,
  DiseaseId,
  DiseaseModeDto,
  GuideArticleDto,
  MapCountryDto,
  OfficialAlertDto,
  SignalDto,
  SummaryDto
} from "./types.js";

const checkedAt = "2026-05-08T09:41:00+03:00";

export const sources = {
  cdc: { id: "cdc", organisation: "CDC", url: "https://www.cdc.gov/hantavirus/" },
  cdcEbola: { id: "cdc-ebola", organisation: "CDC", url: "https://www.cdc.gov/ebola/" },
  ecdc: { id: "ecdc", organisation: "ECDC", url: "https://www.ecdc.europa.eu/" },
  paho: { id: "paho", organisation: "PAHO", url: "https://www.paho.org/" },
  who: { id: "who", organisation: "WHO", url: "https://www.who.int/emergencies/disease-outbreak-news" },
  africaCdc: { id: "africa-cdc", organisation: "Africa CDC", url: "https://africacdc.org/" },
  ministryAr: { id: "ministry-ar", organisation: "National Ministry of Health", url: "https://www.argentina.gob.ar/salud" }
} as const;

export const diseases: DiseaseModeDto[] = [
  { id: "both", title: "Both", sourceFocus: "combined official-source watch" },
  { id: "hantavirus", title: "Hantavirus", sourceFocus: "rodent-borne surveillance" },
  { id: "ebola", title: "Ebola", sourceFocus: "official outbreak notices" }
];

export function normaliseDisease(raw?: string): DiseaseId {
  if (raw === "ebola") return "ebola";
  if (raw === "hantavirus") return "hantavirus";
  return "both";
}

export const countries: CountrySnapshotDto[] = [
  {
    isoCode: "US",
    countryName: "United States",
    regionName: "North America",
    cases: 11,
    deaths: 2,
    confidenceLevel: "OFFICIAL_STRUCTURED_DATA",
    reportingPeriodLabel: "2026 year to date",
    reportedAt: "2026-04-30T12:00:00Z",
    publishedAt: "2026-05-03T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.cdc,
    sourceUrl: sources.cdc.url,
    summary: "Confirmed cases remain rare and are reported through national public-health surveillance.",
    virusType: "Sin Nombre virus",
    limitations: "Publication cadence and state-level detail vary. This display is not a complete exposure-risk estimate."
  },
  {
    isoCode: "AR",
    countryName: "Argentina",
    regionName: "South America",
    cases: 18,
    deaths: 4,
    confidenceLevel: "OFFICIAL_ALERT",
    reportingPeriodLabel: "Recent official alert",
    reportedAt: "2026-05-05T12:00:00Z",
    publishedAt: "2026-05-07T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.paho,
    sourceUrl: sources.paho.url,
    summary: "Official regional alerts note confirmed Andes virus cases and prevention guidance for rural settings.",
    virusType: "Andes virus",
    limitations: "Current public data is alert-led. Comparable national time-series surveillance is not assumed in this MVP."
  },
  {
    isoCode: "DE",
    countryName: "Germany",
    regionName: "Europe",
    cases: 64,
    deaths: 0,
    confidenceLevel: "OFFICIAL_STRUCTURED_DATA",
    reportingPeriodLabel: "2025 annual surveillance",
    reportedAt: "2025-12-31T12:00:00Z",
    publishedAt: "2026-03-18T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.ecdc,
    sourceUrl: sources.ecdc.url,
    summary: "European surveillance supports country-level comparison and annual trend context.",
    virusType: "Puumala virus",
    limitations: "Local drill-down should only be shown where official regional data supports it."
  },
  {
    isoCode: "CL",
    countryName: "Chile",
    regionName: "South America",
    cases: 7,
    deaths: 1,
    confidenceLevel: "OFFICIAL_ALERT",
    reportingPeriodLabel: "Recent official alert",
    reportedAt: "2026-04-28T12:00:00Z",
    publishedAt: "2026-05-01T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.ministryAr,
    sourceUrl: sources.ministryAr.url,
    summary: "Ministry guidance emphasises rural exposure prevention and prompt clinical assessment for symptoms.",
    virusType: "Andes virus",
    limitations: "Alert formats differ by ministry and may not include a complete national table."
  },
  {
    isoCode: "PE",
    countryName: "Peru",
    regionName: "South America",
    cases: null,
    deaths: null,
    confidenceLevel: "NO_RECENT_PUBLIC_DATA",
    reportingPeriodLabel: "No recent public data",
    reportedAt: null,
    publishedAt: null,
    lastCheckedAt: checkedAt,
    source: sources.paho,
    sourceUrl: sources.paho.url,
    summary: "No recent public country-level hantavirus surveillance was found in monitored official channels.",
    virusType: "Not specified",
    limitations: "No recent public data is not the same as zero cases."
  }
];

export const ebolaCountries: CountrySnapshotDto[] = [
  {
    isoCode: "CD",
    countryName: "Democratic Republic of the Congo",
    regionName: "Central Africa",
    cases: 23,
    deaths: 12,
    confidenceLevel: "OFFICIAL_ALERT",
    reportingPeriodLabel: "Active official outbreak notice",
    reportedAt: "2026-05-03T12:00:00Z",
    publishedAt: "2026-05-08T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.who,
    sourceUrl: sources.who.url,
    summary: "WHO outbreak notices and national updates describe active Ebola disease monitoring with affected areas and changing case classifications.",
    virusType: "Bundibugyo ebolavirus",
    limitations: "Counts may change as suspected, probable, and confirmed cases are reclassified by official investigations."
  },
  {
    isoCode: "UG",
    countryName: "Uganda",
    regionName: "East Africa",
    cases: 4,
    deaths: 1,
    confidenceLevel: "OFFICIAL_ALERT",
    reportingPeriodLabel: "Cross-border monitoring notice",
    reportedAt: "2026-05-04T12:00:00Z",
    publishedAt: "2026-05-08T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.who,
    sourceUrl: sources.who.url,
    summary: "Official notices describe monitoring linked to the regional Ebola event. Imported and local signals are kept separate.",
    virusType: "Bundibugyo ebolavirus",
    limitations: "Public updates may emphasize response activity before complete case tables are available."
  },
  {
    isoCode: "GN",
    countryName: "Guinea",
    regionName: "West Africa",
    cases: null,
    deaths: null,
    confidenceLevel: "OFFICIAL_STRUCTURED_DATA",
    reportingPeriodLabel: "Historical context",
    reportedAt: null,
    publishedAt: "2026-04-20T12:00:00Z",
    lastCheckedAt: checkedAt,
    source: sources.cdcEbola,
    sourceUrl: sources.cdcEbola.url,
    summary: "CDC historical outbreak material is used for context only, not as a live case-count authority.",
    virusType: "Zaire ebolavirus",
    limitations: "Historical context does not imply current local transmission."
  },
  {
    isoCode: "SL",
    countryName: "Sierra Leone",
    regionName: "West Africa",
    cases: null,
    deaths: null,
    confidenceLevel: "NO_RECENT_PUBLIC_DATA",
    reportingPeriodLabel: "No current official event cached",
    reportedAt: null,
    publishedAt: null,
    lastCheckedAt: checkedAt,
    source: sources.cdcEbola,
    sourceUrl: sources.cdcEbola.url,
    summary: "No current official Ebola event is cached for this country in the fixture set.",
    virusType: "Not specified",
    limitations: "No recent public data is not the same as zero risk or zero cases."
  }
];

export const alerts: OfficialAlertDto[] = [
  {
    id: "bo-santa-cruz",
    title: "Hantavirus outbreak investigation",
    countryName: "Bolivia - Santa Cruz Department",
    regionName: "Americas",
    source: sources.paho,
    severity: "HIGH",
    confidenceLevel: "OFFICIAL_ALERT",
    reportedAt: "2026-05-05T12:00:00Z",
    publishedAt: "2026-05-07T12:00:00Z",
    summary: "Health authorities are investigating an increase in officially reported cases in rural communities."
  },
  {
    id: "ecdc-annual",
    title: "Hantavirus surveillance update",
    countryName: "European Union / EEA",
    regionName: "Europe",
    source: sources.ecdc,
    severity: "LOW",
    confidenceLevel: "OFFICIAL_STRUCTURED_DATA",
    reportedAt: "2025-12-31T12:00:00Z",
    publishedAt: "2026-03-18T12:00:00Z",
    summary: "Routine surveillance summary published with country-level case counts and known reporting limitations."
  }
];

export const ebolaAlerts: OfficialAlertDto[] = [
  {
    id: "who-ebola-drc-uganda",
    title: "Ebola disease official outbreak notice",
    countryName: "DRC and Uganda",
    regionName: "Africa",
    source: sources.who,
    severity: "HIGH",
    confidenceLevel: "OFFICIAL_ALERT",
    reportedAt: "2026-05-03T12:00:00Z",
    publishedAt: "2026-05-08T12:00:00Z",
    summary: "Official source-backed notice with affected areas, case classifications, and response context."
  },
  {
    id: "cdc-ebola-situation",
    title: "Ebola current situation context",
    countryName: "Global",
    regionName: "Reference",
    source: sources.cdcEbola,
    severity: "MEDIUM",
    confidenceLevel: "OFFICIAL_STRUCTURED_DATA",
    reportedAt: "2026-04-30T12:00:00Z",
    publishedAt: "2026-05-02T12:00:00Z",
    summary: "CDC situation material provides context and travel-health framing without replacing local official notices."
  }
];

export const summary: SummaryDto = {
  checkedAt,
  countryCount: 94,
  officialAlertCount: 3,
  savedCountSeed: 7,
  latestAlert: alerts[0]
};

export const ebolaSummary: SummaryDto = {
  checkedAt,
  countryCount: ebolaCountries.length,
  officialAlertCount: ebolaAlerts.length,
  savedCountSeed: 0,
  latestAlert: ebolaAlerts[0]
};

export const bothSummary: SummaryDto = {
  checkedAt,
  countryCount: uniqueCountryCount([...countries, ...ebolaCountries]),
  officialAlertCount: alerts.length + ebolaAlerts.length,
  savedCountSeed: summary.savedCountSeed + ebolaSummary.savedCountSeed,
  latestAlert: [...alerts, ...ebolaAlerts].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt))[0]
};

export const guideArticles: GuideArticleDto[] = [
  { id: "ventilate", section: "prevention", title: "Ventilate closed spaces", body: "Open doors and windows before entering sheds, cabins, barns, or unused buildings.", symbolName: "window.vertical.open" },
  { id: "wet-dust", section: "prevention", title: "Wet down dust", body: "Lightly wet contaminated surfaces before cleaning to avoid stirring particles into the air.", symbolName: "drop.fill" },
  { id: "early", section: "symptoms", title: "Early symptoms", body: "Fever, fatigue, muscle aches, headache, dizziness, chills, nausea, or abdominal symptoms can occur.", symbolName: "thermometer.medium" },
  { id: "urgent", section: "urgentCare", title: "Breathing trouble", body: "Seek urgent medical care for shortness of breath after possible rodent exposure.", symbolName: "exclamationmark.triangle.fill" }
];

export const ebolaGuideArticles: GuideArticleDto[] = [
  { id: "ebola-avoid-fluids", section: "prevention", title: "Avoid direct contact", body: "Avoid direct contact with blood, body fluids, or contaminated items during an official Ebola event.", symbolName: "hand.raised.fill" },
  { id: "ebola-wildlife", section: "prevention", title: "Avoid sick or dead wildlife", body: "Do not handle sick or dead wildlife in affected areas. Follow local public-health guidance.", symbolName: "leaf.fill" },
  { id: "ebola-symptoms", section: "symptoms", title: "Symptoms need assessment", body: "Fever, weakness, aches, vomiting, diarrhoea, or bleeding symptoms require official clinical guidance, especially after exposure.", symbolName: "thermometer.medium" },
  { id: "ebola-call-ahead", section: "urgentCare", title: "Call ahead for care", body: "If exposed or symptomatic in an affected area, contact local health authorities or a clinician before arriving when possible.", symbolName: "phone.fill" }
];

export const mapCountries: MapCountryDto[] = countries.map((country, index) => ({
  isoCode: country.isoCode,
  name: country.countryName,
  confidenceLevel: country.confidenceLevel,
  cases: country.cases,
  alerts: country.confidenceLevel === "OFFICIAL_ALERT" ? 1 : 0,
  colourKey: country.confidenceLevel,
  polygons: [[
    { x: 0.15 + index * 0.12, y: 0.34 + index * 0.07 },
    { x: 0.23 + index * 0.12, y: 0.32 + index * 0.07 },
    { x: 0.25 + index * 0.12, y: 0.42 + index * 0.07 },
    { x: 0.16 + index * 0.12, y: 0.45 + index * 0.07 }
  ]]
}));

export const ebolaMapCountries: MapCountryDto[] = ebolaCountries.map((country, index) => ({
  isoCode: country.isoCode,
  name: country.countryName,
  confidenceLevel: country.confidenceLevel,
  cases: country.cases,
  alerts: country.confidenceLevel === "OFFICIAL_ALERT" ? 1 : 0,
  colourKey: country.confidenceLevel,
  polygons: [[
    { x: 0.48 + index * 0.05, y: 0.56 + index * 0.02 },
    { x: 0.53 + index * 0.05, y: 0.55 + index * 0.02 },
    { x: 0.55 + index * 0.05, y: 0.64 + index * 0.02 },
    { x: 0.49 + index * 0.05, y: 0.65 + index * 0.02 }
  ]]
}));

export const ebolaSignals: SignalDto[] = [
  {
    id: "ebola-cd-1",
    title: "WHO notice tracks Ebola disease outbreak and affected health zones",
    summary: "Official source-backed signal. Counts can shift as suspected, probable, and confirmed cases are reclassified.",
    url: "https://www.who.int/emergencies/disease-outbreak-news",
    sourceBucket: "WHO-DON",
    publishedAt: "2026-05-07T12:00:00Z",
    countryISO: "CD",
    category: "LOCAL",
    severity: "HIGH",
    postType: "CASE_CONFIRMED",
    // The worker ingests + og:image-enriches Hantavirus only, so Ebola
    // signals carry curated public-domain source imagery (CDC PHIL via
    // Wikimedia Commons) to match the Hantavirus feed's image cards.
    primaryMedia: {
      type: "IMAGE",
      url: "https://commons.wikimedia.org/wiki/Special:FilePath/Ebola_virus_virion.jpg",
      thumbnailUrl: "https://commons.wikimedia.org/wiki/Special:FilePath/Ebola_virus_virion.jpg",
      provider: "WHO",
      sourceUrl: "https://www.who.int/emergencies/disease-outbreak-news",
      width: null,
      height: null
    }
  },
  {
    id: "ebola-ug-1",
    title: "Official cross-border monitoring update follows Ebola event",
    summary: "Displayed as an official response signal until a country-specific case table is published.",
    url: "https://www.who.int/emergencies/disease-outbreak-news",
    sourceBucket: "WHO-DON",
    publishedAt: "2026-05-06T12:00:00Z",
    countryISO: "UG",
    category: "RESPONSE",
    severity: "HIGH",
    postType: "OFFICIAL_RESPONSE",
    primaryMedia: {
      type: "IMAGE",
      url: "https://commons.wikimedia.org/wiki/Special:FilePath/CDC_worker_exposed_to_Ebola_virus.jpg",
      thumbnailUrl: "https://commons.wikimedia.org/wiki/Special:FilePath/CDC_worker_exposed_to_Ebola_virus.jpg",
      provider: "WHO",
      sourceUrl: "https://www.who.int/emergencies/disease-outbreak-news",
      width: null,
      height: null
    }
  },
  {
    id: "ebola-cd-2",
    title: "Ministry response teams expand Ebola contact tracing",
    summary: "Response activity is shown separately from confirmed case counts.",
    url: "https://www.who.int/emergencies/disease-outbreak-news",
    sourceBucket: "Ministry-CD",
    publishedAt: "2026-05-04T12:00:00Z",
    countryISO: "CD",
    category: "RESPONSE",
    severity: "MEDIUM",
    postType: "OFFICIAL_RESPONSE",
    primaryMedia: {
      type: "IMAGE",
      url: "https://commons.wikimedia.org/wiki/Special:FilePath/Biosafety_level_4_hazmat_suit.jpg",
      thumbnailUrl: "https://commons.wikimedia.org/wiki/Special:FilePath/Biosafety_level_4_hazmat_suit.jpg",
      provider: "Ministry of Health",
      sourceUrl: "https://www.who.int/emergencies/disease-outbreak-news",
      width: null,
      height: null
    }
  },
  {
    id: "ebola-gn-1",
    title: "CDC historical Ebola outbreak record used for context",
    summary: "Historical context only; not a current local transmission claim.",
    url: "https://www.cdc.gov/ebola/",
    sourceBucket: "CDC-Ebola",
    publishedAt: "2026-04-30T12:00:00Z",
    countryISO: "GN",
    category: "MEDIA",
    severity: "LOW",
    postType: "PUBLIC_DISCOURSE",
    primaryMedia: {
      type: "IMAGE",
      url: "https://commons.wikimedia.org/wiki/Special:FilePath/Ebola_virus_virion.jpg",
      thumbnailUrl: "https://commons.wikimedia.org/wiki/Special:FilePath/Ebola_virus_virion.jpg",
      provider: "CDC",
      sourceUrl: "https://www.cdc.gov/ebola/",
      width: null,
      height: null
    }
  }
];

export const ebolaAggregates: CountrySignalAggregateDto[] = aggregateSignals(ebolaSignals);
export const ebolaStats: AppStatsDto = statsFromSignals(ebolaSignals);

export function summaryForDisease(disease: DiseaseId): SummaryDto {
  if (disease === "ebola") return ebolaSummary;
  if (disease === "hantavirus") return summary;
  return bothSummary;
}

export function countriesForDisease(disease: DiseaseId): CountrySnapshotDto[] {
  if (disease === "ebola") return ebolaCountries;
  if (disease === "hantavirus") return countries;
  return mergeCountries([...countries, ...ebolaCountries]);
}

export function alertsForDisease(disease: DiseaseId): OfficialAlertDto[] {
  if (disease === "ebola") return ebolaAlerts;
  if (disease === "hantavirus") return alerts;
  return [...alerts, ...ebolaAlerts].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
}

export function guideForDisease(disease: DiseaseId): GuideArticleDto[] {
  if (disease === "ebola") return ebolaGuideArticles;
  if (disease === "hantavirus") return guideArticles;
  return [...guideArticles, ...ebolaGuideArticles];
}

export function mapForDisease(disease: DiseaseId): MapCountryDto[] {
  if (disease === "ebola") return ebolaMapCountries;
  if (disease === "hantavirus") return mapCountries;
  return mergeMapCountries([...mapCountries, ...ebolaMapCountries]);
}

export function fixtureSignalsForDisease(disease: DiseaseId): SignalDto[] {
  if (disease === "ebola" || disease === "both") return ebolaSignals;
  return [];
}

export function fixtureAggregatesForDisease(disease: DiseaseId): CountrySignalAggregateDto[] {
  if (disease === "ebola" || disease === "both") return ebolaAggregates;
  return [];
}

export function fixtureStatsForDisease(disease: DiseaseId): AppStatsDto {
  if (disease === "ebola" || disease === "both") return ebolaStats;
  return statsFromSignals([]);
}

export function mergeSignals(...signalGroups: SignalDto[][]): SignalDto[] {
  return signalGroups
    .flat()
    .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
}

export function mergeAggregates(...aggregateGroups: CountrySignalAggregateDto[][]): CountrySignalAggregateDto[] {
  const byCountry = new Map<string, CountrySignalAggregateDto>();
  for (const aggregate of aggregateGroups.flat()) {
    const iso = aggregate.countryISO.toUpperCase();
    const existing = byCountry.get(iso);
    if (!existing) {
      byCountry.set(iso, { ...aggregate, countryISO: iso });
      continue;
    }
    byCountry.set(iso, {
      countryISO: iso,
      last30dCount: existing.last30dCount + aggregate.last30dCount,
      last6mCount: existing.last6mCount + aggregate.last6mCount,
      last1yCount: existing.last1yCount + aggregate.last1yCount,
      allTimeCount: existing.allTimeCount + aggregate.allTimeCount,
      activeLevel: strongestActiveLevel(existing.activeLevel, aggregate.activeLevel),
      lastSignalAt: maxIsoDate(existing.lastSignalAt, aggregate.lastSignalAt)
    });
  }
  return [...byCountry.values()].sort((a, b) => (b.lastSignalAt ?? "").localeCompare(a.lastSignalAt ?? ""));
}

export function mergeStats(...statsGroups: AppStatsDto[]): AppStatsDto {
  const buckets = new Map<string, number>();
  let signalsTotal = 0;
  let signalsLast30d = 0;
  let countriesActive = 0;
  let latestUpdatedAt = checkedAt;
  for (const item of statsGroups) {
    signalsTotal += item.signalsTotal;
    signalsLast30d += item.signalsLast30d;
    countriesActive += item.countriesActive;
    if (item.updatedAt > latestUpdatedAt) latestUpdatedAt = item.updatedAt;
    for (const source of item.topSources) {
      buckets.set(source.bucket, (buckets.get(source.bucket) ?? 0) + source.count);
    }
  }
  return {
    updatedAt: latestUpdatedAt,
    signalsTotal,
    signalsLast30d,
    countriesActive,
    topSources: [...buckets.entries()]
      .map(([bucket, count]) => ({ bucket, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 6)
  };
}

function uniqueCountryCount(sourceCountries: CountrySnapshotDto[]): number {
  return new Set(sourceCountries.map((country) => country.isoCode.toUpperCase())).size;
}

function mergeCountries(sourceCountries: CountrySnapshotDto[]): CountrySnapshotDto[] {
  const byCountry = new Map<string, CountrySnapshotDto>();
  for (const country of sourceCountries) {
    const iso = country.isoCode.toUpperCase();
    const existing = byCountry.get(iso);
    if (!existing) {
      byCountry.set(iso, country);
      continue;
    }
    const existingDate = existing.publishedAt ?? existing.reportedAt ?? "";
    const nextDate = country.publishedAt ?? country.reportedAt ?? "";
    if (nextDate >= existingDate) byCountry.set(iso, country);
  }
  return [...byCountry.values()].sort((a, b) => a.countryName.localeCompare(b.countryName));
}

function mergeMapCountries(sourceCountries: MapCountryDto[]): MapCountryDto[] {
  const byCountry = new Map<string, MapCountryDto>();
  for (const country of sourceCountries) {
    const iso = country.isoCode.toUpperCase();
    const existing = byCountry.get(iso);
    if (!existing) {
      byCountry.set(iso, country);
      continue;
    }
    byCountry.set(iso, {
      ...country,
      isoCode: iso,
      cases: addNullable(existing.cases, country.cases),
      alerts: existing.alerts + country.alerts,
      confidenceLevel: strongestConfidence(existing.confidenceLevel, country.confidenceLevel),
      colourKey: strongestConfidence(existing.confidenceLevel, country.confidenceLevel),
      polygons: [...existing.polygons, ...country.polygons]
    });
  }
  return [...byCountry.values()].sort((a, b) => a.name.localeCompare(b.name));
}

function addNullable(lhs: number | null, rhs: number | null): number | null {
  if (lhs === null) return rhs;
  if (rhs === null) return lhs;
  return lhs + rhs;
}

function strongestConfidence(lhs: CountrySnapshotDto["confidenceLevel"], rhs: CountrySnapshotDto["confidenceLevel"]) {
  return confidenceRank(rhs) > confidenceRank(lhs) ? rhs : lhs;
}

function confidenceRank(level: CountrySnapshotDto["confidenceLevel"]): number {
  switch (level) {
    case "NO_RECENT_PUBLIC_DATA": return 0;
    case "MEDIA_SIGNAL": return 1;
    case "OFFICIAL_STRUCTURED_DATA": return 2;
    case "OFFICIAL_ALERT": return 3;
  }
}

function maxIsoDate(lhs: string | null, rhs: string | null): string | null {
  if (!lhs) return rhs;
  if (!rhs) return lhs;
  return rhs > lhs ? rhs : lhs;
}

function aggregateSignals(signals: SignalDto[]): CountrySignalAggregateDto[] {
  const byCountry = new Map<string, CountrySignalAggregateDto>();
  for (const signal of signals) {
    if (!signal.countryISO) continue;
    const iso = signal.countryISO.toUpperCase();
    const existing = byCountry.get(iso) ?? {
      countryISO: iso,
      last30dCount: 0,
      last6mCount: 0,
      last1yCount: 0,
      allTimeCount: 0,
      activeLevel: "NONE" as const,
      lastSignalAt: null
    };
    existing.last30dCount += 1;
    existing.last6mCount += 1;
    existing.last1yCount += 1;
    existing.allTimeCount += 1;
    existing.activeLevel = strongestActiveLevel(existing.activeLevel, activeLevelForPostType(signal.postType));
    if (!existing.lastSignalAt || signal.publishedAt > existing.lastSignalAt) {
      existing.lastSignalAt = signal.publishedAt;
    }
    byCountry.set(iso, existing);
  }
  return [...byCountry.values()].sort((a, b) => (b.lastSignalAt ?? "").localeCompare(a.lastSignalAt ?? ""));
}

function statsFromSignals(signals: SignalDto[]): AppStatsDto {
  const counts = new Map<string, number>();
  for (const signal of signals) counts.set(signal.sourceBucket, (counts.get(signal.sourceBucket) ?? 0) + 1);
  return {
    updatedAt: checkedAt,
    signalsTotal: signals.length,
    signalsLast30d: signals.length,
    countriesActive: new Set(signals.map((signal) => signal.countryISO).filter(Boolean)).size,
    topSources: [...counts.entries()]
      .map(([bucket, count]) => ({ bucket, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 6)
  };
}

function activeLevelForPostType(postType: SignalDto["postType"]): CountrySignalAggregateDto["activeLevel"] {
  switch (postType) {
    case "DEATH":
    case "CASE_CONFIRMED":
    case "CASE_SUSPECTED":
      return "ACTIVE";
    case "CASE_IMPORTED":
      return "IMPORTED";
    case "OFFICIAL_RESPONSE":
    case "EXPERT_VOICE":
    case "PUBLIC_DISCOURSE":
    default:
      return "RESPONSE";
  }
}

function strongestActiveLevel(
  lhs: CountrySignalAggregateDto["activeLevel"],
  rhs: CountrySignalAggregateDto["activeLevel"]
): CountrySignalAggregateDto["activeLevel"] {
  const rank = { NONE: 0, RESPONSE: 1, IMPORTED: 2, ENDEMIC: 2, ACTIVE: 3 };
  return rank[rhs] > rank[lhs] ? rhs : lhs;
}
