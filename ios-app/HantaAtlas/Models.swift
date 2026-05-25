import Foundation
import Observation
import SwiftUI

enum DiseaseMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case both
    case hantavirus
    case ebola

    var id: String { rawValue }

    var title: String {
        switch self {
        case .both: "Both"
        case .hantavirus: "Hantavirus"
        case .ebola: "Ebola"
        }
    }

    var shortTitle: String {
        switch self {
        case .both: "Both"
        case .hantavirus: "Hanta"
        case .ebola: "Ebola"
        }
    }

    var feedLabel: String {
        switch self {
        case .both: "outbreak watch"
        case .hantavirus: "hanta news"
        case .ebola: "ebola updates"
        }
    }

    var sourceFocus: String {
        switch self {
        case .both: "combined official-source watch"
        case .hantavirus: "rodent-borne surveillance"
        case .ebola: "official outbreak notices"
        }
    }

    var pathogenLabel: String {
        switch self {
        case .both: "Tracked diseases"
        case .hantavirus: "Virus type"
        case .ebola: "Pathogen/species"
        }
    }

    var accentSymbol: String {
        switch self {
        case .both: "square.grid.2x2.fill"
        case .hantavirus: "globe.europe.africa.fill"
        case .ebola: "waveform.path.ecg.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .both: Theme.amber
        case .hantavirus: Theme.moss
        case .ebola: Theme.terracotta
        }
    }
}

enum ConfidenceLevel: String, Codable, CaseIterable, Identifiable {
    case officialStructuredData = "OFFICIAL_STRUCTURED_DATA"
    case officialAlert = "OFFICIAL_ALERT"
    case mediaSignal = "MEDIA_SIGNAL"
    case noRecentPublicData = "NO_RECENT_PUBLIC_DATA"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .officialStructuredData: "Official structured data"
        case .officialAlert: "Official alert"
        case .mediaSignal: "Media signal"
        case .noRecentPublicData: "No recent public data"
        }
    }

    var shortTitle: String {
        switch self {
        case .officialStructuredData: "Structured"
        case .officialAlert: "Alert"
        case .mediaSignal: "Media"
        case .noRecentPublicData: "No recent data"
        }
    }

    var explanation: String {
        switch self {
        case .officialStructuredData:
            "Regular public-health surveillance with comparable country-level data."
        case .officialAlert:
            "An official alert or bulletin without a complete comparable table."
        case .mediaSignal:
            "Media-reported signal awaiting confirmation from an official source."
        case .noRecentPublicData:
            "No recent public country-level source was found in monitored official channels."
        }
    }
}

enum AlertSeverity: String, Codable, CaseIterable, Identifiable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MapMetric: String, Codable, CaseIterable, Identifiable {
    case cases
    case alerts
    case confidence

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Source: Identifiable, Codable, Hashable {
    let id: String
    let organisation: String
    let url: URL
}

struct CountrySnapshot: Identifiable, Codable, Hashable {
    let id: String
    let isoCode: String
    let countryName: String
    let regionName: String
    let cases: Int?
    let deaths: Int?
    let reportingPeriodLabel: String
    let reportedAt: Date?
    let publishedAt: Date?
    let lastCheckedAt: Date
    let source: Source
    let sourceUrl: URL
    let summary: String
    let virusType: String
    let limitations: String
    let confidenceLevel: ConfidenceLevel
    let trend: [TrendPoint]

    var casesLabel: String { cases.map(String.init) ?? "Not published" }
    var deathsLabel: String { deaths.map(String.init) ?? "Not published" }
}

struct TrendPoint: Identifiable, Codable, Hashable {
    let id: UUID
    let label: String
    let cases: Int

    init(label: String, cases: Int) {
        self.id = UUID()
        self.label = label
        self.cases = cases
    }
}

struct OfficialAlert: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let countryName: String
    let regionName: String
    let source: Source
    let severity: AlertSeverity
    let confidenceLevel: ConfidenceLevel
    let reportedAt: Date
    let publishedAt: Date
    let summary: String
}

struct GuideArticle: Identifiable, Codable, Hashable {
    let id: String
    let section: GuideSection
    let title: String
    let body: String
    let symbolName: String
}

enum GuideSection: String, Codable, CaseIterable, Identifiable {
    case prevention
    case symptoms
    case urgentCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prevention: "Prevention"
        case .symptoms: "Symptoms"
        case .urgentCare: "Urgent care"
        }
    }
}

struct MapCountry: Identifiable, Codable, Hashable {
    let id: String
    let isoCode: String
    let name: String
    let confidenceLevel: ConfidenceLevel
    let cases: Int?
    let alerts: Int
    let polygons: [[MapPoint]]
}

struct MapPoint: Codable, Hashable {
    let x: Double
    let y: Double
}

struct AppSummary: Codable, Hashable {
    let checkedAt: Date
    let countryCount: Int
    let officialAlertCount: Int
    let savedCount: Int
}

@MainActor
@Observable
final class LocalPreferences {
    /// Shared instance so the whole UI and the profile-sync engine
    /// (`PreferencesSync`) mutate one source of truth. Saved countries and
    /// settings persist on-device via UserDefaults and, while signed in, sync
    /// to the user's backend profile.
    static let shared = LocalPreferences()

    /// True while `applyRemote(_:)` is writing server values into local state.
    /// Suppresses the change-observation push so a pull doesn't immediately
    /// echo back as a PUT. Not observed — it's sync plumbing, not view state.
    @ObservationIgnored var isApplyingRemote = false

    var selectedDiseaseMode: DiseaseMode {
        didSet { UserDefaults.standard.set(selectedDiseaseMode.rawValue, forKey: Keys.selectedDiseaseMode) }
    }
    var savedCountryCodes: Set<String> {
        didSet { saveStringArray(Array(savedCountryCodes), key: Keys.savedCountries) }
    }
    var trackAllCountries: Bool {
        didSet { UserDefaults.standard.set(trackAllCountries, forKey: Keys.trackAllCountries) }
    }
    var lastSelectedMetric: MapMetric {
        didSet { UserDefaults.standard.set(lastSelectedMetric.rawValue, forKey: Keys.metric) }
    }
    var officialNoticeAlerts: Bool {
        didSet { UserDefaults.standard.set(officialNoticeAlerts, forKey: Keys.officialNoticeAlerts) }
    }
    var itineraryAlerts: Bool {
        didSet { UserDefaults.standard.set(itineraryAlerts, forKey: Keys.itineraryAlerts) }
    }
    var trackedCountryCaseAlerts: Bool {
        didSet { UserDefaults.standard.set(trackedCountryCaseAlerts, forKey: Keys.trackedCountryCaseAlerts) }
    }
    var trackedCountryNewsBurstAlerts: Bool {
        didSet { UserDefaults.standard.set(trackedCountryNewsBurstAlerts, forKey: Keys.trackedCountryNewsBurstAlerts) }
    }

    // MARK: - Alert preferences (Alerts tab)

