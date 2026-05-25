// Best-effort ISO-3166 country detection from a free-text headline + summary.
// Pure heuristic — keyword + ISO match. No LLM, no network calls.
//
// We err on the side of NULL: if we can't be confident, leave countryISO unset.
// The map UI shows uncategorised signals in the "global" feed, not pinned to a
// random country.
//
// Coverage emphasis follows hantavirus epidemiology rather than world GDP —
// the regional aliases below are deliberately tuned to the Americas (Andes
// hot zone: AR Patagonia, CL Aysén, BR Mato Grosso; US Four Corners region),
// Europe (Puumala-endemic Nordic + Dobrava-endemic Balkans), and East Asia
// (Seoul-virus distribution in KR/CN/RU). A signal that drops into a
// non-aliased region is less likely to be hantavirus anyway, so the trade-off
// is acceptable.

const COUNTRIES: Array<{ iso: string; aliases: string[] }> = [
    // ── Americas (Andes-virus / Sin Nombre hot zone) ─────────────────────
    {
        iso: "US",
        aliases: [
            "united states", "usa", "u.s.", "u.s.a.", "america", "american", " us ",
            // Four Corners hantavirus region — high incidence of Sin Nombre cases
            "new mexico", "arizona", "colorado", "utah", "four corners",
            // Additional state names that show up in CDC HAN bulletins
            "california", "nevada", "wyoming", "south dakota", "north dakota",
            "montana", "idaho", "oregon", "washington state"
        ]
    },
    {
        iso: "CA",
        aliases: ["canada", "canadian", "british columbia", "alberta", "saskatchewan", "manitoba"]
    },
    { iso: "MX", aliases: ["mexico", "mexican", "méxico", "mexicano"] },
    {
        iso: "BR",
        aliases: [
            "brazil", "brazilian", "brasil", "brasileiro", "brasileira",
            // States with recurring HPS clusters (rural south / southeast)
            "mato grosso", "paraná", "parana", "santa catarina",
            "rio grande do sul", "minas gerais", "são paulo", "sao paulo"
        ]
    },
    {
        iso: "AR",
        aliases: [
            "argentina", "argentine", "argentino", "argentina's",
            // Andes-virus high-incidence regions
            "patagonia", "patagonian", "neuquén", "neuquen", "río negro", "rio negro",
            "chubut", "santa cruz argentina", "el bolsón", "el bolson",
            "bariloche", "esquel"
        ]
    },
    {
        iso: "CL",
        aliases: [
            "chile", "chilean", "chileno", "chilena",
            // Andes-virus endemic regions
            "aysén", "aysen", "los lagos", "los ríos", "los rios",
            "la araucanía", "araucania", "biobío", "biobio", "magallanes"
        ]
    },
    { iso: "PE", aliases: ["peru", "peruvian", "perú", "peruano"] },
    {
        iso: "BO",
        aliases: [
            "bolivia", "bolivian", "boliviano",
            "santa cruz de la sierra", "santa cruz bolivia"
        ]
    },
    { iso: "CO", aliases: ["colombia", "colombian", "colombiano"] },
    { iso: "VE", aliases: ["venezuela", "venezuelan", "venezolano"] },
    { iso: "PY", aliases: ["paraguay", "paraguayan", "paraguayo"] },
    { iso: "UY", aliases: ["uruguay", "uruguayan", "uruguayo"] },
    { iso: "EC", aliases: ["ecuador", "ecuadorian", "ecuatoriano"] },
    { iso: "PA", aliases: ["panama", "panamá", "panamanian"] },
    { iso: "CR", aliases: ["costa rica", "costa rican"] },

    // ── Europe (Puumala + Dobrava-Belgrade) ──────────────────────────────
    {
        iso: "GB",
        aliases: ["united kingdom", " uk ", "britain", "british", "england", "scotland", "wales"]
    },
    { iso: "IE", aliases: ["ireland", "irish", "republic of ireland"] },
    { iso: "FR", aliases: ["france", "french", "française"] },
    {
        iso: "DE",
        aliases: [
            "germany", "german", "deutschland", "deutsche",
            // Regions with recurring Puumala outbreaks
            "bayern", "bavaria", "baden-württemberg", "baden-wurttemberg",
            "nordrhein-westfalen", "north rhine-westphalia"
        ]
    },
    { iso: "ES", aliases: ["spain", "spanish", "españa", "español", "tenerife", "canary islands"] },
    { iso: "PT", aliases: ["portugal", "portuguese", "português"] },
    { iso: "IT", aliases: ["italy", "italian", "italia", "italiano"] },
    { iso: "NL", aliases: ["netherlands", "dutch", "holland", "nederland"] },
    { iso: "BE", aliases: ["belgium", "belgian", "belgique", "belgië"] },
    { iso: "CH", aliases: ["switzerland", "swiss", "suisse", "schweiz"] },
    { iso: "AT", aliases: ["austria", "austrian", "österreich", "osterreich"] },
    { iso: "PL", aliases: ["poland", "polish", "polska"] },
    { iso: "CZ", aliases: ["czech republic", "czechia", "czech"] },
    { iso: "SK", aliases: ["slovakia", "slovak republic", "slovensko"] },
    { iso: "SI", aliases: ["slovenia", "slovenian", "slovenija"] },
    { iso: "HR", aliases: ["croatia", "croatian", "hrvatska"] },
    { iso: "BA", aliases: ["bosnia", "bosnia and herzegovina", "herzegovina", "bosnian"] },
    { iso: "RS", aliases: ["serbia", "serbian", "srbija"] },
    { iso: "ME", aliases: ["montenegro", "montenegrin"] },
    { iso: "MK", aliases: ["north macedonia", "macedonia"] },
    { iso: "BG", aliases: ["bulgaria", "bulgarian"] },
    { iso: "AL", aliases: ["albania", "albanian"] },
    { iso: "SE", aliases: ["sweden", "swedish", "sverige"] },
    { iso: "NO", aliases: ["norway", "norwegian", "norge"] },
    { iso: "FI", aliases: ["finland", "finnish", "suomi"] },
    { iso: "DK", aliases: ["denmark", "danish", "danmark"] },
    { iso: "IS", aliases: ["iceland", "icelandic"] },
    { iso: "EE", aliases: ["estonia", "estonian", "eesti"] },
    { iso: "LV", aliases: ["latvia", "latvian"] },
    { iso: "LT", aliases: ["lithuania", "lithuanian"] },
    { iso: "GR", aliases: ["greece", "greek", "ελλάδα"] },
    { iso: "RO", aliases: ["romania", "romanian", "românia"] },
    { iso: "HU", aliases: ["hungary", "hungarian", "magyarország"] },
    { iso: "UA", aliases: ["ukraine", "ukrainian", "україна"] },
    { iso: "BY", aliases: ["belarus", "belarusian"] },
    { iso: "MD", aliases: ["moldova", "moldovan"] },
    { iso: "RU", aliases: ["russia", "russian", "россия", "rossiya"] },
    { iso: "TR", aliases: ["turkey", "türkiye", "turkish", "türk"] },
    { iso: "CY", aliases: ["cyprus", "cypriot"] },
    { iso: "MT", aliases: ["malta", "maltese"] },

    // ── Africa ──────────────────────────────────────────────────────────
    { iso: "ZA", aliases: ["south africa", "south african"] },
    { iso: "EG", aliases: ["egypt", "egyptian", "مصر"] },
    { iso: "NG", aliases: ["nigeria", "nigerian"] },
    { iso: "KE", aliases: ["kenya", "kenyan"] },
    { iso: "ET", aliases: ["ethiopia", "ethiopian"] },
    { iso: "MA", aliases: ["morocco", "moroccan", "maroc"] },
    { iso: "DZ", aliases: ["algeria", "algerian", "algérie"] },
    { iso: "TN", aliases: ["tunisia", "tunisian", "tunisie"] },
    { iso: "LY", aliases: ["libya", "libyan"] },
    { iso: "GH", aliases: ["ghana", "ghanaian"] },
    { iso: "AO", aliases: ["angola", "angolan"] },
    { iso: "TZ", aliases: ["tanzania", "tanzanian"] },
    { iso: "UG", aliases: ["uganda", "ugandan"] },
    { iso: "RW", aliases: ["rwanda", "rwandan"] },
    { iso: "MG", aliases: ["madagascar", "malagasy"] },
    { iso: "MZ", aliases: ["mozambique", "mozambican"] },
    { iso: "ZW", aliases: ["zimbabwe", "zimbabwean"] },
    { iso: "ZM", aliases: ["zambia", "zambian"] },
    { iso: "CD", aliases: ["democratic republic of the congo", "dr congo", "dem rep congo", "drc"] },
    { iso: "CG", aliases: ["republic of the congo", "congo-brazzaville", "congo brazzaville"] },
    { iso: "SN", aliases: ["senegal", "senegalese"] },
    { iso: "CI", aliases: ["côte d'ivoire", "cote d'ivoire", "ivory coast", "ivorian"] },
    { iso: "CM", aliases: ["cameroon", "cameroonian"] },
    { iso: "SD", aliases: ["sudan", "sudanese"] },
    { iso: "SS", aliases: ["south sudan"] },
    { iso: "SO", aliases: ["somalia", "somali"] },

    // ── Middle East ─────────────────────────────────────────────────────
    { iso: "SA", aliases: ["saudi arabia", "saudi"] },
    { iso: "IR", aliases: ["iran", "iranian"] },
    { iso: "IQ", aliases: ["iraq", "iraqi"] },
    { iso: "IL", aliases: ["israel", "israeli"] },
    { iso: "JO", aliases: ["jordan", "jordanian"] },
    { iso: "LB", aliases: ["lebanon", "lebanese"] },
    { iso: "SY", aliases: ["syria", "syrian"] },
    { iso: "YE", aliases: ["yemen", "yemeni"] },
    { iso: "OM", aliases: ["oman", "omani"] },
    { iso: "AE", aliases: ["united arab emirates", "uae", "emirati"] },
    { iso: "QA", aliases: ["qatar", "qatari"] },
    { iso: "KW", aliases: ["kuwait", "kuwaiti"] },
    { iso: "BH", aliases: ["bahrain", "bahraini"] },
    { iso: "AF", aliases: ["afghanistan", "afghan"] },

    // ── South + Central Asia ────────────────────────────────────────────
    { iso: "PK", aliases: ["pakistan", "pakistani"] },
    { iso: "IN", aliases: ["india", "indian", "भारत"] },
    { iso: "BD", aliases: ["bangladesh", "bangladeshi"] },
    { iso: "LK", aliases: ["sri lanka", "sri lankan"] },
    { iso: "NP", aliases: ["nepal", "nepalese", "nepali"] },
    { iso: "BT", aliases: ["bhutan", "bhutanese"] },
    { iso: "KZ", aliases: ["kazakhstan", "kazakh"] },
    { iso: "UZ", aliases: ["uzbekistan", "uzbek"] },
    { iso: "KG", aliases: ["kyrgyzstan", "kyrgyz"] },
    { iso: "TJ", aliases: ["tajikistan", "tajik"] },
    { iso: "MN", aliases: ["mongolia", "mongolian"] },

    // ── East Asia (Seoul virus + Hantaan virus distribution) ───────────
    { iso: "CN", aliases: ["china", "chinese", "中国"] },
    { iso: "JP", aliases: ["japan", "japanese", "日本"] },
    {
        iso: "KR",
        aliases: ["south korea", "korea", "korean", "republic of korea", "rok", "한국"]
    },
    { iso: "KP", aliases: ["north korea", "dprk"] },
    { iso: "TW", aliases: ["taiwan", "taiwanese"] },

    // ── Southeast Asia ──────────────────────────────────────────────────
    { iso: "ID", aliases: ["indonesia", "indonesian"] },
    { iso: "PH", aliases: ["philippines", "filipino", "philippine"] },
    { iso: "TH", aliases: ["thailand", "thai"] },
    { iso: "VN", aliases: ["vietnam", "vietnamese"] },
    { iso: "MY", aliases: ["malaysia", "malaysian"] },
    { iso: "SG", aliases: ["singapore", "singaporean"] },
    { iso: "MM", aliases: ["myanmar", "burmese", "burma"] },
    { iso: "KH", aliases: ["cambodia", "cambodian"] },
    { iso: "LA", aliases: ["laos", "laotian"] },

    // ── Oceania ─────────────────────────────────────────────────────────
    { iso: "AU", aliases: ["australia", "australian"] },
    { iso: "NZ", aliases: ["new zealand", "new zealander"] },
    { iso: "PG", aliases: ["papua new guinea"] },
    { iso: "FJ", aliases: ["fiji", "fijian"] }
];

