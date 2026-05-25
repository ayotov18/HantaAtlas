-- Per-user preferences: saved countries + personalization / alert settings,
-- synced across devices for a signed-in user. 1:1 with User (PK = userId).

CREATE TABLE "UserPreferences" (
    "userId"                        TEXT         NOT NULL,
    "savedCountries"                TEXT[]       NOT NULL DEFAULT ARRAY[]::TEXT[],
    "trackAllCountries"             BOOLEAN      NOT NULL DEFAULT false,
    "selectedDiseaseMode"           TEXT         NOT NULL DEFAULT 'both',
    "lastSelectedMetric"            TEXT         NOT NULL DEFAULT 'confidence',
    "officialNoticeAlerts"          BOOLEAN      NOT NULL DEFAULT true,
    "itineraryAlerts"               BOOLEAN      NOT NULL DEFAULT true,
    "trackedCountryCaseAlerts"      BOOLEAN      NOT NULL DEFAULT true,
    "trackedCountryNewsBurstAlerts" BOOLEAN      NOT NULL DEFAULT true,
    "alertFrequency"                TEXT         NOT NULL DEFAULT 'realtime',
    "minAlertLevel"                 TEXT         NOT NULL DEFAULT 'ADVISORY',
    "quietHoursEnabled"             BOOLEAN      NOT NULL DEFAULT false,
    "quietHoursStart"               INTEGER      NOT NULL DEFAULT 22,
    "quietHoursEnd"                 INTEGER      NOT NULL DEFAULT 7,
    "createdAt"                     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"                     TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserPreferences_pkey" PRIMARY KEY ("userId"),
    CONSTRAINT "UserPreferences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