    /// How often to notify on classification changes for tracked countries.
    /// Default = real-time on tracked-country escalation only. Per Apple
    /// 4.5.4 / 5.1.2: opt-in, never gates feature, can be turned off here.
    var alertFrequency: AlertFrequency {
        didSet { UserDefaults.standard.set(alertFrequency.rawValue, forKey: Keys.alertFrequency) }
    }
    /// Minimum classification level that triggers a notification — the user
    /// chooses how loud the alerts are.
    var minAlertLevel: EmergencyClassification {
        didSet { UserDefaults.standard.set(minAlertLevel.rawValue, forKey: Keys.minAlertLevel) }
    }
    var quietHoursEnabled: Bool {
        didSet { UserDefaults.standard.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled) }
    }
    var quietHoursStart: Int {  // 0..23
        didSet { UserDefaults.standard.set(quietHoursStart, forKey: Keys.quietHoursStart) }
    }
    var quietHoursEnd: Int {
        didSet { UserDefaults.standard.set(quietHoursEnd, forKey: Keys.quietHoursEnd) }
    }

    init() {
        // Empty by default — users explicitly opt in to saved countries via
        // the Saved tab's inline add affordance. (Was previously seeded with
        // ["US", "AR", "DE"], which is wrong product-wise.)
        //
        // Normalise to uppercase on load. ISO 3166-1 alpha-2 codes are
        // canonically uppercase, but earlier app versions persisted whatever
        // casing was passed to `toggleSaved`. Without normalisation a user
        // who saved "us" would never match a signal whose `countryISO` is
        // "US" — silent failure of the entire follow-feature. This guard
        // also forward-fixes any prior install that has mixed-case codes
        // sitting in UserDefaults.
        self.selectedDiseaseMode = DiseaseMode(rawValue: UserDefaults.standard.string(forKey: Keys.selectedDiseaseMode) ?? "") ?? .both
        let storedCountries = UserDefaults.standard.stringArray(forKey: Keys.savedCountries) ?? []
        self.savedCountryCodes = Set(storedCountries.map { $0.uppercased() })
        self.trackAllCountries = UserDefaults.standard.object(forKey: Keys.trackAllCountries) as? Bool ?? false
        self.lastSelectedMetric = MapMetric(rawValue: UserDefaults.standard.string(forKey: Keys.metric) ?? "") ?? .confidence
        self.officialNoticeAlerts = UserDefaults.standard.object(forKey: Keys.officialNoticeAlerts) as? Bool ?? true
        self.itineraryAlerts = UserDefaults.standard.object(forKey: Keys.itineraryAlerts) as? Bool ?? true
        self.trackedCountryCaseAlerts = UserDefaults.standard.object(forKey: Keys.trackedCountryCaseAlerts) as? Bool ?? true
        self.trackedCountryNewsBurstAlerts = UserDefaults.standard.object(forKey: Keys.trackedCountryNewsBurstAlerts) as? Bool ?? true
        self.alertFrequency = AlertFrequency(rawValue: UserDefaults.standard.string(forKey: Keys.alertFrequency) ?? "") ?? .realtime
        self.minAlertLevel = EmergencyClassification(rawValue: UserDefaults.standard.string(forKey: Keys.minAlertLevel) ?? "") ?? .advisory
        self.quietHoursEnabled = UserDefaults.standard.object(forKey: Keys.quietHoursEnabled) as? Bool ?? false
        self.quietHoursStart = UserDefaults.standard.object(forKey: Keys.quietHoursStart) as? Int ?? 22
        self.quietHoursEnd = UserDefaults.standard.object(forKey: Keys.quietHoursEnd) as? Int ?? 7
        self.seenSignalIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.seenSignalIDs) ?? [])
        let mutedRaw = UserDefaults.standard.dictionary(forKey: Keys.mutedCountries) as? [String: Double] ?? [:]
        self.mutedCountriesUntil = mutedRaw.mapValues { Date(timeIntervalSince1970: $0) }
        self.swipeScopeFollowingOnly = UserDefaults.standard.object(forKey: Keys.swipeScopeFollowing) as? Bool ?? true
        self.swipeMinSeverity = AlertSeverity(rawValue: UserDefaults.standard.string(forKey: Keys.swipeMinSeverity) ?? "") ?? .low
        self.swipeHorizonDays = UserDefaults.standard.object(forKey: Keys.swipeHorizonDays) as? Int ?? 7
    }

    func toggleSaved(_ isoCode: String) {
        // Canonical store is uppercase. See `init()` for the rationale —
        // every consumer (Today, Feed scope, Catch-up filter, Alerts widgets,
        // notifications) treats `savedCountryCodes` as case-sensitive Set
        // membership, so we have to keep one consistent casing.
        let normalized = isoCode.uppercased()
        if savedCountryCodes.contains(normalized) {
            savedCountryCodes.remove(normalized)
        } else {
            savedCountryCodes.insert(normalized)
        }
    }

    func setTrackAllCountries(_ enabled: Bool) {
        trackAllCountries = enabled
    }

    /// Case-insensitive, nil-safe "is this country in the user's saved set?"
    /// helper. Replaces direct `savedCountryCodes.contains(iso)` calls — those
    /// failed silently whenever `iso` arrived in a different casing than the
    /// saved value. All comparison call sites should funnel through this.
    func isFollowing(_ isoCode: String?) -> Bool {
        guard let iso = isoCode?.uppercased(), !iso.isEmpty else { return false }
        return trackAllCountries || savedCountryCodes.contains(iso)
    }

    /// Map/feed scoping helper. Empty selected list means global exploration;
    /// once the user explicitly picks countries, surfaces narrow to those
    /// countries unless "track all" is enabled.
    func shouldShowCountry(_ isoCode: String?, includeAllWhenEmpty: Bool = true) -> Bool {
        guard let iso = isoCode?.uppercased(), !iso.isEmpty else { return includeAllWhenEmpty }
        if trackAllCountries { return true }
        if savedCountryCodes.isEmpty { return includeAllWhenEmpty }
        return savedCountryCodes.contains(iso)
    }

    func trackedCountryCount(totalAvailable: Int) -> Int {
        trackAllCountries ? totalAvailable : savedCountryCodes.count
    }

    private func saveStringArray(_ value: [String], key: String) {
        UserDefaults.standard.set(value.sorted(), forKey: key)
    }

    // MARK: - Swipe deck state (Catch-up feature)

    /// Set of signal IDs the user has already reviewed in the swipe deck.
    /// Persisted on-device only — no backend sync. Cleared from the deck
    /// settings if the user wants to reset.
    var seenSignalIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(seenSignalIDs), forKey: Keys.seenSignalIDs) }
    }
    /// Country ISO codes the user has muted from the swipe deck (24h TTL
    /// is enforced at read time using the matching `mutedAt` map).
    var mutedCountriesUntil: [String: Date] {
        didSet {
            // Convert to a [String: Double] (timestamp) for UserDefaults.
            let dict = mutedCountriesUntil.mapValues { $0.timeIntervalSince1970 }
            UserDefaults.standard.set(dict, forKey: Keys.mutedCountries)
        }
    }
    /// Persisted swipe-deck filter preferences.
    var swipeScopeFollowingOnly: Bool {
        didSet { UserDefaults.standard.set(swipeScopeFollowingOnly, forKey: Keys.swipeScopeFollowing) }
    }
    var swipeMinSeverity: AlertSeverity {
        didSet { UserDefaults.standard.set(swipeMinSeverity.rawValue, forKey: Keys.swipeMinSeverity) }
    }
    var swipeHorizonDays: Int {
        didSet { UserDefaults.standard.set(swipeHorizonDays, forKey: Keys.swipeHorizonDays) }
    }

    func markSeen(_ signalID: String) {
        seenSignalIDs.insert(signalID)
    }
    func resetSeenQueue() {
        seenSignalIDs = []
    }
    func muteCountry(_ iso: String, hours: Int = 24) {
        guard let until = Calendar.current.date(byAdding: .hour, value: hours, to: Date()) else { return }
        mutedCountriesUntil[iso.uppercased()] = until
    }
    /// Removes expired mutes lazily before returning the active set.
    func currentlyMutedCountries() -> Set<String> {
        let now = Date()
        let active = mutedCountriesUntil.filter { $0.value > now }
        if active.count != mutedCountriesUntil.count {
            // Cleanup expired entries
            mutedCountriesUntil = active
        }
        return Set(active.keys)
    }

    // MARK: - Profile sync (PreferencesSync)

    /// The synced subset of preferences, in the exact wire shape the backend
    /// `/v1/me/preferences` endpoint expects. On-device-only state (seen
    /// signals, muted countries, swipe filters) is intentionally excluded.
    var syncSnapshot: PreferencesPayload {
        PreferencesPayload(
            // Sorted for stable equality (the Set's iteration order is not
            // deterministic) so the sync engine can diff snapshots reliably.
            savedCountries: savedCountryCodes.sorted(),
            trackAllCountries: trackAllCountries,
            selectedDiseaseMode: selectedDiseaseMode.rawValue,
            lastSelectedMetric: lastSelectedMetric.rawValue,
            officialNoticeAlerts: officialNoticeAlerts,
            itineraryAlerts: itineraryAlerts,
            trackedCountryCaseAlerts: trackedCountryCaseAlerts,
            trackedCountryNewsBurstAlerts: trackedCountryNewsBurstAlerts,
            alertFrequency: alertFrequency.rawValue,
            minAlertLevel: minAlertLevel.rawValue,
            quietHoursEnabled: quietHoursEnabled,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd
        )
    }

    /// Overwrite local state with the server's profile. Wrapped in
    /// `isApplyingRemote` so the observation-driven push doesn't fire. Unknown
    /// enum strings fall back to the current value rather than crashing.
    func applyRemote(_ p: PreferencesPayload) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        savedCountryCodes = Set(p.savedCountries.map { $0.uppercased() })
        trackAllCountries = p.trackAllCountries
        selectedDiseaseMode = DiseaseMode(rawValue: p.selectedDiseaseMode) ?? selectedDiseaseMode
        lastSelectedMetric = MapMetric(rawValue: p.lastSelectedMetric) ?? lastSelectedMetric
        officialNoticeAlerts = p.officialNoticeAlerts
        itineraryAlerts = p.itineraryAlerts
        trackedCountryCaseAlerts = p.trackedCountryCaseAlerts
        trackedCountryNewsBurstAlerts = p.trackedCountryNewsBurstAlerts
        alertFrequency = AlertFrequency(rawValue: p.alertFrequency) ?? alertFrequency
        minAlertLevel = EmergencyClassification(rawValue: p.minAlertLevel) ?? minAlertLevel
        quietHoursEnabled = p.quietHoursEnabled
        quietHoursStart = p.quietHoursStart
        quietHoursEnd = p.quietHoursEnd
    }

    private enum Keys {
        static let selectedDiseaseMode = "hantaatlas.selectedDiseaseMode"
        static let savedCountries = "savedCountries"
        static let trackAllCountries = "trackAllCountries"
        static let metric = "lastSelectedMetric"
        static let officialNoticeAlerts = "officialNoticeAlerts"
        static let itineraryAlerts = "itineraryAlerts"
        static let trackedCountryCaseAlerts = "trackedCountryCaseAlerts"
        static let trackedCountryNewsBurstAlerts = "trackedCountryNewsBurstAlerts"
        static let alertFrequency = "alertFrequency"
        static let minAlertLevel = "minAlertLevel"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let quietHoursStart = "quietHoursStart"
        static let quietHoursEnd = "quietHoursEnd"
        static let seenSignalIDs = "swipe.seenSignalIDs"
        static let mutedCountries = "swipe.mutedCountries"
        static let swipeScopeFollowing = "swipe.scopeFollowing"
        static let swipeMinSeverity = "swipe.minSeverity"
        static let swipeHorizonDays = "swipe.horizonDays"
    }
}