// Source-bucket → fallback ISO, when the headline gives no signal.
//
// Two groups:
//   - Geographically-scoped national sources: their items implicitly refer
//     to that country (e.g. Argentina's Ministry of Health bulletin is
//     almost always about Argentina even when the headline doesn't say so).
//   - Multilingual GoogleNews regional buckets: a French-language item from
//     fr-FR is most likely about France absent any other country reference.
//
// Multi-country regional sources (PAHO, Africa CDC, WHO EMRO/SEARO,
// MEDISYS, HealthMap, ECDC, ProMED) deliberately have NO fallback — a
// generic regional headline shouldn't pin to a random country. The map
// UI handles `countryISO = null` as an unpinned signal so we don't lose
// the data, we just don't fabricate a location for it.
const BUCKET_FALLBACK: Record<string, string> = {
    // National public-health authorities — scoped to one country.
    "CDC-HAN":       "US",
    "MoH-Argentina": "AR",
    "MoH-Chile":     "CL",
    "MoH-Brazil":    "BR",
    // GoogleNews-* (existing). Weaker fallback than the national sources
    // above because GoogleNews regional editions sometimes carry stories
    // about other countries.
    "GoogleNews-en-US": "US",
    "GoogleNews-en-GB": "GB",
    "GoogleNews-en-IN": "IN",
    "GoogleNews-en-AU": "AU",
    "GoogleNews-en-CA": "CA",
    "GoogleNews-en-NZ": "NZ",
    "GoogleNews-de-DE": "DE",
    "GoogleNews-fr-FR": "FR",
    "GoogleNews-es-ES": "ES",
    "GoogleNews-pt-BR": "BR",
    "GoogleNews-it-IT": "IT",
    "GoogleNews-nl-NL": "NL",
    "GoogleNews-tr-TR": "TR",
    "GoogleNews-zh-CN": "CN",
    "GoogleNews-zh-TW": "TW",
    "GoogleNews-ja-JP": "JP",
    "GoogleNews-ko-KR": "KR",
    "GoogleNews-pl-PL": "PL",
    "GoogleNews-ru-RU": "RU",
    "GoogleNews-uk-UA": "UA",
    "GoogleNews-vi-VN": "VN",
    "GoogleNews-id-ID": "ID",
    "GoogleNews-th-TH": "TH",
    "GoogleNews-ar-SA": "SA"
};

