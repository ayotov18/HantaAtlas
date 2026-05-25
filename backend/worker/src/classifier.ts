// Heuristic classifier for ingested signals. Returns category + severity.
// Pure string match; intentionally simple. Replace with NER later.

export type SignalCategory = "LOCAL" | "IMPORTED" | "RESPONSE" | "MEDIA";
export type SignalSeverity = "LOW" | "MEDIUM" | "HIGH";

export type SignalPostType =
    | "DEATH"
    | "CASE_CONFIRMED"
    | "CASE_SUSPECTED"
    | "CASE_IMPORTED"
    | "OFFICIAL_RESPONSE"
    | "EXPERT_VOICE"
    | "PUBLIC_DISCOURSE";

const RESPONSE_KEYWORDS = [
    "advisory", "screening", "quarantine", "ban", "restriction",
    "border", "travel warning", "guidance issued", "alert issued"
];

const IMPORTED_KEYWORDS = [
    "imported", "returnee", "returning traveller", "returning traveler",
    "repatriation", "repatriated", "evacuated"
];

const LOCAL_KEYWORDS = [
    "case", "cases", "death", "deaths", "fatal", "outbreak",
    "confirmed", "investigation", "hospital", "patient", "patients",
    "vaka", "ölü", "vaka görüldü"  // Turkish (frequent in feed)
];

const HIGH_SEVERITY = ["death", "deaths", "fatal", "outbreak", "epidemic", "pandemic", "fatality", "fatalities", "ölü"];
const MEDIUM_SEVERITY = ["case", "cases", "confirmed", "investigation", "patient", "vaka"];

export function classify(title: string, summary?: string): { category: SignalCategory; severity: SignalSeverity } {
    const text = (title + " " + (summary ?? "")).toLowerCase();

    let category: SignalCategory = "MEDIA";
    if (RESPONSE_KEYWORDS.some((k) => text.includes(k))) {
        category = "RESPONSE";
    } else if (IMPORTED_KEYWORDS.some((k) => text.includes(k))) {
        category = "IMPORTED";
    } else if (LOCAL_KEYWORDS.some((k) => text.includes(k))) {
        category = "LOCAL";
    }

    let severity: SignalSeverity = "LOW";
    if (HIGH_SEVERITY.some((k) => text.includes(k))) {
        severity = "HIGH";
    } else if (MEDIUM_SEVERITY.some((k) => text.includes(k))) {
        severity = "MEDIUM";
    }

    return { category, severity };
}

// 7-bucket post-type taxonomy for the world map. The map dot colour is
// derived from this; the layers panel groups them into "ground truth" vs
// "discourse". Multilingual keyword sets cover EN (primary) plus ES / PT /
// IT / DE / TR / FR cognates that appear in the upstream JSON Feed.
//
// Precedence (most-severe-event wins):
//   DEATH > CASE_CONFIRMED > CASE_IMPORTED > CASE_SUSPECTED >
//   OFFICIAL_RESPONSE > EXPERT_VOICE > PUBLIC_DISCOURSE.

const DEATH_KEYWORDS = [
    "death", "deaths", "died", "fatal", "fatality", "fatalities",
    "deceased", "casualty", "casualties",
    "muerte", "muertos", "muerto",       // ES
    "morte", "mortes",                   // PT/IT
    "tod ", "todesfälle",                // DE
    "ölü", "ölüm",                       // TR
    "décès"                              // FR
];

const CONFIRMED_KEYWORDS = [
    "confirmed case", "lab-confirmed", "lab confirmed", "test positive",
    "tested positive", "diagnosed with", "outbreak declared",
    "caso confirmado", "casi confermati", "fall bestätigt", "doğrulandı"
];

const IMPORTED_POST_KEYWORDS = [
    "imported case", "imported", "returnee", "returning traveller",
    "returning traveler", "repatriation", "repatriated", "evacuated",
    "caso importado", "caso importato", "rückkehrer", "yurt dışından"
];

const SUSPECTED_KEYWORDS = [
    "suspected case", "suspected", "under investigation", "possible case",
    "monitoring", "awaiting test", "awaiting results", "preliminary",
    "caso sospechoso", "caso sospetto", "verdachtsfall", "şüpheli vaka"
];

const OFFICIAL_RESPONSE_KEYWORDS = [
    "advisory", "advise", "screening", "quarantine", "ban", "restriction",
    "border", "travel warning", "guidance issued", "alert issued", "protocol",
    "aviso", "advertencia", "cuarentena", "protocollo",
    "warnung", "tarama", "uyarı"
];

const EXPERT_VOICE_KEYWORDS = [
    "predict", "predicts", "prediction", "project", "projects", "projection",
    "forecast", "warn", "warns", "warning", "fear", "fears", "concern",
    "concerns", "experts say", "expert says", "scientists believe", "scientist",
    "researcher", "study suggests", "research suggests", "could be", "may be",
    "might be",
    "predicen", "preocupación",          // ES
    "previsione", "preoccupazione",      // IT
    "vorhersage", "besorgt",             // DE
    "tahmin", "endişe"                   // TR
];

const GENERIC_CASE_KEYWORDS = [
    "case", "cases", "infected", "infection", "patient", "patients",
    "outbreak", "hospital",
    "caso", "casos",                     // ES/PT
    "fall ", "fälle",                    // DE
    "vaka",                              // TR
    "cas "                               // FR
];

export function classifyPostType(
    title: string,
    summary: string | null | undefined,
    category: SignalCategory
): SignalPostType {
    const text = (title + " " + (summary ?? "")).toLowerCase();

    if (DEATH_KEYWORDS.some((k) => text.includes(k))) return "DEATH";
    if (CONFIRMED_KEYWORDS.some((k) => text.includes(k))) return "CASE_CONFIRMED";
    if (category === "IMPORTED" || IMPORTED_POST_KEYWORDS.some((k) => text.includes(k))) return "CASE_IMPORTED";
    if (SUSPECTED_KEYWORDS.some((k) => text.includes(k))) return "CASE_SUSPECTED";
    if (category === "RESPONSE" || OFFICIAL_RESPONSE_KEYWORDS.some((k) => text.includes(k))) return "OFFICIAL_RESPONSE";
    if (EXPERT_VOICE_KEYWORDS.some((k) => text.includes(k))) return "EXPERT_VOICE";
    if (category === "LOCAL" || GENERIC_CASE_KEYWORDS.some((k) => text.includes(k))) return "CASE_CONFIRMED";
    return "PUBLIC_DISCOURSE";
}