/// Wire shape for `GET`/`PUT /v1/me/preferences`. Field names + enum raw
/// strings match the backend `UserPreferences` model and zod schema exactly.
struct PreferencesPayload: Codable, Equatable, Sendable {
    var savedCountries: [String]
    var trackAllCountries: Bool
    var selectedDiseaseMode: String
    var lastSelectedMetric: String
    var officialNoticeAlerts: Bool
    var itineraryAlerts: Bool
    var trackedCountryCaseAlerts: Bool
    var trackedCountryNewsBurstAlerts: Bool
    var alertFrequency: String
    var minAlertLevel: String
    var quietHoursEnabled: Bool
    var quietHoursStart: Int
    var quietHoursEnd: Int
}

// ── Signal models (live data from /v1/signals + /v1/map-aggregates + /v1/stats) ──

enum SignalCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case local    = "LOCAL"
    case imported = "IMPORTED"
    case response = "RESPONSE"
    case media    = "MEDIA"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .local:    "Local"
        case .imported: "Imported"
        case .response: "Response"
        case .media:    "Media"
        }
    }
}

enum CountryActiveLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case endemic  = "ENDEMIC"
    case active   = "ACTIVE"
    case imported = "IMPORTED"
    case response = "RESPONSE"
    case none     = "NONE"

    var id: String { rawValue }
}

enum SignalTimeRange: String, Codable, CaseIterable, Identifiable, Hashable {
    case d30 = "30d"
    case m6  = "6m"
    case y1  = "1y"
    case all = "all"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .d30: "30d"
        case .m6:  "6m"
        case .y1:  "1y"
        case .all: "All"
        }
    }
}

enum SignalMediaType: String, Codable, Hashable {
    case image = "IMAGE"
    case video = "VIDEO"
    case embed = "EMBED"
}

struct SignalMedia: Codable, Hashable {
    let type: SignalMediaType
    let url: URL
    let thumbnailUrl: URL?
    let provider: String?
    let sourceUrl: URL?
    let width: Int?
    let height: Int?
}

struct Signal: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String?
    let url: URL
    let sourceBucket: String
    let publishedAt: Date
    let countryISO: String?
    let category: SignalCategory
    let severity: AlertSeverity

    /// Backend-classified post type (nullable for legacy rows during the
    /// rollout window). When null, the client derives via `mapPostType`.
    let postType: MapPostType?
    let primaryMedia: SignalMedia?

    /// Explicit member-wise init so call sites (fixtures, mappers, tests) can
    /// keep working when `postType` is omitted.
    init(
        id: String,
        title: String,
        summary: String? = nil,
        url: URL,
        sourceBucket: String,
        publishedAt: Date,
        countryISO: String? = nil,
        category: SignalCategory,
        severity: AlertSeverity,
        postType: MapPostType? = nil,
        primaryMedia: SignalMedia? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.url = url
        self.sourceBucket = sourceBucket
        self.publishedAt = publishedAt
        self.countryISO = countryISO
        self.category = category
        self.severity = severity
        self.postType = postType
        self.primaryMedia = primaryMedia
    }
}

extension Signal {
    /// Whether the signal came from an official public-health authority — WHO
    /// (incl. regional offices), ECDC, PAHO, CDC, Africa CDC, a national
    /// Ministry of Health, or a MEDISYS alert edition — as opposed to media /
    /// aggregator feeds (Google News, HealthMap, ProMED, ReliefWeb). Mirrors
    /// the worker's official-vs-media source split and drives the "official"
    /// framing of the Today dashboard's latest-alert card.
    var isOfficialSource: Bool {
        let bucket = sourceBucket.uppercased()
        if bucket.hasPrefix("WHO") || bucket.hasPrefix("MOH-") { return true }
        return ["ECDC-CDT", "PAHO", "CDC-HAN", "AFRICA-CDC", "MEDISYS"].contains(bucket)
    }
}

