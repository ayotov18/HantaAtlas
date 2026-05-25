import Foundation

enum Fixtures {
    static let cdc = Source(id: "cdc", organisation: "CDC", url: URL(string: "https://www.cdc.gov/hantavirus/")!)
    static let ecdc = Source(id: "ecdc", organisation: "ECDC", url: URL(string: "https://www.ecdc.europa.eu/")!)
    static let paho = Source(id: "paho", organisation: "PAHO", url: URL(string: "https://www.paho.org/")!)
    static let who = Source(id: "who", organisation: "WHO", url: URL(string: "https://www.who.int/emergencies/disease-outbreak-news")!)
    static let cdcEbola = Source(id: "cdc-ebola", organisation: "CDC", url: URL(string: "https://www.cdc.gov/ebola/")!)
    static let africaCdc = Source(id: "africa-cdc", organisation: "Africa CDC", url: URL(string: "https://africacdc.org/")!)
    static let ministry = Source(id: "ministry-ar", organisation: "National Ministry of Health", url: URL(string: "https://www.argentina.gob.ar/salud")!)

    static let checkedAt = Date.fixture("2026-05-08T09:41:00+03:00")

    static let summary = AppSummary(
        checkedAt: checkedAt,
        countryCount: 94,
        officialAlertCount: 3,
        savedCount: 7
    )

    static let ebolaSummary = AppSummary(
        checkedAt: checkedAt,
        countryCount: 4,
        officialAlertCount: 2,
        savedCount: 0
    )