/**
 * Detect an ISO-3166 country code for a news item.
 *
 * Priority:
 *   1. Keyword match in `title` (or in `description` if title is silent).
 *      The first match wins; aliases are ordered most-specific first within
 *      each country (e.g. "patagonia" before "argentina") so a regional
 *      mention doesn't get swallowed by a broader alias on a different
 *      country.
 *   2. `BUCKET_FALLBACK` for sources that are inherently scoped to one
 *      country.
 *   3. `null` — let the map render the signal in the "global" feed without
 *      a country pin. Never fabricate a location.
 *
 * `description` was added in 2026-05 because many WHO / HealthMap / MEDISYS
 * items put the country in the body of the announcement rather than the
 * headline ("WHO confirms Hantavirus cluster" → title carries no country,
 * description says "in Argentina's Río Negro province"). The previous
 * title-only matcher silently dropped these into the null-pin bucket.
 */
export function detectCountry(
    title: string,
    sourceBucket: string,
    description?: string | null
): string | null {
    const haystack = ` ${(title + " " + (description ?? "")).toLowerCase()} `;
    for (const c of COUNTRIES) {
        for (const alias of c.aliases) {
            if (haystack.includes(alias)) {
                return c.iso;
            }
        }
    }
    // Fallback: source bucket maps to one country.
    if (sourceBucket in BUCKET_FALLBACK) {
        return BUCKET_FALLBACK[sourceBucket];
    }
    return null;
}