/// Map-facing post taxonomy — 7 buckets, two groups.
///
/// **Ground truth** (something happened):
///   - DEATH           — fatality reported (terracotta + white inner ring)
///   - CASE_CONFIRMED  — verified live infection / outbreak (amber)
///   - CASE_SUSPECTED  — under investigation, not yet confirmed (pale yellow-amber)
///   - CASE_IMPORTED   — case in a returnee / repatriated traveller (olive)
///
/// **Discourse** (something is being said):
///   - OFFICIAL_RESPONSE — advisory / screening / quarantine / ban / guidance (moss)
///   - EXPERT_VOICE      — predictions, warnings, expert opinions (clay)
///   - PUBLIC_DISCOURSE  — media mention / op-ed / discussion / no specific claim (soft grey)
///
/// Precedence (most-severe-event wins): DEATH > CASE_CONFIRMED > CASE_IMPORTED >
/// CASE_SUSPECTED > OFFICIAL_RESPONSE > EXPERT_VOICE > PUBLIC_DISCOURSE.
/// User-facing map display modes — the answer to "what am I looking at?"
///
/// Earlier the map exposed two parallel controls: a per-post-type visibility
/// sheet (LayersSheet) and a `MapMetric` enum that wasn't wired to UI. Users
/// reported the result as confusing — there was no single switch for
/// "show me deaths" or "show me active confirmed cases". This enum is the
/// single primary switch. Each mode resolves to a concrete set of
/// `MapPostType`s; the LayersSheet remains available for fine-tuning within
/// the chosen mode.
///
/// The mode never touches camera state — switching mode is a pure
/// data-layer filter. Camera state is owned by `MKMapHostView` /
/// `SharedMKMapStore` and persisted via `PersistedCamera`.
enum MapDisplayMode: String, CaseIterable, Identifiable, Codable {
    /// Everything we have — case posts, deaths, alerts, expert voices,
    /// public discourse. The legacy default; busy but complete.
    case allSignals       = "ALL_SIGNALS"

    /// Active outbreak surveillance — confirmed, suspected, imported cases
    /// plus deaths. This is the canonical "what's happening" view that
    /// matches how public-health agencies (WHO DON, ECDC) report.
    case activeConfirmed  = "ACTIVE_CONFIRMED"

    /// Deaths only. The most severe ground-truth signal — used when the
    /// user wants to focus on fatality clusters.
    case deaths           = "DEATHS"

    /// Official alerts (WHO DON, CDC HAN, ECDC, PAHO advisories). Filters
    /// out media-derived signals so only government / WHO action posts
    /// remain. The "high-confidence" view.
    case alerts           = "ALERTS"

    /// Confidence overlay — every signal type, but the visual emphasis is
    /// the per-country choropleth showing data quality
    /// (OFFICIAL_STRUCTURED_DATA → MEDIA_SIGNAL → NO_RECENT_PUBLIC_DATA).
    case confidence       = "CONFIDENCE"

    var id: String { rawValue }

    /// Short label for the segmented control. Keep ≤8 chars so the control
    /// fits five segments at iPhone-narrow widths without truncation.
    var shortTitle: String {
        switch self {
        case .allSignals:      "All"
        case .activeConfirmed: "Active"
        case .deaths:          "Deaths"
        case .alerts:          "Alerts"
        case .confidence:      "Confidence"
        }
    }

    /// Long description for accessibility labels and any "what does this
    /// mean?" hint surface.
    var accessibilityHint: String {
        switch self {
        case .allSignals:
            "Every signal type — cases, deaths, alerts, expert voices, public discourse."
        case .activeConfirmed:
            "Confirmed, suspected, and imported cases plus deaths."
        case .deaths:
            "Deaths only."
        case .alerts:
            "Official advisories from WHO, CDC, ECDC, PAHO."
        case .confidence:
            "Every signal, with countries shaded by data-quality confidence level."
        }
    }

    /// Post-type subset this mode renders. The LayersSheet may further
    /// narrow within this set, but cannot widen beyond it.
    var visiblePostTypes: Set<MapPostType> {
        switch self {
        case .allSignals:
            return Set(MapPostType.allCases)
        case .activeConfirmed:
            return [.death, .caseConfirmed, .caseSuspected, .caseImported]
        case .deaths:
            return [.death]
        case .alerts:
            return [.officialResponse]
        case .confidence:
            return Set(MapPostType.allCases)
        }
    }

    /// SF Symbol for the mode's pill / accessibility label.
    var symbolName: String {
        switch self {
        case .allSignals:      "circle.grid.2x2.fill"
        case .activeConfirmed: "exclamationmark.triangle.fill"
        case .deaths:          "heart.slash.fill"
        case .alerts:          "bell.badge.fill"
        case .confidence:      "checkmark.shield.fill"
        }
    }
}

enum MapPostType: String, CaseIterable, Identifiable, Codable {
    case death            = "DEATH"
    case caseConfirmed    = "CASE_CONFIRMED"
    case caseSuspected    = "CASE_SUSPECTED"
    case caseImported     = "CASE_IMPORTED"
    case officialResponse = "OFFICIAL_RESPONSE"
    case expertVoice      = "EXPERT_VOICE"
    case publicDiscourse  = "PUBLIC_DISCOURSE"

    var id: String { rawValue }

    /// Whether this bucket sits in the "ground truth" half (something happened)
    /// or the "discourse" half (something is being said). Used by the layers
    /// sheet to render two grouped sections.
    var group: Group {
        switch self {
        case .death, .caseConfirmed, .caseSuspected, .caseImported: return .groundTruth
        case .officialResponse, .expertVoice, .publicDiscourse:     return .discourse
        }
    }

    enum Group: String, CaseIterable, Identifiable {
        case groundTruth
        case discourse
        var id: String { rawValue }
        var title: String {
            switch self {
            case .groundTruth: "Ground truth"
            case .discourse:   "Discourse"
            }
        }
        var blurb: String {
            switch self {
            case .groundTruth: "Something happened"
            case .discourse:   "Something is being said"
            }
        }
    }

    var title: String {
        switch self {
        case .death:            "Death"
        case .caseConfirmed:    "Confirmed case"
        case .caseSuspected:    "Suspected case"
        case .caseImported:     "Imported"
        case .officialResponse: "Official response"
        case .expertVoice:      "Expert voice"
        case .publicDiscourse:  "Public discourse"
        }
    }

    var blurb: String {
        switch self {
        case .death:            "Fatality reported in this country"
        case .caseConfirmed:    "Confirmed live infection or outbreak"
        case .caseSuspected:    "Under investigation — not yet confirmed"
        case .caseImported:     "Case in a returnee or repatriated traveller"
        case .officialResponse: "Government / public health authority taking action — advisory, screening, quarantine, ban"
        case .expertVoice:      "Experts, scientists or officials speaking — predictions, warnings, projections"
        case .publicDiscourse:  "Media mention, op-ed, public reaction — no specific claim"
        }
    }
}