    static let countries: [CountrySnapshot] = [
        CountrySnapshot(
            id: "US-2026",
            isoCode: "US",
            countryName: "United States",
            regionName: "North America",
            cases: 11,
            deaths: 2,
            reportingPeriodLabel: "2026 year to date",
            reportedAt: Date.fixture("2026-04-30T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-03T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: cdc,
            sourceUrl: cdc.url,
            summary: "Confirmed cases remain rare and are reported through national public-health surveillance.",
            virusType: "Sin Nombre virus",
            limitations: "Publication cadence and state-level detail vary. This display is not a complete exposure-risk estimate.",
            confidenceLevel: .officialStructuredData,
            trend: [TrendPoint(label: "2022", cases: 8), TrendPoint(label: "2023", cases: 9), TrendPoint(label: "2024", cases: 12), TrendPoint(label: "2025", cases: 10), TrendPoint(label: "2026", cases: 11)]
        ),
        CountrySnapshot(
            id: "AR-2026",
            isoCode: "AR",
            countryName: "Argentina",
            regionName: "South America",
            cases: 18,
            deaths: 4,
            reportingPeriodLabel: "Recent official alert",
            reportedAt: Date.fixture("2026-05-05T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-07T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: paho,
            sourceUrl: paho.url,
            summary: "Official regional alerts note confirmed Andes virus cases and prevention guidance for rural settings.",
            virusType: "Andes virus",
            limitations: "Current public data is alert-led. Comparable national time-series surveillance is not assumed in this MVP.",
            confidenceLevel: .officialAlert,
            trend: [TrendPoint(label: "2022", cases: 13), TrendPoint(label: "2023", cases: 16), TrendPoint(label: "2024", cases: 14), TrendPoint(label: "2025", cases: 19), TrendPoint(label: "2026", cases: 18)]
        ),
        CountrySnapshot(
            id: "DE-2026",
            isoCode: "DE",
            countryName: "Germany",
            regionName: "Europe",
            cases: 64,
            deaths: 0,
            reportingPeriodLabel: "2025 annual surveillance",
            reportedAt: Date.fixture("2025-12-31T12:00:00Z"),
            publishedAt: Date.fixture("2026-03-18T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: ecdc,
            sourceUrl: ecdc.url,
            summary: "European surveillance supports country-level comparison and annual trend context.",
            virusType: "Puumala virus",
            limitations: "Local drill-down should only be shown where official regional data supports it.",
            confidenceLevel: .officialStructuredData,
            trend: [TrendPoint(label: "2021", cases: 41), TrendPoint(label: "2022", cases: 53), TrendPoint(label: "2023", cases: 49), TrendPoint(label: "2024", cases: 57), TrendPoint(label: "2025", cases: 64)]
        ),
        CountrySnapshot(
            id: "CL-2026",
            isoCode: "CL",
            countryName: "Chile",
            regionName: "South America",
            cases: 7,
            deaths: 1,
            reportingPeriodLabel: "Recent official alert",
            reportedAt: Date.fixture("2026-04-28T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-01T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: ministry,
            sourceUrl: ministry.url,
            summary: "Ministry guidance emphasises rural exposure prevention and prompt clinical assessment for symptoms.",
            virusType: "Andes virus",
            limitations: "Alert formats differ by ministry and may not include a complete national table.",
            confidenceLevel: .officialAlert,
            trend: [TrendPoint(label: "2022", cases: 8), TrendPoint(label: "2023", cases: 6), TrendPoint(label: "2024", cases: 10), TrendPoint(label: "2025", cases: 8), TrendPoint(label: "2026", cases: 7)]
        ),
        CountrySnapshot(
            id: "PE-2026",
            isoCode: "PE",
            countryName: "Peru",
            regionName: "South America",
            cases: nil,
            deaths: nil,
            reportingPeriodLabel: "No recent public data",
            reportedAt: nil,
            publishedAt: nil,
            lastCheckedAt: checkedAt,
            source: paho,
            sourceUrl: paho.url,
            summary: "No recent public country-level hantavirus surveillance was found in monitored official channels.",
            virusType: "Not specified",
            limitations: "No recent public data is not the same as zero cases.",
            confidenceLevel: .noRecentPublicData,
            trend: []
        )
    ]

    static let ebolaCountries: [CountrySnapshot] = [
        CountrySnapshot(
            id: "CD-EBOLA-2026",
            isoCode: "CD",
            countryName: "Democratic Republic of the Congo",
            regionName: "Central Africa",
            cases: 23,
            deaths: 12,
            reportingPeriodLabel: "Active official outbreak notice",
            reportedAt: Date.fixture("2026-05-03T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-08T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: who,
            sourceUrl: who.url,
            summary: "WHO outbreak notices and national updates describe active Ebola disease monitoring with affected areas and changing case classifications.",
            virusType: "Bundibugyo ebolavirus",
            limitations: "Counts may change as suspected, probable, and confirmed cases are reclassified by official investigations.",
            confidenceLevel: .officialAlert,
            trend: [TrendPoint(label: "Wk 1", cases: 7), TrendPoint(label: "Wk 2", cases: 12), TrendPoint(label: "Wk 3", cases: 18), TrendPoint(label: "Wk 4", cases: 23)]
        ),
        CountrySnapshot(
            id: "UG-EBOLA-2026",
            isoCode: "UG",
            countryName: "Uganda",
            regionName: "East Africa",
            cases: 4,
            deaths: 1,
            reportingPeriodLabel: "Cross-border monitoring notice",
            reportedAt: Date.fixture("2026-05-04T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-08T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: who,
            sourceUrl: who.url,
            summary: "Official notices describe monitoring linked to the regional Ebola event. The app keeps imported and local signals separated.",
            virusType: "Bundibugyo ebolavirus",
            limitations: "Public updates may emphasize response activity before complete case tables are available.",
            confidenceLevel: .officialAlert,
            trend: [TrendPoint(label: "Wk 1", cases: 1), TrendPoint(label: "Wk 2", cases: 2), TrendPoint(label: "Wk 3", cases: 4)]
        ),
        CountrySnapshot(
            id: "GN-EBOLA-HISTORICAL",
            isoCode: "GN",
            countryName: "Guinea",
            regionName: "West Africa",
            cases: nil,
            deaths: nil,
            reportingPeriodLabel: "Historical context",
            reportedAt: nil,
            publishedAt: Date.fixture("2026-04-20T12:00:00Z"),
            lastCheckedAt: checkedAt,
            source: cdcEbola,
            sourceUrl: cdcEbola.url,
            summary: "CDC historical outbreak material is used for context only, not as a live case-count authority.",
            virusType: "Zaire ebolavirus",
            limitations: "Historical context does not imply current local transmission.",
            confidenceLevel: .officialStructuredData,
            trend: []
        ),
        CountrySnapshot(
            id: "SL-EBOLA-HISTORICAL",
            isoCode: "SL",
            countryName: "Sierra Leone",
            regionName: "West Africa",
            cases: nil,
            deaths: nil,
            reportingPeriodLabel: "No current official event cached",
            reportedAt: nil,
            publishedAt: nil,
            lastCheckedAt: checkedAt,
            source: cdcEbola,
            sourceUrl: cdcEbola.url,
            summary: "No current official Ebola event is cached for this country in the local fixture set.",
            virusType: "Not specified",
            limitations: "No recent public data is not the same as zero risk or zero cases.",
            confidenceLevel: .noRecentPublicData,
            trend: []
        )
    ]

    static let alerts: [OfficialAlert] = [
        OfficialAlert(
            id: "bo-santa-cruz",
            title: "Hantavirus outbreak investigation",
            countryName: "Bolivia - Santa Cruz Department",
            regionName: "Americas",
            source: paho,
            severity: .high,
            confidenceLevel: .officialAlert,
            reportedAt: Date.fixture("2026-05-05T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-07T12:00:00Z"),
            summary: "Health authorities are investigating an increase in officially reported cases in rural communities."
        ),
        OfficialAlert(
            id: "ecdc-annual",
            title: "Hantavirus surveillance update",
            countryName: "European Union / EEA",
            regionName: "Europe",
            source: ecdc,
            severity: .low,
            confidenceLevel: .officialStructuredData,
            reportedAt: Date.fixture("2025-12-31T12:00:00Z"),
            publishedAt: Date.fixture("2026-03-18T12:00:00Z"),
            summary: "Routine surveillance summary published with country-level case counts and known reporting limitations."
        ),
        OfficialAlert(
            id: "who-travel",
            title: "Multi-country exposure notice",
            countryName: "Multiple countries",
            regionName: "Global",
            source: who,
            severity: .medium,
            confidenceLevel: .officialAlert,
            reportedAt: Date.fixture("2026-05-01T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-04T12:00:00Z"),
            summary: "Official notice highlights why cross-border monitoring matters when exposure history spans travel routes."
        )
    ]

    static let ebolaAlerts: [OfficialAlert] = [
        OfficialAlert(
            id: "who-ebola-drc-uganda",
            title: "Ebola disease official outbreak notice",
            countryName: "DRC and Uganda",
            regionName: "Africa",
            source: who,
            severity: .high,
            confidenceLevel: .officialAlert,
            reportedAt: Date.fixture("2026-05-03T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-08T12:00:00Z"),
            summary: "Official source-backed notice with affected areas, case classifications, and response context."
        ),
        OfficialAlert(
            id: "cdc-ebola-situation",
            title: "Ebola current situation context",
            countryName: "Global",
            regionName: "Reference",
            source: cdcEbola,
            severity: .medium,
            confidenceLevel: .officialStructuredData,
            reportedAt: Date.fixture("2026-04-30T12:00:00Z"),
            publishedAt: Date.fixture("2026-05-02T12:00:00Z"),
            summary: "CDC situation material provides context and travel-health framing without replacing local official notices."
        )
    ]

    static let guideArticles: [GuideArticle] = [
        GuideArticle(id: "ventilate", section: .prevention, title: "Ventilate closed spaces", body: "Open doors and windows before entering sheds, cabins, barns, or unused buildings.", symbolName: "window.vertical.open"),
        GuideArticle(id: "wet-dust", section: .prevention, title: "Wet down dust", body: "Lightly wet contaminated surfaces before cleaning to avoid stirring particles into the air.", symbolName: "drop.fill"),
        GuideArticle(id: "seal-food", section: .prevention, title: "Seal food and entry points", body: "Store food in rodent-resistant containers and close holes in walls or foundations.", symbolName: "shippingbox.fill"),
        GuideArticle(id: "seek-care", section: .prevention, title: "Seek care for warning signs", body: "Get medical help promptly for fever with fatigue or muscle aches, especially after possible exposure.", symbolName: "cross.case.fill"),
        GuideArticle(id: "early", section: .symptoms, title: "Early symptoms", body: "Fever, fatigue, muscle aches, headache, dizziness, chills, nausea, or abdominal symptoms can occur.", symbolName: "thermometer.medium"),
        GuideArticle(id: "breathing", section: .symptoms, title: "Breathing symptoms", body: "Cough, shortness of breath, chest tightness, or rapid worsening should be assessed urgently.", symbolName: "lungs.fill"),
        GuideArticle(id: "urgent-breathing", section: .urgentCare, title: "Breathing trouble", body: "Seek urgent medical care for shortness of breath after possible rodent exposure.", symbolName: "exclamationmark.triangle.fill"),
        GuideArticle(id: "tell-clinician", section: .urgentCare, title: "Share exposure details", body: "Tell a clinician about cabins, field work, barns, camping, or rodent-contaminated spaces.", symbolName: "person.text.rectangle.fill")
    ]

    static let ebolaGuideArticles: [GuideArticle] = [
        GuideArticle(id: "ebola-avoid-fluids", section: .prevention, title: "Avoid direct contact", body: "Avoid direct contact with blood, body fluids, or items that may be contaminated during an official Ebola event.", symbolName: "hand.raised.fill"),
        GuideArticle(id: "ebola-wildlife", section: .prevention, title: "Avoid sick or dead wildlife", body: "Do not handle sick or dead wildlife in affected areas. Follow local public-health guidance.", symbolName: "leaf.fill"),
        GuideArticle(id: "ebola-symptoms", section: .symptoms, title: "Symptoms need assessment", body: "Fever, weakness, aches, vomiting, diarrhoea, or bleeding symptoms require official clinical guidance, especially after exposure.", symbolName: "thermometer.medium"),
        GuideArticle(id: "ebola-call-ahead", section: .urgentCare, title: "Call ahead for care", body: "If exposed or symptomatic in an affected area, contact local health authorities or a clinician before arriving when possible.", symbolName: "phone.fill"),
        GuideArticle(id: "ebola-emergency", section: .urgentCare, title: "Emergency symptoms", body: "Seek urgent local medical help for severe illness. HantaAtlas does not provide emergency instructions.", symbolName: "exclamationmark.triangle.fill")
    ]

    static let mapCountries: [MapCountry] = [
        MapCountry(id: "US", isoCode: "US", name: "United States", confidenceLevel: .officialStructuredData, cases: 11, alerts: 0, polygons: [[MapPoint(x: 0.12, y: 0.33), MapPoint(x: 0.30, y: 0.29), MapPoint(x: 0.34, y: 0.45), MapPoint(x: 0.19, y: 0.52), MapPoint(x: 0.10, y: 0.43)]]),
        MapCountry(id: "CA", isoCode: "CA", name: "Canada", confidenceLevel: .officialStructuredData, cases: 2, alerts: 0, polygons: [[MapPoint(x: 0.12, y: 0.20), MapPoint(x: 0.34, y: 0.16), MapPoint(x: 0.31, y: 0.30), MapPoint(x: 0.14, y: 0.32)]]),
        MapCountry(id: "BR", isoCode: "BR", name: "Brazil", confidenceLevel: .mediaSignal, cases: nil, alerts: 1, polygons: [[MapPoint(x: 0.34, y: 0.61), MapPoint(x: 0.47, y: 0.66), MapPoint(x: 0.42, y: 0.80), MapPoint(x: 0.30, y: 0.76), MapPoint(x: 0.27, y: 0.66)]]),
        MapCountry(id: "AR", isoCode: "AR", name: "Argentina", confidenceLevel: .officialAlert, cases: 18, alerts: 1, polygons: [[MapPoint(x: 0.31, y: 0.78), MapPoint(x: 0.38, y: 0.80), MapPoint(x: 0.36, y: 0.94), MapPoint(x: 0.29, y: 0.90)]]),
        MapCountry(id: "CL", isoCode: "CL", name: "Chile", confidenceLevel: .officialAlert, cases: 7, alerts: 1, polygons: [[MapPoint(x: 0.27, y: 0.76), MapPoint(x: 0.30, y: 0.77), MapPoint(x: 0.29, y: 0.94), MapPoint(x: 0.25, y: 0.91)]]),
        MapCountry(id: "DE", isoCode: "DE", name: "Germany", confidenceLevel: .officialStructuredData, cases: 64, alerts: 0, polygons: [[MapPoint(x: 0.53, y: 0.35), MapPoint(x: 0.58, y: 0.35), MapPoint(x: 0.59, y: 0.43), MapPoint(x: 0.52, y: 0.43)]]),
        MapCountry(id: "CN", isoCode: "CN", name: "China", confidenceLevel: .officialAlert, cases: nil, alerts: 1, polygons: [[MapPoint(x: 0.70, y: 0.42), MapPoint(x: 0.86, y: 0.40), MapPoint(x: 0.87, y: 0.55), MapPoint(x: 0.72, y: 0.57)]]),
        MapCountry(id: "ZA", isoCode: "ZA", name: "South Africa", confidenceLevel: .noRecentPublicData, cases: nil, alerts: 0, polygons: [[MapPoint(x: 0.55, y: 0.79), MapPoint(x: 0.64, y: 0.78), MapPoint(x: 0.65, y: 0.88), MapPoint(x: 0.57, y: 0.90)]]),
        MapCountry(id: "AU", isoCode: "AU", name: "Australia", confidenceLevel: .officialStructuredData, cases: 0, alerts: 0, polygons: [[MapPoint(x: 0.80, y: 0.74), MapPoint(x: 0.94, y: 0.76), MapPoint(x: 0.92, y: 0.88), MapPoint(x: 0.78, y: 0.86)]])
    ]

    static let ebolaMapCountries: [MapCountry] = [
        MapCountry(id: "CD", isoCode: "CD", name: "DRC", confidenceLevel: .officialAlert, cases: 23, alerts: 1, polygons: [[MapPoint(x: 0.55, y: 0.59), MapPoint(x: 0.62, y: 0.58), MapPoint(x: 0.63, y: 0.68), MapPoint(x: 0.55, y: 0.69)]]),
        MapCountry(id: "UG", isoCode: "UG", name: "Uganda", confidenceLevel: .officialAlert, cases: 4, alerts: 1, polygons: [[MapPoint(x: 0.63, y: 0.57), MapPoint(x: 0.66, y: 0.57), MapPoint(x: 0.66, y: 0.61), MapPoint(x: 0.63, y: 0.61)]]),
        MapCountry(id: "GN", isoCode: "GN", name: "Guinea", confidenceLevel: .officialStructuredData, cases: nil, alerts: 0, polygons: [[MapPoint(x: 0.47, y: 0.56), MapPoint(x: 0.50, y: 0.56), MapPoint(x: 0.50, y: 0.60), MapPoint(x: 0.47, y: 0.60)]]),
        MapCountry(id: "SL", isoCode: "SL", name: "Sierra Leone", confidenceLevel: .noRecentPublicData, cases: nil, alerts: 0, polygons: [[MapPoint(x: 0.46, y: 0.59), MapPoint(x: 0.49, y: 0.59), MapPoint(x: 0.49, y: 0.62), MapPoint(x: 0.46, y: 0.62)]])
    ]

    private struct SignalSeed {
        let iso: String
        let country: String
        let title: String
        let summary: String
        let bucket: String
        let category: SignalCategory
        let severity: AlertSeverity
        let postType: MapPostType
        let daysAgo: Int
    }

    private struct AggregateScratch {
        var last30dCount = 0
        var last6mCount = 0
        var last1yCount = 0
        var allTimeCount = 0
        var activeLevel: CountryActiveLevel = .none
        var lastSignalAt: Date?
    }

    private static let signalSeeds: [SignalSeed] = [
        SignalSeed(iso: "AR", country: "Argentina", title: "Provincial media report fatal Andes virus case under official follow-up", summary: "Public reports cite a fatal case and local prevention messaging; treat as media signal until matched to a ministry bulletin.", bucket: "PublicNews-es-AR", category: .media, severity: .high, postType: .death, daysAgo: 1),
        SignalSeed(iso: "CL", country: "Chile", title: "Regional report describes confirmed hantavirus infection after rural exposure", summary: "Case coverage references health authority statements and cabin-cleaning guidance.", bucket: "PublicNews-es-CL", category: .local, severity: .high, postType: .caseConfirmed, daysAgo: 2),
        SignalSeed(iso: "BO", country: "Bolivia", title: "Santa Cruz outlets report cluster investigation in rural communities", summary: "Coverage follows official statements about recent confirmed cases and field investigation.", bucket: "PublicNews-es-BO", category: .local, severity: .high, postType: .caseConfirmed, daysAgo: 3),
        SignalSeed(iso: "PY", country: "Paraguay", title: "Health advisory coverage urges rodent-exposure prevention during harvest", summary: "Local public-health reporting focuses on prevention guidance and seasonal exposure risk.", bucket: "PublicNews-es-PY", category: .response, severity: .medium, postType: .officialResponse, daysAgo: 4),
        SignalSeed(iso: "BR", country: "Brazil", title: "State media mention suspected hantavirus case awaiting laboratory confirmation", summary: "Report remains unverified in the app until official laboratory confirmation is published.", bucket: "PublicNews-pt-BR", category: .media, severity: .medium, postType: .caseSuspected, daysAgo: 5),
        SignalSeed(iso: "US", country: "United States", title: "Local outlet reports hantavirus death with county prevention reminder", summary: "Coverage references confirmed surveillance context and rodent-exposure prevention steps.", bucket: "PublicNews-en-US", category: .local, severity: .high, postType: .death, daysAgo: 6),
        SignalSeed(iso: "CA", country: "Canada", title: "Experts discuss prevention after western provinces report rare cases", summary: "Expert commentary is displayed as discourse unless paired with official surveillance updates.", bucket: "PublicNews-en-CA", category: .media, severity: .low, postType: .expertVoice, daysAgo: 7),
        SignalSeed(iso: "MX", country: "Mexico", title: "Newspaper coverage notes hantavirus prevention advice for rural work", summary: "No official case count is attached to this public report.", bucket: "PublicNews-es-MX", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 7),
        SignalSeed(iso: "PA", country: "Panama", title: "Public-health notice coverage highlights rural rodent exposure", summary: "Response-style signal linked to public prevention messaging.", bucket: "PublicNews-es-PA", category: .response, severity: .medium, postType: .officialResponse, daysAgo: 8),
        SignalSeed(iso: "CO", country: "Colombia", title: "Regional news mentions suspected hantavirus monitoring", summary: "Classified as media signal pending official confirmation.", bucket: "PublicNews-es-CO", category: .media, severity: .medium, postType: .caseSuspected, daysAgo: 9),
        SignalSeed(iso: "PE", country: "Peru", title: "Rural health coverage discusses hantavirus prevention after public questions", summary: "Displayed as public discourse, not as a confirmed case.", bucket: "PublicNews-es-PE", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 10),
        SignalSeed(iso: "UY", country: "Uruguay", title: "Media report prevention campaign for rural cleaning and storage", summary: "No case count attached; prevention context only.", bucket: "PublicNews-es-UY", category: .response, severity: .low, postType: .officialResponse, daysAgo: 11),
        SignalSeed(iso: "DE", country: "Germany", title: "Surveillance coverage reports Puumala virus seasonal case rise", summary: "Structured surveillance context is paired with local news coverage.", bucket: "PublicNews-de-DE", category: .local, severity: .medium, postType: .caseConfirmed, daysAgo: 12),
        SignalSeed(iso: "FI", country: "Finland", title: "Regional outlets report nephropathia epidemica case activity", summary: "Public report uses local clinical terminology associated with Puumala virus.", bucket: "PublicNews-fi-FI", category: .local, severity: .medium, postType: .caseConfirmed, daysAgo: 13),
        SignalSeed(iso: "SE", country: "Sweden", title: "Experts warn bank vole season may increase public-health enquiries", summary: "Expert voice signal; not a confirmed outbreak by itself.", bucket: "PublicNews-sv-SE", category: .media, severity: .low, postType: .expertVoice, daysAgo: 14),
        SignalSeed(iso: "NO", country: "Norway", title: "Local coverage discusses rodent-borne disease precautions for cabins", summary: "Prevention and public-interest coverage with no official case metric.", bucket: "PublicNews-no-NO", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 15),
        SignalSeed(iso: "FR", country: "France", title: "Clinicians discuss hantavirus diagnosis awareness in eastern regions", summary: "Professional commentary signal; shown separately from confirmed surveillance data.", bucket: "PublicNews-fr-FR", category: .media, severity: .low, postType: .expertVoice, daysAgo: 16),
        SignalSeed(iso: "ES", country: "Spain", title: "Imported case coverage mentions returning traveller under clinical care", summary: "Imported-case bucket helps users separate travel-linked cases from local transmission.", bucket: "PublicNews-es-ES", category: .imported, severity: .medium, postType: .caseImported, daysAgo: 17),
        SignalSeed(iso: "GB", country: "United Kingdom", title: "Travel health report mentions imported hantavirus case after exposure abroad", summary: "Classified as imported; the map should not colour it as local transmission.", bucket: "PublicNews-en-GB", category: .imported, severity: .medium, postType: .caseImported, daysAgo: 18),
        SignalSeed(iso: "IT", country: "Italy", title: "Regional newspaper discusses suspected case and laboratory testing", summary: "Suspected case remains separated from confirmed cases.", bucket: "PublicNews-it-IT", category: .media, severity: .medium, postType: .caseSuspected, daysAgo: 19),
        SignalSeed(iso: "PL", country: "Poland", title: "Public-health explainer references hantavirus prevention for farmers", summary: "Information signal; no official case metric attached.", bucket: "PublicNews-pl-PL", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 20),
        SignalSeed(iso: "RO", country: "Romania", title: "Hospital bulletin coverage references confirmed hantavirus infection", summary: "Reported case signal awaiting structured official source match.", bucket: "PublicNews-ro-RO", category: .local, severity: .medium, postType: .caseConfirmed, daysAgo: 21),
        SignalSeed(iso: "TR", country: "Türkiye", title: "Media report ministry advice on rodent exposure during field work", summary: "Response-style media signal based on prevention advice.", bucket: "PublicNews-tr-TR", category: .response, severity: .low, postType: .officialResponse, daysAgo: 22),
        SignalSeed(iso: "RU", country: "Russia", title: "Regional reports describe haemorrhagic fever case monitoring", summary: "Public report is mapped as suspected until an official source is linked.", bucket: "PublicNews-ru-RU", category: .media, severity: .medium, postType: .caseSuspected, daysAgo: 23),
        SignalSeed(iso: "CN", country: "China", title: "Province-level news reports confirmed haemorrhagic fever cases", summary: "Confirmed-case signal from public coverage; country detail should expose source bucket and date.", bucket: "PublicNews-zh-CN", category: .local, severity: .high, postType: .caseConfirmed, daysAgo: 24),
        SignalSeed(iso: "KR", country: "South Korea", title: "Routine surveillance article notes no unusual hantavirus increase", summary: "Structured surveillance update is low severity and should not alarm users.", bucket: "PublicNews-ko-KR", category: .local, severity: .low, postType: .caseConfirmed, daysAgo: 25),
        SignalSeed(iso: "JP", country: "Japan", title: "Travel medicine outlet mentions imported hantavirus exposure follow-up", summary: "Imported travel-linked signal.", bucket: "PublicNews-ja-JP", category: .imported, severity: .medium, postType: .caseImported, daysAgo: 26),
        SignalSeed(iso: "IN", country: "India", title: "Researchers discuss diagnostic awareness after suspected infections", summary: "Expert voice signal, not official surveillance.", bucket: "PublicNews-en-IN", category: .media, severity: .low, postType: .expertVoice, daysAgo: 27),
        SignalSeed(iso: "TH", country: "Thailand", title: "News explainer covers rodent-borne disease monitoring", summary: "General public discourse signal without confirmed case claim.", bucket: "PublicNews-th-TH", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 28),
        SignalSeed(iso: "VN", country: "Vietnam", title: "Local report mentions suspected hantavirus testing after exposure", summary: "Suspected case signal awaiting official confirmation.", bucket: "PublicNews-vi-VN", category: .media, severity: .medium, postType: .caseSuspected, daysAgo: 29),
        SignalSeed(iso: "ID", country: "Indonesia", title: "Public report discusses prevention after rodent exposure concern", summary: "Displayed as public discourse only.", bucket: "PublicNews-id-ID", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 30),
        SignalSeed(iso: "PH", country: "Philippines", title: "Health column explains when clinicians consider hantavirus testing", summary: "Expert/public discourse signal with no official case count.", bucket: "PublicNews-en-PH", category: .media, severity: .low, postType: .expertVoice, daysAgo: 31),
        SignalSeed(iso: "AU", country: "Australia", title: "Travel-linked imported case discussed in public-health news", summary: "Imported signal separated from local transmission.", bucket: "PublicNews-en-AU", category: .imported, severity: .medium, postType: .caseImported, daysAgo: 32),
        SignalSeed(iso: "NZ", country: "New Zealand", title: "Public-health explainer mentions hantavirus as a travel consideration", summary: "No local case claim; public discourse only.", bucket: "PublicNews-en-NZ", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 33),
        SignalSeed(iso: "ZA", country: "South Africa", title: "Port-health advisory coverage mentions imported febrile illness monitoring", summary: "Response signal; no local transmission is implied.", bucket: "PublicNews-en-ZA", category: .response, severity: .medium, postType: .officialResponse, daysAgo: 34),
        SignalSeed(iso: "KE", country: "Kenya", title: "Regional news discusses rodent-borne disease surveillance gaps", summary: "Public discourse signal useful for watchlist discovery.", bucket: "PublicNews-en-KE", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 35),
        SignalSeed(iso: "NG", country: "Nigeria", title: "Scientists call for wider rodent-borne disease monitoring", summary: "Expert voice signal; not a confirmed hantavirus event.", bucket: "PublicNews-en-NG", category: .media, severity: .low, postType: .expertVoice, daysAgo: 36)
    ]

    private static let ebolaSignalSeeds: [SignalSeed] = [
        SignalSeed(iso: "CD", country: "Democratic Republic of the Congo", title: "WHO notice tracks Ebola disease outbreak and affected health zones", summary: "Official source-backed signal. Counts can shift as suspected, probable, and confirmed cases are reclassified.", bucket: "WHO-DON", category: .local, severity: .high, postType: .caseConfirmed, daysAgo: 1),
        SignalSeed(iso: "UG", country: "Uganda", title: "Official cross-border monitoring update follows Ebola event", summary: "Displayed as an official response signal until a country-specific case table is published.", bucket: "WHO-DON", category: .response, severity: .high, postType: .officialResponse, daysAgo: 2),
        SignalSeed(iso: "CD", country: "Democratic Republic of the Congo", title: "Ministry response teams expand Ebola contact tracing", summary: "Response activity is shown separately from confirmed case counts.", bucket: "Ministry-CD", category: .response, severity: .medium, postType: .officialResponse, daysAgo: 4),
        SignalSeed(iso: "GN", country: "Guinea", title: "CDC historical Ebola outbreak record used for context", summary: "Historical context only; not a current local transmission claim.", bucket: "CDC-Ebola", category: .media, severity: .low, postType: .publicDiscourse, daysAgo: 8),
        SignalSeed(iso: "SL", country: "Sierra Leone", title: "Public-health reference explains Ebola case definitions", summary: "Explainer signal; no current official event is implied by this fixture.", bucket: "CDC-Ebola", category: .media, severity: .low, postType: .expertVoice, daysAgo: 12)
    ]

    static let signals: [Signal] = signalSeeds.enumerated().map { index, seed in
        Signal(
            id: "public-\(seed.iso.lowercased())-\(index + 1)",
            title: seed.title,
            summary: seed.summary,
            url: publicNewsURL(country: seed.country),
            sourceBucket: seed.bucket,
            publishedAt: Date(timeInterval: -Double(seed.daysAgo) * 86_400, since: checkedAt),
            countryISO: seed.iso,
            category: seed.category,
            severity: seed.severity,
            postType: seed.postType
        )
    }

    /// Representative public-domain source imagery (CDC PHIL via Wikimedia
    /// Commons) so the Ebola swipe deck shows the same image-card treatment as
    /// the media-enriched Hantavirus feed. The worker only ingests (and
    /// og:image-enriches) Hantavirus, so Ebola signals would otherwise carry no
    /// media. `Special:FilePath` is a stable redirect to the current file; if a
    /// link ever dies, `SignalMediaPreview` degrades to its designed fallback.
    private static let ebolaMediaURLs: [URL] = [
        URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Ebola_virus_virion.jpg")!,
        URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/CDC_worker_exposed_to_Ebola_virus.jpg")!,
        URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Biosafety_level_4_hazmat_suit.jpg")!
    ]

    static let ebolaSignals: [Signal] = ebolaSignalSeeds.enumerated().map { index, seed in
        let articleURL = publicNewsURL(country: seed.country, disease: "ebola")
        let mediaURL = ebolaMediaURLs[index % ebolaMediaURLs.count]
        let provider = seed.bucket.hasPrefix("WHO") ? "WHO"
            : (seed.bucket.hasPrefix("Ministry") ? "Ministry of Health" : "CDC")
        return Signal(
            id: "ebola-\(seed.iso.lowercased())-\(index + 1)",
            title: seed.title,
            summary: seed.summary,
            url: articleURL,
            sourceBucket: seed.bucket,
            publishedAt: Date(timeInterval: -Double(seed.daysAgo) * 86_400, since: checkedAt),
            countryISO: seed.iso,
            category: seed.category,
            severity: seed.severity,
            postType: seed.postType,
            primaryMedia: SignalMedia(
                type: .image,
                url: mediaURL,
                thumbnailUrl: mediaURL,
                provider: provider,
                sourceUrl: articleURL,
                width: nil,
                height: nil
            )
        )
    }

    static let signalAggregates: [CountrySignalAggregate] = {
        var scratch: [String: AggregateScratch] = [:]
        for signal in signals {
            guard let iso = signal.countryISO?.uppercased() else { continue }
            var item = scratch[iso] ?? AggregateScratch()
            item.allTimeCount += 1
            if isWithin(signal.publishedAt, days: 30) { item.last30dCount += 1 }
            if isWithin(signal.publishedAt, days: 183) { item.last6mCount += 1 }
            if isWithin(signal.publishedAt, days: 365) { item.last1yCount += 1 }
            item.activeLevel = strongestLevel(item.activeLevel, activeLevel(for: signal.mapPostType))
            if item.lastSignalAt.map({ signal.publishedAt > $0 }) ?? true {
                item.lastSignalAt = signal.publishedAt
            }
            scratch[iso] = item
        }

        return scratch.map { iso, item in
            CountrySignalAggregate(
                countryISO: iso,
                last30dCount: item.last30dCount,
                last6mCount: item.last6mCount,
                last1yCount: item.last1yCount,
                allTimeCount: item.allTimeCount,
                activeLevel: item.activeLevel,
                lastSignalAt: item.lastSignalAt
            )
        }
        .sorted { ($0.lastSignalAt ?? .distantPast) > ($1.lastSignalAt ?? .distantPast) }
    }()

    static let stats: AppStats = {
        let counts = Dictionary(grouping: signals, by: \.sourceBucket)
            .map { AppStats.TopSource(bucket: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(6)
        return AppStats(
            updatedAt: checkedAt,
            signalsTotal: signals.count,
            signalsLast30d: signals.filter { isWithin($0.publishedAt, days: 30) }.count,
            countriesActive: Set(signals.compactMap { $0.countryISO?.uppercased() }).count,
            topSources: Array(counts)
        )
    }()

    static let ebolaSignalAggregates: [CountrySignalAggregate] = aggregates(from: ebolaSignals)

    static let ebolaStats: AppStats = stats(from: ebolaSignals)

    static func summary(for mode: DiseaseMode) -> AppSummary {
        switch mode {
        case .hantavirus:
            return summary
        case .ebola:
            return ebolaSummary
        case .both:
            return AppSummary(
                checkedAt: max(summary.checkedAt, ebolaSummary.checkedAt),
                countryCount: uniqueCountryCount(countries + ebolaCountries),
                officialAlertCount: alerts.count + ebolaAlerts.count,
                savedCount: summary.savedCount + ebolaSummary.savedCount
            )
        }
    }

    static func countries(for mode: DiseaseMode) -> [CountrySnapshot] {
        switch mode {
        case .hantavirus:
            return countries
        case .ebola:
            return ebolaCountries
        case .both:
            return mergeCountries(countries + ebolaCountries)
        }
    }

    static func alerts(for mode: DiseaseMode) -> [OfficialAlert] {
        switch mode {
        case .hantavirus:
            return alerts
        case .ebola:
            return ebolaAlerts
        case .both:
            return (alerts + ebolaAlerts).sorted { $0.publishedAt > $1.publishedAt }
        }
    }

    static func guideArticles(for mode: DiseaseMode) -> [GuideArticle] {
        switch mode {
        case .hantavirus:
            return guideArticles
        case .ebola:
            return ebolaGuideArticles
        case .both:
            return guideArticles + ebolaGuideArticles
        }
    }

    static func mapCountries(for mode: DiseaseMode) -> [MapCountry] {
        switch mode {
        case .hantavirus:
            return mapCountries
        case .ebola:
            return ebolaMapCountries
        case .both:
            return mergeMapCountries(mapCountries + ebolaMapCountries)
        }
    }

    static func signals(for mode: DiseaseMode) -> [Signal] {
        switch mode {
        case .hantavirus:
            return signals
        case .ebola:
            return ebolaSignals
        case .both:
            return (signals + ebolaSignals).sorted { $0.publishedAt > $1.publishedAt }
        }
    }

    static func signalAggregates(for mode: DiseaseMode) -> [CountrySignalAggregate] {
        switch mode {
        case .hantavirus:
            return signalAggregates
        case .ebola:
            return ebolaSignalAggregates
        case .both:
            return mergeAggregates(signalAggregates + ebolaSignalAggregates)
        }
    }

    static func stats(for mode: DiseaseMode) -> AppStats {
        switch mode {
        case .hantavirus:
            return stats
        case .ebola:
            return ebolaStats
        case .both:
            return stats(from: signals(for: .both))
        }
    }

    private static func uniqueCountryCount(_ sourceCountries: [CountrySnapshot]) -> Int {
        Set(sourceCountries.map { $0.isoCode.uppercased() }).count
    }

    private static func mergeCountries(_ sourceCountries: [CountrySnapshot]) -> [CountrySnapshot] {
        var byISO: [String: CountrySnapshot] = [:]
        for country in sourceCountries {
            let iso = country.isoCode.uppercased()
            if let existing = byISO[iso] {
                let existingDate = existing.publishedAt ?? existing.reportedAt ?? .distantPast
                let nextDate = country.publishedAt ?? country.reportedAt ?? .distantPast
                if nextDate >= existingDate {
                    byISO[iso] = country
                }
            } else {
                byISO[iso] = country
            }
        }
        return byISO.values.sorted { $0.countryName < $1.countryName }
    }

    private static func mergeMapCountries(_ sourceCountries: [MapCountry]) -> [MapCountry] {
        var byISO: [String: MapCountry] = [:]
        for country in sourceCountries {
            let iso = country.isoCode.uppercased()
            guard let existing = byISO[iso] else {
                byISO[iso] = country
                continue
            }
            byISO[iso] = MapCountry(
                id: iso,
                isoCode: iso,
                name: country.name,
                confidenceLevel: strongestConfidence(existing.confidenceLevel, country.confidenceLevel),
                cases: addOptional(existing.cases, country.cases),
                alerts: existing.alerts + country.alerts,
                polygons: existing.polygons + country.polygons
            )
        }
        return byISO.values.sorted { $0.name < $1.name }
    }

    private static func mergeAggregates(_ sourceAggregates: [CountrySignalAggregate]) -> [CountrySignalAggregate] {
        var byISO: [String: CountrySignalAggregate] = [:]
        for aggregate in sourceAggregates {
            let iso = aggregate.countryISO.uppercased()
            guard let existing = byISO[iso] else {
                byISO[iso] = aggregate
                continue
            }
            byISO[iso] = CountrySignalAggregate(
                countryISO: iso,
                last30dCount: existing.last30dCount + aggregate.last30dCount,
                last6mCount: existing.last6mCount + aggregate.last6mCount,
                last1yCount: existing.last1yCount + aggregate.last1yCount,
                allTimeCount: existing.allTimeCount + aggregate.allTimeCount,
                activeLevel: strongestLevel(existing.activeLevel, aggregate.activeLevel),
                lastSignalAt: [existing.lastSignalAt, aggregate.lastSignalAt].compactMap { $0 }.max()
            )
        }
        return byISO.values.sorted { ($0.lastSignalAt ?? .distantPast) > ($1.lastSignalAt ?? .distantPast) }
    }

    private static func addOptional(_ lhs: Int?, _ rhs: Int?) -> Int? {
        switch (lhs, rhs) {
        case let (l?, r?): l + r
        case let (l?, nil): l
        case let (nil, r?): r
        case (nil, nil): nil
        }
    }

    private static func strongestConfidence(_ lhs: ConfidenceLevel, _ rhs: ConfidenceLevel) -> ConfidenceLevel {
        confidenceRank(rhs) > confidenceRank(lhs) ? rhs : lhs
    }

    private static func confidenceRank(_ level: ConfidenceLevel) -> Int {
        switch level {
        case .noRecentPublicData: return 0
        case .mediaSignal: return 1
        case .officialStructuredData: return 2
        case .officialAlert: return 3
        }
    }

    private static func publicNewsURL(country: String, disease: String = "hantavirus") -> URL {
        let encoded = "\(disease) \(country)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? disease
        return URL(string: "https://news.google.com/search?q=\(encoded)")!
    }

    private static func aggregates(from sourceSignals: [Signal]) -> [CountrySignalAggregate] {
        var scratch: [String: AggregateScratch] = [:]
        for signal in sourceSignals {
            guard let iso = signal.countryISO?.uppercased() else { continue }
            var item = scratch[iso] ?? AggregateScratch()
            item.allTimeCount += 1
            if isWithin(signal.publishedAt, days: 30) { item.last30dCount += 1 }
            if isWithin(signal.publishedAt, days: 183) { item.last6mCount += 1 }
            if isWithin(signal.publishedAt, days: 365) { item.last1yCount += 1 }
            item.activeLevel = strongestLevel(item.activeLevel, activeLevel(for: signal.mapPostType))
            if item.lastSignalAt.map({ signal.publishedAt > $0 }) ?? true {
                item.lastSignalAt = signal.publishedAt
            }
            scratch[iso] = item
        }

        return scratch.map { iso, item in
            CountrySignalAggregate(
                countryISO: iso,
                last30dCount: item.last30dCount,
                last6mCount: item.last6mCount,
                last1yCount: item.last1yCount,
                allTimeCount: item.allTimeCount,
                activeLevel: item.activeLevel,
                lastSignalAt: item.lastSignalAt
            )
        }
        .sorted { ($0.lastSignalAt ?? .distantPast) > ($1.lastSignalAt ?? .distantPast) }
    }

    private static func stats(from sourceSignals: [Signal]) -> AppStats {
        let counts = Dictionary(grouping: sourceSignals, by: \.sourceBucket)
            .map { AppStats.TopSource(bucket: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(6)
        return AppStats(
            updatedAt: checkedAt,
            signalsTotal: sourceSignals.count,
            signalsLast30d: sourceSignals.filter { isWithin($0.publishedAt, days: 30) }.count,
            countriesActive: Set(sourceSignals.compactMap { $0.countryISO?.uppercased() }).count,
            topSources: Array(counts)
        )
    }

    private static func isWithin(_ date: Date, days: Int) -> Bool {
        date >= Date(timeInterval: -Double(days) * 86_400, since: checkedAt)
    }

    private static func activeLevel(for postType: MapPostType) -> CountryActiveLevel {
        switch postType {
        case .death, .caseConfirmed, .caseSuspected:
            return .active
        case .caseImported:
            return .imported
        case .officialResponse, .expertVoice, .publicDiscourse:
            return .response
        }
    }

    private static func strongestLevel(_ lhs: CountryActiveLevel, _ rhs: CountryActiveLevel) -> CountryActiveLevel {
        activeLevelRank(rhs) > activeLevelRank(lhs) ? rhs : lhs
    }

    private static func activeLevelRank(_ level: CountryActiveLevel) -> Int {
        switch level {
        case .none: return 0
        case .response: return 1
        case .imported, .endemic: return 2
        case .active: return 3
        }
    }
}
