// Disease tagging for ingested signals. The pipeline now carries two diseases
// (Hantavirus + Ebola), so every signal, aggregate, and classification is
// tagged so the API can serve `?disease=` at parity.

export type DiseaseTag = "hantavirus" | "ebola";

/// Hantaviridae keywords (covers the four major serotypes + the regional
/// spellings used by non-English health authorities). HPS = Hantavirus
/// Pulmonary Syndrome; HCPS = Cardiopulmonary; HFRS = Haemorrhagic Fever with
/// Renal Syndrome.
export const HANTA_FILTER =
    /hantavirus|hantavirál|hantavírus|HFRS|HCPS|HPS\b|sin nombre|andes virus|seoul virus|puumala|dobrava/i;

/// Ebolavirus keywords. Deliberately ebola-specific — we do NOT include the
/// generic "viral haemorrhagic fever" (which also describes HFRS) or Marburg
/// (a separate filovirus), to avoid mis-tagging. Covers the four human-
/// pathogenic species + the common short forms and non-English spelling.
export const EBOLA_FILTER =
    /\bebola\b|ébola|\bEVD\b|ebola virus disease|ebolavirus|zaire ebolavirus|sudan ebolavirus|bundibugyo|ta[ïi] forest/i;

/// Union filter for general-purpose feeds (ProMED, regional news, etc.): we
/// ingest an item if it mentions either disease, then `detectDisease` decides
/// which bucket it lands in.
export const TOPIC_FILTER_ANY = new RegExp(
    `(${HANTA_FILTER.source})|(${EBOLA_FILTER.source})`,
    "i"
);

function countMatches(re: RegExp, hay: string): number {
    const g = new RegExp(re.source, "gi");
    return (hay.match(g) ?? []).length;
}

/// Classify an item's disease from its text. Returns `null` when neither
/// disease is clearly present (general feeds pass items through `TOPIC_FILTER_ANY`
/// first, so a `null` here means an ambiguous / off-topic item we should skip).
/// When both diseases are mentioned (rare cross-disease roundups), the one with
/// more keyword hits wins; a tie returns `null` so we don't guess.
export function detectDisease(
    title: string,
    summary: string | null | undefined,
    _sourceBucket?: string
): DiseaseTag | null {
    const hay = `${title} ${summary ?? ""}`;
    const ebola = EBOLA_FILTER.test(hay);
    const hanta = HANTA_FILTER.test(hay);
    if (ebola && !hanta) return "ebola";
    if (hanta && !ebola) return "hantavirus";
    if (!ebola && !hanta) return null;
    // Both mentioned — decide by keyword density.
    const e = countMatches(EBOLA_FILTER, hay);
    const h = countMatches(HANTA_FILTER, hay);
    if (e > h) return "ebola";
    if (h > e) return "hantavirus";
    return null;
}