extension Signal {
    /// Authoritative post type for the map dot. Prefers the backend-classified
    /// `postType` field; falls back to the on-device derivation only when the
    /// backend hasn't classified yet (legacy row from before the worker
    /// rollout). Multilingual keyword sets cover EN + ES/PT/IT/DE/TR/FR.
    var mapPostType: MapPostType {
        if let backend = postType { return backend }
        let text = (title + " " + (summary ?? "")).lowercased()

        // 1. DEATH — strongest signal, takes precedence.
        if Self.deathKeywords.contains(where: { text.contains($0) }) {
            return .death
        }

        // 2. CASE_CONFIRMED — explicit confirmation language.
        if Self.confirmedKeywords.contains(where: { text.contains($0) }) {
            return .caseConfirmed
        }

        // 3. CASE_IMPORTED — returnee / traveller language (or upstream IMPORTED).
        if category == .imported || Self.importedKeywords.contains(where: { text.contains($0) }) {
            return .caseImported
        }

        // 4. CASE_SUSPECTED — under-investigation language.
        if Self.suspectedKeywords.contains(where: { text.contains($0) }) {
            return .caseSuspected
        }

        // 5. OFFICIAL_RESPONSE — measure / advisory language (or upstream RESPONSE).
        if category == .response || Self.officialResponseKeywords.contains(where: { text.contains($0) }) {
            return .officialResponse
        }

        // 6. EXPERT_VOICE — speculation / prediction / warning language.
        if Self.expertVoiceKeywords.contains(where: { text.contains($0) }) {
            return .expertVoice
        }

        // 7. Generic local case (raw "case" keyword) → CASE_CONFIRMED weakly.
        if category == .local || Self.genericCaseKeywords.contains(where: { text.contains($0) }) {
            return .caseConfirmed
        }

        // 8. Catch-all: PUBLIC_DISCOURSE.
        return .publicDiscourse
    }

    private static let deathKeywords: [String] = [
        "death", "deaths", "died", "fatal", "fatality", "fatalities",
        "deceased", "casualty", "casualties",
        "muerte", "muertos", "muerto",       // ES
        "morte", "mortes",                   // PT/IT
        "tod ", "todesfälle",                // DE
        "ölü", "ölüm",                       // TR
        "décès"                              // FR
    ]

    private static let confirmedKeywords: [String] = [
        "confirmed case", "lab-confirmed", "lab confirmed", "test positive",
        "tested positive", "diagnosed with", "outbreak declared",
        "caso confirmado", "casi confermati", "fall bestätigt", "doğrulandı"
    ]

    private static let importedKeywords: [String] = [
        "imported case", "imported", "returnee", "returning traveller",
        "returning traveler", "repatriation", "repatriated", "evacuated",
        "caso importado", "caso importato", "rückkehrer", "yurt dışından"
    ]

    private static let suspectedKeywords: [String] = [
        "suspected case", "suspected", "under investigation", "possible case",
        "monitoring", "awaiting test", "awaiting results", "preliminary",
        "caso sospechoso", "caso sospetto", "verdachtsfall", "şüpheli vaka"
    ]

    private static let officialResponseKeywords: [String] = [
        "advisory", "advise", "screening", "quarantine", "ban", "restriction",
        "border", "travel warning", "guidance issued", "alert issued", "protocol",
        "aviso", "advertencia", "cuarentena", "screening", "protocollo",
        "warnung", "tarama", "uyarı"
    ]

    private static let expertVoiceKeywords: [String] = [
        "predict", "predicts", "prediction", "project", "projects", "projection",
        "forecast", "warn", "warns", "warning", "fear", "fears", "concern",
        "concerns", "experts say", "expert says", "scientists believe", "scientist",
        "researcher", "study suggests", "research suggests", "could be", "may be",
        "might be",
        "predicen", "preocupación",          // ES
        "previsione", "preoccupazione",      // IT
        "vorhersage", "besorgt",             // DE
        "tahmin", "endişe"                   // TR
    ]

    private static let genericCaseKeywords: [String] = [
        "case", "cases", "infected", "infection", "patient", "patients",
        "outbreak", "hospital",
        "caso", "casos",                     // ES/PT
        "fall ", "fälle",                    // DE
        "vaka",                              // TR
        "cas "                               // FR
    ]
}

extension Signal {
    /// Best-effort source-language detection from the upstream bucket name.
    /// Examples: `GoogleNews-tr-TR` → `tr`, `GoogleNews-en-US` → `en`.
    /// Returns `nil` for buckets that don't match the locale-tagged pattern
    /// (caller can fall back to NLLanguageRecognizer if needed).
    var detectedLanguage: String? {
        // Pattern: <prefix>-<lang2>-<region2>  with optional trailing crumbs.
        guard let match = sourceBucket.range(
            of: #"-([a-z]{2})-[A-Z]{2}(\b|$)"#,
            options: .regularExpression
        ) else { return nil }
        let token = sourceBucket[match]
        // token looks like "-tr-TR"; extract the 2-letter lang code.
        let parts = token.split(separator: "-", omittingEmptySubsequences: true)
        guard let lang = parts.first, lang.count == 2 else { return nil }
        return String(lang).lowercased()
    }

    /// Whether the signal text is in a language other than the device's first
    /// preferred language. Used to gate the translate affordance.
    var isInForeignLanguage: Bool {
        guard let detected = detectedLanguage else { return false }
        let device = Locale.current.language.languageCode?.identifier.lowercased() ?? "en"
        return detected != device
    }

    /// If this is an EXPERT_VOICE / commentary signal whose text contains a
    /// forecast keyword + a near-term horizon, return a synthetic projected
    /// publication date in the future. Used by the map timeline scrubber to
    /// show "what experts are predicting" when the user drags past `now`.
    /// Returns `nil` for non-forecast signals.
    var projectedDate: Date? {
        guard mapPostType == .expertVoice else { return nil }
        let text = (title + " " + (summary ?? "")).lowercased()

        // Estimate horizon from explicit time-window phrases. Falls back to
        // 14 days when a forecast keyword is present but no horizon is stated.
        let forecastKeywords = [
            "predict", "predicts", "prediction", "forecast", "forecasts",
            "could rise", "could spread", "could increase", "may rise",
            "may spread", "might rise", "might spread", "expected to",
            "experts say", "scientists believe", "research suggests"
        ]
        guard forecastKeywords.contains(where: { text.contains($0) }) else { return nil }

        let cal = Calendar.current
        var horizon: Int = 14  // default fallback
        if text.contains("next week") || text.contains("within a week") || text.contains("seven days") {
            horizon = 7
        } else if text.contains("next month") || text.contains("within a month") || text.contains("30 days") {
            horizon = 30
        } else if text.contains("next year") {
            horizon = 365
        } else {
            // Look for "in N days/weeks/months"
            let regex = try? NSRegularExpression(
                pattern: #"\b(in|within)\s+(\d{1,3})\s+(day|week|month)"#
            )
            if let m = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               m.numberOfRanges >= 4,
               let nRange = Range(m.range(at: 2), in: text),
               let unitRange = Range(m.range(at: 3), in: text),
               let n = Int(text[nRange])
            {
                let unit = text[unitRange]
                if unit.contains("day")   { horizon = n }
                if unit.contains("week")  { horizon = n * 7 }
                if unit.contains("month") { horizon = n * 30 }
            }
        }
        return cal.date(byAdding: .day, value: horizon, to: publishedAt)
    }
}

struct CountrySignalAggregate: Identifiable, Codable, Hashable {
    var id: String { countryISO }
    let countryISO: String
    let last30dCount: Int
    let last6mCount: Int
    let last1yCount: Int
    let allTimeCount: Int
    let activeLevel: CountryActiveLevel
    let lastSignalAt: Date?
}

/// 5-tier emergency classification used by the Alerts feature. Mirrors the
/// language WHO + national health agencies use, mapped to a stable enum so
/// changes can be detected across snapshots.
enum EmergencyClassification: String, CaseIterable, Identifiable, Codable {
    case none                  = "NONE"
    case advisory              = "ADVISORY"
    case outbreak              = "OUTBREAK"
    case nationalEmergency     = "NATIONAL_EMERGENCY"
    case internationalConcern  = "INTERNATIONAL_CONCERN"

    var id: String { rawValue }

