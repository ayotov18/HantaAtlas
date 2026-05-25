// Map a free-text WHO/ECDC/CDC item to a 5-tier emergency classification.
// Pure keyword heuristic (same shape as the post-type classifier).
//
// Precedence (highest wins):
//   INTERNATIONAL_CONCERN > NATIONAL_EMERGENCY > OUTBREAK > ADVISORY > NONE.

export type EmergencyClassificationLevel =
    | "NONE"
    | "ADVISORY"
    | "OUTBREAK"
    | "NATIONAL_EMERGENCY"
    | "INTERNATIONAL_CONCERN";

const PHEIC_KEYWORDS = [
    "pheic",
    "public health emergency of international concern",
    "international concern",
    "international emergency"
];

const NATIONAL_EMERGENCY_KEYWORDS = [
    "national emergency",
    "state of emergency",
    "emergency declared",
    "declared a national",
    "declared an emergency"
];

const OUTBREAK_KEYWORDS = [
    "outbreak",
    "cluster of cases",
    "rapid spread",
    "epidemic",
    "confirmed cases",
    "deaths reported",
    "fatalities"
];

const ADVISORY_KEYWORDS = [
    "advisory",
    "alert issued",
    "screening",
    "guidance",
    "travel warning",
    "preventive",
    "precautionary"
];

export function classifyEmergency(
    title: string,
    description: string | null | undefined
): EmergencyClassificationLevel {
    const text = (title + " " + (description ?? "")).toLowerCase();
    if (PHEIC_KEYWORDS.some((k) => text.includes(k))) return "INTERNATIONAL_CONCERN";
    if (NATIONAL_EMERGENCY_KEYWORDS.some((k) => text.includes(k))) return "NATIONAL_EMERGENCY";
    if (OUTBREAK_KEYWORDS.some((k) => text.includes(k))) return "OUTBREAK";
    if (ADVISORY_KEYWORDS.some((k) => text.includes(k))) return "ADVISORY";
    return "NONE";
}

export function severityRank(level: EmergencyClassificationLevel): number {
    switch (level) {
        case "NONE": return 0;
        case "ADVISORY": return 1;
        case "OUTBREAK": return 2;
        case "NATIONAL_EMERGENCY": return 3;
        case "INTERNATIONAL_CONCERN": return 4;
    }
}
