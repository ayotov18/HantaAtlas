import {
  alertsForDisease,
  countriesForDisease,
  diseases,
  guideForDisease,
  mapForDisease,
  normaliseDisease,
  summaryForDisease
} from "./fixtures.js";
import type { CountrySnapshotDto, DiseaseId, DiseaseModeDto, GuideArticleDto, MapCountryDto, MapMetric, OfficialAlertDto, SummaryDto } from "./types.js";

export interface SurveillanceRepository {
  diseases(): Promise<DiseaseModeDto[]>;
  summary(disease?: DiseaseId): Promise<SummaryDto>;
  map(metric: MapMetric, disease?: DiseaseId): Promise<MapCountryDto[]>;
  feed(disease?: DiseaseId): Promise<OfficialAlertDto[]>;
  countries(disease?: DiseaseId): Promise<CountrySnapshotDto[]>;
  country(isoCode: string, disease?: DiseaseId): Promise<CountrySnapshotDto | undefined>;
  guide(disease?: DiseaseId): Promise<GuideArticleDto[]>;
  appConfig(): Promise<Record<string, unknown>>;
}

export class FixtureRepository implements SurveillanceRepository {
  async diseases(): Promise<DiseaseModeDto[]> {
    return diseases;
  }

  async summary(disease?: DiseaseId): Promise<SummaryDto> {
    return summaryForDisease(normaliseDisease(disease));
  }

  async map(metric: MapMetric, disease?: DiseaseId): Promise<MapCountryDto[]> {
    return mapForDisease(normaliseDisease(disease)).map((country) => ({
      ...country,
      colourKey:
        metric === "cases" && (country.cases ?? 0) > 20
          ? "CASE_HIGH"
          : metric === "alerts" && country.alerts > 0
            ? "ALERT_PRESENT"
            : country.confidenceLevel
    }));
  }

  async feed(disease?: DiseaseId): Promise<OfficialAlertDto[]> {
    return alertsForDisease(normaliseDisease(disease));
  }

  async countries(disease?: DiseaseId): Promise<CountrySnapshotDto[]> {
    return countriesForDisease(normaliseDisease(disease));
  }

  async country(isoCode: string, disease?: DiseaseId): Promise<CountrySnapshotDto | undefined> {
    return countriesForDisease(normaliseDisease(disease)).find((country) => country.isoCode.toLowerCase() === isoCode.toLowerCase());
  }

  async guide(disease?: DiseaseId): Promise<GuideArticleDto[]> {
    return guideForDisease(normaliseDisease(disease));
  }

  async appConfig(): Promise<Record<string, unknown>> {
    return {
      currentProjectDate: "2026-05-08",
      defaultDevelopmentTimezone: "Europe/Sofia",
      purchaseMode: "free-no-ads-no-account",
      defaultDisease: "both",
      diseases,
      supportUrl: "https://example.com/hantaatlas-support"
    };
  }
}