    /// Order — used for "level ≥ X" comparisons (severity threshold).
    var severity: Int {
        switch self {
        case .none: return 0
        case .advisory: return 1
        case .outbreak: return 2
        case .nationalEmergency: return 3
        case .internationalConcern: return 4
        }
    }

    var title: String {
        switch self {
        case .none:                  "No emergency"
        case .advisory:              "Health advisory"
        case .outbreak:              "Outbreak"
        case .nationalEmergency:     "National emergency"
        case .internationalConcern:  "International concern"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:                  "No"
        case .advisory:              "Advisory"
        case .outbreak:              "Outbreak"
        case .nationalEmergency:     "National"
        case .internationalConcern:  "PHEIC"
        }
    }

    var blurb: String {
        switch self {
        case .none:                  "No active health emergency"
        case .advisory:              "Preventive guidance issued by health authority"
        case .outbreak:              "Active local cases reported"
        case .nationalEmergency:     "Declared by national health authority"
        case .internationalConcern:  "WHO Public Health Emergency of International Concern"
        }
    }
}

/// Current classification snapshot for a country.
struct CountryClassification: Identifiable, Codable, Hashable {
    var id: String { countryISO }
    let countryISO: String
    let countryName: String
    let level: EmergencyClassification
    let sourceOrganisation: String      // "WHO", "ECDC", "CDC", "PAHO", etc.
    let sourceUrl: URL
    let declaredAt: Date
    let summary: String
}

/// One change in the audit log — used to detect "from → to" transitions and
/// drive both the in-app inbox and notification scheduling.
struct ClassificationChange: Identifiable, Codable, Hashable {
    var id: String { "\(countryISO)#\(changedAt.timeIntervalSince1970)" }
    let countryISO: String
    let countryName: String
    let fromLevel: EmergencyClassification
    let toLevel: EmergencyClassification
    let changedAt: Date
    let sourceOrganisation: String
    let sourceUrl: URL

    /// True when the change is an escalation (severity went up). Drives the
    /// notification trigger — we don't notify on de-escalations.
    var isEscalation: Bool { toLevel.severity > fromLevel.severity }
}

/// User-facing alert preferences. Persisted via UserDefaults inside
/// `LocalPreferences` so the user controls what they get notified about.
enum AlertFrequency: String, CaseIterable, Identifiable, Codable {
    case realtime
    case daily
    case weekly
    case off

    var id: String { rawValue }
    var title: String {
        switch self {
        case .realtime: "Real-time"
        case .daily:    "Daily digest"
        case .weekly:   "Weekly summary"
        case .off:      "Off"
        }
    }
}

struct AppStats: Codable, Hashable {
    let updatedAt: Date
    let signalsTotal: Int
    let signalsLast30d: Int
    let countriesActive: Int
    let topSources: [TopSource]

    struct TopSource: Codable, Hashable {
        let bucket: String
        let count: Int
    }
}

@MainActor
@Observable
final class SurveillanceRepository {
    private static let mapSignalFetchLimit = 5_000

    var isRefreshing = false
    var lastError: String?
    var hasLoadedFromNetwork = false

    /// True while a refresh that was triggered by a disease-mode change is in
    /// flight. `hasLoadedFromNetwork` latches true after the first load and
    /// never resets, so it can't gate the loading skeleton on subsequent mode
    /// switches — this flag does, so Both / Ebola show the same skeleton the
    /// default mode shows on cold start.
    var isSwitchingMode = false

    private var summarySnapshot: AppSummary
    private var countriesSnapshot: [CountrySnapshot]
    private var alertsSnapshot: [OfficialAlert]
    private var guideSnapshot: [GuideArticle]
    private var mapSnapshot: [MapCountry]
    private var activeDiseaseMode: DiseaseMode = .both

    // Live signal-side state — populated by /v1/signals, /v1/map-aggregates, /v1/stats.
    private(set) var signals: [Signal] = []
    private(set) var aggregates: [CountrySignalAggregate] = []
    private(set) var stats: AppStats?
    var timeRange: SignalTimeRange = .all

    // Alerts-side state — populated by /v1/alerts/classifications and
    // /v1/alerts/changes when the backend ships those endpoints. Until then
    // we derive client-side from `aggregates` so the Alerts tab is functional
    // from day one.
    private(set) var classificationsCache: [CountryClassification]? = nil
    private(set) var changesCache: [ClassificationChange]? = nil

    private let client: APIClient
    private let knownSignalCountriesKey = "signals.knownCountryISOSet"
    private let notifiedCaseSignalIDsKey = "alerts.notifiedCaseSignalIDs"
    private let newsBurstCountsKey = "alerts.newsBurstCountsByCountry"

    init(client: APIClient = .makeDefault()) {
        self.summarySnapshot = Fixtures.summary(for: .both)
        self.countriesSnapshot = CountryCatalogue.merged(with: Fixtures.countries(for: .both))
        self.alertsSnapshot = Fixtures.alerts(for: .both)
        self.guideSnapshot = Fixtures.guideArticles(for: .both)
        self.mapSnapshot = Fixtures.mapCountries(for: .both)
        self.signals = Fixtures.signals(for: .both)
        self.aggregates = Fixtures.signalAggregates(for: .both)
        self.stats = Fixtures.stats(for: .both)
        self.client = client
    }

    func summary() -> AppSummary { summarySnapshot }
    func countries() -> [CountrySnapshot] { countriesSnapshot }
    func country(isoCode: String) -> CountrySnapshot? {
        countriesSnapshot.first { $0.isoCode == isoCode }
    }
    func alerts() -> [OfficialAlert] { alertsSnapshot }
    func guideArticles(section: GuideSection) -> [GuideArticle] {
        guideSnapshot.filter { $0.section == section }
    }
    func mapCountries() -> [MapCountry] { mapSnapshot }

    private func applyLocalFixtures(for mode: DiseaseMode) {
        activeDiseaseMode = mode
        summarySnapshot = Fixtures.summary(for: mode)
        countriesSnapshot = countriesForDisplay(Fixtures.countries(for: mode), mode: mode)
        alertsSnapshot = Fixtures.alerts(for: mode)
        guideSnapshot = Fixtures.guideArticles(for: mode)
        mapSnapshot = Fixtures.mapCountries(for: mode)
        signals = Fixtures.signals(for: mode)
        aggregates = Fixtures.signalAggregates(for: mode)
        stats = Fixtures.stats(for: mode)
        classificationsCache = nil
        changesCache = nil
    }

    private func countriesForDisplay(_ countries: [CountrySnapshot], mode: DiseaseMode) -> [CountrySnapshot] {
        switch mode {
        case .hantavirus:
            return CountryCatalogue.merged(with: countries)
        case .ebola:
            return countries
        case .both:
            return CountryCatalogue.merged(with: countries)
        }
    }

    func aggregate(for isoCode: String) -> CountrySignalAggregate? {
        aggregates.first { $0.countryISO.uppercased() == isoCode.uppercased() }
    }

    // MARK: - Alerts (classifications + changes)

    /// Classifications per country — backend-authoritative when present, derived
    /// from `aggregates` + `signals` otherwise. Same shape either way so the UI
    /// is a single code path.
    func classifications() -> [CountryClassification] {
        if let cache = classificationsCache, !cache.isEmpty { return cache }
        return derivedClassifications()
    }

    func classification(for isoCode: String) -> CountryClassification? {
        classifications().first { $0.countryISO == isoCode.uppercased() }
    }

    /// Recent classification changes (newest first). When backend doesn't
    /// supply yet, we don't fabricate change history — return [] until we
    /// have at least one snapshot diff to compare against.
    func recentChanges(limit: Int = 30) -> [ClassificationChange] {
        Array((changesCache ?? derivedChanges()).prefix(limit))
    }

    /// Derive a conservative classification per country from existing live data.
    /// Bias: NONE / ADVISORY when uncertain. OUTBREAK only when there's
    /// explicit ground-truth evidence (DEATH or CASE_CONFIRMED post types
    /// across multiple sources). Previous heuristic was over-classifying:
    /// the US had heavy media discussion of an Atlantic-cruise outbreak but
    /// no actual local US cases — and was getting tagged OUTBREAK. Fixed.
    ///
    /// Promotion ladder (highest level wins):
    /// • PHEIC keyword in any signal              → INTERNATIONAL_CONCERN
    /// • Explicit "national emergency declared"   → NATIONAL_EMERGENCY
    /// • ≥2 DEATH posts AND ≥3 sources reporting  → NATIONAL_EMERGENCY
    /// • ≥2 DEATH or CASE_CONFIRMED + ≥2 sources  → OUTBREAK
    /// • ≥1 CASE_CONFIRMED or CASE_IMPORTED       → ADVISORY
    /// • RESPONSE / EXPERT_VOICE only             → ADVISORY (just discourse)
    /// • Otherwise                                → NONE
    private func derivedClassifications() -> [CountryClassification] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = signals.filter { $0.publishedAt > cutoff }
        let pheicKeywords = ["pheic", "international concern", "international emergency"]
        let nationalKeywords = ["national emergency", "state of emergency", "emergency declared"]

        return aggregates.compactMap { agg -> CountryClassification? in
            let iso = agg.countryISO
            let countrySignals = recent.filter { $0.countryISO == iso }
            let level: EmergencyClassification = {
                let titles = countrySignals.map { $0.title.lowercased() + " " + ($0.summary?.lowercased() ?? "") }
                if titles.contains(where: { t in pheicKeywords.contains { t.contains($0) } }) {
                    return .internationalConcern
                }
                if titles.contains(where: { t in nationalKeywords.contains { t.contains($0) } }) {
                    return .nationalEmergency
                }
                let deaths = countrySignals.filter { $0.mapPostType == .death }
                let confirmed = countrySignals.filter { $0.mapPostType == .caseConfirmed }
                let imported = countrySignals.filter { $0.mapPostType == .caseImported }
                let groundTruth = deaths + confirmed
                let buckets = Set(groundTruth.map { $0.sourceBucket }).count

                if deaths.count >= 2 && Set(deaths.map { $0.sourceBucket }).count >= 3 {
                    return .nationalEmergency
                }
                if groundTruth.count >= 2 && buckets >= 2 {
                    return .outbreak
                }
                if !confirmed.isEmpty || !imported.isEmpty {
                    return .advisory
                }
                // Pure discourse / response / expert-voice with no confirmed
                // cases → ADVISORY at most. The US had this exact pattern
                // (lots of "experts say" + cruise-ship media) and was being
                // mis-classified as OUTBREAK before.
                if !countrySignals.isEmpty {
                    return .advisory
                }
                return .none
            }()

            // Pick a representative source from the most-recent signal for the country.
            let representative = countrySignals.first
            let countryName = country(isoCode: iso)?.countryName ?? iso
            return CountryClassification(
                countryISO: iso,
                countryName: countryName,
                level: level,
                sourceOrganisation: representative?.sourceBucket ?? "Aggregate",
                sourceUrl: representative?.url ?? URL(string: "https://www.who.int/emergencies")!,
                declaredAt: representative?.publishedAt ?? agg.lastSignalAt ?? Date(),
                summary: representative?.title ?? level.blurb
            )
        }
    }

    /// In-memory change detection: compare current derived classifications to
    /// the snapshot persisted in UserDefaults under the alerts key. Returns
    /// the list of detected changes (escalations + de-escalations) sorted
    /// newest first.
    private func derivedChanges() -> [ClassificationChange] {
        let snapshotKey = "alerts.lastClassificationSnapshot"
        let stored = UserDefaults.standard.dictionary(forKey: snapshotKey) as? [String: String] ?? [:]
        let now = Date()
        var out: [ClassificationChange] = []
        for c in derivedClassifications() {
            let prevRaw = stored[c.countryISO]
            let prev = prevRaw.flatMap(EmergencyClassification.init(rawValue:)) ?? .none
            if prev != c.level {
                out.append(ClassificationChange(
                    countryISO: c.countryISO,
                    countryName: c.countryName,
                    fromLevel: prev,
                    toLevel: c.level,
                    changedAt: now,
                    sourceOrganisation: c.sourceOrganisation,
                    sourceUrl: c.sourceUrl
                ))
            }
        }
        return out.sorted { $0.changedAt > $1.changedAt }
    }

    /// Persist the current classification snapshot. Called after the user
    /// has been notified, so the next refresh detects only new changes.
    func commitClassificationSnapshot() {
        let snapshotKey = "alerts.lastClassificationSnapshot"
        let snapshot = derivedClassifications().reduce(into: [String: String]()) { dict, c in
            dict[c.countryISO] = c.level.rawValue
        }
        UserDefaults.standard.set(snapshot, forKey: snapshotKey)
    }

    @MainActor
    func refresh(preferences: LocalPreferences? = nil) async {
        guard !isRefreshing else { return }
        let diseaseMode = preferences?.selectedDiseaseMode ?? activeDiseaseMode
        let modeChanged = activeDiseaseMode != diseaseMode
        if modeChanged {
            applyLocalFixtures(for: diseaseMode)
            isSwitchingMode = true
        }
        isRefreshing = true
        defer {
            isRefreshing = false
            isSwitchingMode = false
        }

        do {
            async let summary = client.summary(disease: diseaseMode)
            async let countries = client.countries(disease: diseaseMode)
            async let alerts = client.feed(disease: diseaseMode)
            async let guide = client.guide(disease: diseaseMode)
            async let map = client.mapCountries(metric: .confidence, disease: diseaseMode)
            async let signalsResp = client.signals(range: timeRange, limit: Self.mapSignalFetchLimit, disease: diseaseMode)
            async let aggsResp = client.mapAggregates(disease: diseaseMode)
            async let statsResp = client.stats(disease: diseaseMode)

            let fetchedCountries = try await countries
            guard backendResponseSupports(diseaseMode, countries: fetchedCountries) else {
                // Old production API builds normalize unknown disease query
                // values back to Hantavirus. Keep the local fixture state
                // instead of replacing Ebola/Both with Hanta-looking data.
                self.hasLoadedFromNetwork = false
                self.lastError = nil
                return
            }

            self.summarySnapshot = try await summary
            self.countriesSnapshot = countriesForDisplay(fetchedCountries, mode: diseaseMode)
            self.alertsSnapshot = try await alerts
            self.guideSnapshot = try await guide
            let fetchedMap = try await map
            if backendResponseSupports(diseaseMode, mapCountries: fetchedMap) {
                self.mapSnapshot = fetchedMap
            }
            var acceptedSignals = diseaseMode == .hantavirus
            if let fetchedSignals = try? await signalsResp {
                acceptedSignals = backendResponseSupports(diseaseMode, signals: fetchedSignals)
                if acceptedSignals {
                    self.signals = fetchedSignals
                }
                if acceptedSignals, let preferences {
                    await notifyNewSignalCountriesIfNeeded(fetchedSignals, preferences: preferences)
                    await notifyTrackedCountryRulesIfNeeded(fetchedSignals, preferences: preferences)
                }
            }
            if let fetchedAggregates = try? await aggsResp {
                if backendResponseSupports(diseaseMode, aggregates: fetchedAggregates) {
                    self.aggregates = fetchedAggregates
                }
            }
            if let fetchedStats = try? await statsResp {
                if acceptedSignals || fetchedStats.signalsTotal == 0 && diseaseMode == .hantavirus {
                    self.stats = fetchedStats
                }
            }
            self.lastError = nil
            self.hasLoadedFromNetwork = true
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func backendResponseSupports(_ mode: DiseaseMode, countries: [CountrySnapshot]) -> Bool {
        backendResponseSupports(mode, isos: Set(countries.map { $0.isoCode.uppercased() }))
    }

    private func backendResponseSupports(_ mode: DiseaseMode, signals: [Signal]) -> Bool {
        backendResponseSupports(mode, isos: Set(signals.compactMap { $0.countryISO?.uppercased() }))
    }

    private func backendResponseSupports(_ mode: DiseaseMode, mapCountries: [MapCountry]) -> Bool {
        backendResponseSupports(mode, isos: Set(mapCountries.map { $0.isoCode.uppercased() }))
    }

    private func backendResponseSupports(_ mode: DiseaseMode, aggregates: [CountrySignalAggregate]) -> Bool {
        backendResponseSupports(mode, isos: Set(aggregates.map { $0.countryISO.uppercased() }))
    }

    private func backendResponseSupports(_ mode: DiseaseMode, isos: Set<String>) -> Bool {
        let hantaAnchors: Set<String> = ["US", "AR", "DE", "CL", "PE"]
        let ebolaAnchors: Set<String> = ["CD", "UG", "GN", "SL"]
        switch mode {
        case .hantavirus:
            return true
        case .ebola:
            return !isos.isDisjoint(with: ebolaAnchors)
        case .both:
            return !isos.isDisjoint(with: hantaAnchors) && !isos.isDisjoint(with: ebolaAnchors)
        }
    }

    @MainActor
    func setTimeRange(_ range: SignalTimeRange) async {
        self.timeRange = range
        if let fetched = try? await client.signals(range: range, limit: Self.mapSignalFetchLimit, disease: activeDiseaseMode),
           backendResponseSupports(activeDiseaseMode, signals: fetched) {
            self.signals = fetched
        }
    }

    @MainActor
    func deckSignals(days: Int, limit: Int, minSeverity: AlertSeverity?) async -> [Signal] {
        if let fetched = try? await client.deckSignals(days: days, limit: limit, minSeverity: minSeverity, disease: activeDiseaseMode),
           backendResponseSupports(activeDiseaseMode, signals: fetched) {
            return fetched
        }
        return signals
    }

    @MainActor
    func reloadMap(metric: MapMetric) async {
        do {
            let fetched = try await client.mapCountries(metric: metric, disease: activeDiseaseMode)
            if backendResponseSupports(activeDiseaseMode, mapCountries: fetched) {
                self.mapSnapshot = fetched
            }
        } catch {
            // Keep the previous snapshot on failure.
        }
    }

    private func notifyNewSignalCountriesIfNeeded(_ fetchedSignals: [Signal], preferences: LocalPreferences) async {
        let currentCountries = Set(fetchedSignals.compactMap { $0.countryISO?.uppercased() })
        guard !currentCountries.isEmpty else { return }

        let storedCountries = Set(UserDefaults.standard.stringArray(forKey: knownSignalCountriesKey) ?? [])
        guard !storedCountries.isEmpty else {
            // First live sync: establish the baseline silently so a fresh
            // install does not fire dozens of "new country" notifications.
            UserDefaults.standard.set(Array(currentCountries).sorted(), forKey: knownSignalCountriesKey)
            return
        }

        let newlySeen = currentCountries.subtracting(storedCountries)
        guard !newlySeen.isEmpty else { return }
        UserDefaults.standard.set(Array(storedCountries.union(currentCountries)).sorted(), forKey: knownSignalCountriesKey)

        let signalsByCountry = Dictionary(grouping: fetchedSignals) { $0.countryISO?.uppercased() ?? "" }
        for iso in newlySeen.sorted() {
            let count = signalsByCountry[iso]?.count ?? 1
            _ = await NotificationService.shared.scheduleNewSignalCountry(
                isoCode: iso,
                countryName: displayName(for: iso),
                signalCount: count,
                preferences: preferences
            )
        }
    }

    private func notifyTrackedCountryRulesIfNeeded(_ fetchedSignals: [Signal], preferences: LocalPreferences) async {
        await notifyTrackedCountryCasesIfNeeded(fetchedSignals, preferences: preferences)
        await notifyTrackedCountryNewsBurstsIfNeeded(fetchedSignals, preferences: preferences)
    }

    private func notifyTrackedCountryCasesIfNeeded(_ fetchedSignals: [Signal], preferences: LocalPreferences) async {
        let caseSignals = fetchedSignals
            .filter(isCaseSignal)
            .filter { preferences.shouldShowCountry($0.countryISO, includeAllWhenEmpty: false) }
        let currentCaseIDs = Set(fetchedSignals.filter(isCaseSignal).map(\.id))
        let storedCaseIDs = Set(UserDefaults.standard.stringArray(forKey: notifiedCaseSignalIDsKey) ?? [])

        guard !storedCaseIDs.isEmpty else {
            UserDefaults.standard.set(Array(currentCaseIDs).sorted(), forKey: notifiedCaseSignalIDsKey)
            return
        }

        let newCaseSignals = caseSignals.filter { !storedCaseIDs.contains($0.id) }
        guard !newCaseSignals.isEmpty else {
            UserDefaults.standard.set(Array(storedCaseIDs.union(currentCaseIDs)).sorted(), forKey: notifiedCaseSignalIDsKey)
            return
        }

        for signal in newCaseSignals.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            _ = await NotificationService.shared.scheduleTrackedCountryCaseSignal(
                signal: signal,
                countryName: displayName(for: signal.countryISO ?? ""),
                preferences: preferences
            )
        }
        UserDefaults.standard.set(Array(storedCaseIDs.union(currentCaseIDs)).sorted(), forKey: notifiedCaseSignalIDsKey)
    }

    private func notifyTrackedCountryNewsBurstsIfNeeded(_ fetchedSignals: [Signal], preferences: LocalPreferences) async {
        let countsByCountry = Dictionary(grouping: fetchedSignals) { signal in
            signal.countryISO?.uppercased() ?? ""
        }
        .filter { !$0.key.isEmpty }
        .mapValues { $0.count }

        let storedCounts = UserDefaults.standard.dictionary(forKey: newsBurstCountsKey) as? [String: Int] ?? [:]
        guard !storedCounts.isEmpty else {
            UserDefaults.standard.set(countsByCountry, forKey: newsBurstCountsKey)
            return
        }

        for (iso, count) in countsByCountry where count > 3 {
            let previous = storedCounts[iso] ?? 0
            guard previous <= 3 else { continue }
            guard preferences.shouldShowCountry(iso, includeAllWhenEmpty: false) else { continue }
            _ = await NotificationService.shared.scheduleTrackedCountryNewsBurst(
                isoCode: iso,
                countryName: displayName(for: iso),
                signalCount: count,
                preferences: preferences
            )
        }

        UserDefaults.standard.set(countsByCountry, forKey: newsBurstCountsKey)
    }

    private func isCaseSignal(_ signal: Signal) -> Bool {
        switch signal.mapPostType {
        case .death, .caseConfirmed, .caseSuspected, .caseImported:
            return true
        case .officialResponse, .expertVoice, .publicDiscourse:
            return false
        }
    }

    private func displayName(for isoCode: String) -> String {
        country(isoCode: isoCode)?.countryName
            ?? Locale.current.localizedString(forRegionCode: isoCode)
            ?? isoCode
    }
}

extension Date {
    static func fixture(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
