import Foundation

// MARK: - DTOs

/// Wire DTOs that mirror `backend/api/src/types.ts`. We decode these and then
/// project into the existing app models so views stay unchanged.

private struct SourceDto: Decodable {
    let id: String
    let organisation: String
    let url: String
}

private struct CountrySnapshotDto: Decodable {
    let isoCode: String
    let countryName: String
    let regionName: String
    let cases: Int?
    let deaths: Int?
    let confidenceLevel: String
    let reportingPeriodLabel: String
    let reportedAt: String?
    let publishedAt: String?
    let lastCheckedAt: String
    let source: SourceDto
    let sourceUrl: String
    let summary: String
    let virusType: String
    let limitations: String
}

private struct OfficialAlertDto: Decodable {
    let id: String
    let title: String
    let countryName: String
    let regionName: String
    let source: SourceDto
    let severity: String
    let confidenceLevel: String
    let reportedAt: String
    let publishedAt: String
    let summary: String
}

private struct SummaryDto: Decodable {
    let checkedAt: String
    let countryCount: Int
    let officialAlertCount: Int
    let savedCountSeed: Int
    let latestAlert: OfficialAlertDto
}

private struct MapPointDto: Decodable {
    let x: Double
    let y: Double
}

private struct MapCountryDto: Decodable {
    let isoCode: String
    let name: String
    let confidenceLevel: String
    let cases: Int?
    let alerts: Int
    let polygons: [[MapPointDto]]
}

private struct GuideArticleDto: Decodable {
    let id: String
    let section: String
    let title: String
    let body: String
    let symbolName: String
}

private struct SignalDto: Decodable {
    let id: String
    let title: String
    let summary: String?
    let url: String
    let sourceBucket: String
    let publishedAt: String
    let countryISO: String?
    let category: String
    let severity: String
    let postType: String?
    let primaryMedia: SignalMediaDto?
}

private struct SignalMediaDto: Decodable {
    let type: String
    let url: String
    let thumbnailUrl: String?
    let provider: String?
    let sourceUrl: String?
    let width: Int?
    let height: Int?
}

private struct CountrySignalAggregateDto: Decodable {
    let countryISO: String
    let last30dCount: Int
    let last6mCount: Int
    let last1yCount: Int
    let allTimeCount: Int
    let activeLevel: String
    let lastSignalAt: String?
}

private struct AppStatsDto: Decodable {
    let updatedAt: String
    let signalsTotal: Int
    let signalsLast30d: Int
    let countriesActive: Int
    let topSources: [TopSourceDto]
    struct TopSourceDto: Decodable {
        let bucket: String
        let count: Int
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case transport(Error)
    case status(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid API URL."
        case .transport(let error): "Network error: \(error.localizedDescription)"
        case .status(let code): "Server returned HTTP \(code)."
        case .decoding(let error): "Could not parse server response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Client

/// Tiny URLSession-based client targeting the HantaAtlas Fastify API. Reads
/// `API_BASE_URL` from the app's Info.plist; defaults to `http://localhost:3000`
/// for simulator development.
struct APIClient: Sendable {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = APIClient.defaultSession) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Fallback when `API_BASE_URL` is missing/invalid in Info.plist. Points at a
    /// local backend, which works in the iOS Simulator. On a real device, iOS
    /// cannot reach the host's localhost — set `API_BASE_URL` to your own HTTPS
    /// reverse-proxy / tunnel domain (see README → "Run the backend").
    static let fallbackBaseURL = URL(string: "http://localhost:3000")!

    /// Single source of truth for the backend origin, resolved once from the
    /// `API_BASE_URL` Info.plist key (falling back to `fallbackBaseURL`). Every
    /// networking caller — APIClient, AuthService, UserSession, PreferencesSync —
    /// routes through this, so the app points at a backend in exactly one place.
    static let resolvedBaseURL: URL = {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalised = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
            if let url = URL(string: normalised),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                return url
            }
        }
        return fallbackBaseURL
    }()

    /// Cold-start hardened URLSession.
    ///
    /// Two changes vs `URLSession.shared`:
    ///  1. `timeoutIntervalForRequest = 5` — default is 60 s. If the backend
    ///     is cold-booting or the QUIC handshake stalls (visible in the
    ///     simulator as `quic_crypto_queue_append`/`Operation timed out`
    ///     console spam), the app gives up after 5 s and falls back to
    ///     fixtures. Users no longer wait a minute to find that out.
    ///  2. `waitsForConnectivity = false` — without this, URLSession will
    ///     queue the request indefinitely on a flaky network instead of
    ///     failing fast. We surface the failure to the repository, which
    ///     keeps the seeded fixture data on screen.
    static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func makeDefault() -> APIClient {
        APIClient(baseURL: resolvedBaseURL)
    }

    // MARK: Endpoints

    func summary(disease: DiseaseMode = .both) async throws -> AppSummary {
        let dto: SummaryDto = try await fetch("/v1/summary?\(diseaseQuery(disease))")
        return AppSummary(
            checkedAt: parseDate(dto.checkedAt) ?? Date(),
            countryCount: dto.countryCount,
            officialAlertCount: dto.officialAlertCount,
            savedCount: dto.savedCountSeed
        )
    }

    func countries(disease: DiseaseMode = .both) async throws -> [CountrySnapshot] {
        let dtos: [CountrySnapshotDto] = try await fetch("/v1/countries?\(diseaseQuery(disease))")
        return dtos.map(map(country:))
    }

    func country(isoCode: String, disease: DiseaseMode = .both) async throws -> CountrySnapshot {
        let dto: CountrySnapshotDto = try await fetch("/v1/countries/\(isoCode)?\(diseaseQuery(disease))")
        return map(country: dto)
    }

    func feed(disease: DiseaseMode = .both) async throws -> [OfficialAlert] {
        let dtos: [OfficialAlertDto] = try await fetch("/v1/feed?\(diseaseQuery(disease))")
        return dtos.map(map(alert:))
    }

    func mapCountries(metric: MapMetric, disease: DiseaseMode = .both) async throws -> [MapCountry] {
        let dtos: [MapCountryDto] = try await fetch("/v1/map?metric=\(metric.rawValue)&\(diseaseQuery(disease))")
        return dtos.map(map(mapCountry:))
    }

    func guide(disease: DiseaseMode = .both) async throws -> [GuideArticle] {
        let dtos: [GuideArticleDto] = try await fetch("/v1/guide?\(diseaseQuery(disease))")
        return dtos.map(map(article:))
    }

    // ── Live signals ──

    func signals(range: SignalTimeRange = .y1, country: String? = nil, category: SignalCategory? = nil, limit: Int? = nil, disease: DiseaseMode = .both) async throws -> [Signal] {
        var q = "since=\(range.rawValue)&\(diseaseQuery(disease))"
        if let country { q += "&country=\(country)" }
        if let category { q += "&category=\(category.rawValue)" }
        if let limit { q += "&limit=\(limit)" }
        let dtos: [SignalDto] = try await fetch("/v1/signals?\(q)")
        return dtos.compactMap(map(signal:))
    }

    func deckSignals(days: Int = 30, limit: Int = 250, minSeverity: AlertSeverity? = nil, disease: DiseaseMode = .both) async throws -> [Signal] {
        var q = "days=\(days)&limit=\(limit)&\(diseaseQuery(disease))"
        if let minSeverity { q += "&minSeverity=\(minSeverity.rawValue)" }
        let dtos: [SignalDto] = try await fetch("/v1/signals/deck?\(q)")
        return dtos.compactMap(map(signal:))
    }

    func mapAggregates(disease: DiseaseMode = .both) async throws -> [CountrySignalAggregate] {
        let dtos: [CountrySignalAggregateDto] = try await fetch("/v1/map-aggregates?\(diseaseQuery(disease))")
        return dtos.map(map(aggregate:))
    }

    func stats(disease: DiseaseMode = .both) async throws -> AppStats {
        let dto: AppStatsDto = try await fetch("/v1/stats?\(diseaseQuery(disease))")
        return map(stats: dto)
    }

    // MARK: Plumbing

    private func diseaseQuery(_ disease: DiseaseMode) -> String {
        "disease=\(disease.rawValue)"
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await transport(url: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.status(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func transport(url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch {
            throw APIError.transport(error)
        }
    }

    // MARK: Mappers (DTO → app model)

    private func map(country dto: CountrySnapshotDto) -> CountrySnapshot {
        CountrySnapshot(
            id: "\(dto.isoCode)-\(dto.lastCheckedAt)",
            isoCode: dto.isoCode,
            countryName: dto.countryName,
            regionName: dto.regionName,
            cases: dto.cases,
            deaths: dto.deaths,
            reportingPeriodLabel: dto.reportingPeriodLabel,
            reportedAt: dto.reportedAt.flatMap(parseDate),
            publishedAt: dto.publishedAt.flatMap(parseDate),
            lastCheckedAt: parseDate(dto.lastCheckedAt) ?? Date(),
            source: Source(
                id: dto.source.id,
                organisation: dto.source.organisation,
                url: URL(string: dto.source.url) ?? URL(string: "https://example.com")!
            ),
            sourceUrl: URL(string: dto.sourceUrl) ?? URL(string: "https://example.com")!,
            summary: dto.summary,
            virusType: dto.virusType,
            limitations: dto.limitations,
            confidenceLevel: ConfidenceLevel(rawValue: dto.confidenceLevel) ?? .noRecentPublicData,
            trend: []
        )
    }

    private func map(alert dto: OfficialAlertDto) -> OfficialAlert {
        OfficialAlert(
            id: dto.id,
            title: dto.title,
            countryName: dto.countryName,
            regionName: dto.regionName,
            source: Source(
                id: dto.source.id,
                organisation: dto.source.organisation,
                url: URL(string: dto.source.url) ?? URL(string: "https://example.com")!
            ),
            severity: AlertSeverity(rawValue: dto.severity) ?? .low,
            confidenceLevel: ConfidenceLevel(rawValue: dto.confidenceLevel) ?? .noRecentPublicData,
            reportedAt: parseDate(dto.reportedAt) ?? Date(),
            publishedAt: parseDate(dto.publishedAt) ?? Date(),
            summary: dto.summary
        )
    }

    private func map(mapCountry dto: MapCountryDto) -> MapCountry {
        MapCountry(
            id: dto.isoCode,
            isoCode: dto.isoCode,
            name: dto.name,
            confidenceLevel: ConfidenceLevel(rawValue: dto.confidenceLevel) ?? .noRecentPublicData,
            cases: dto.cases,
            alerts: dto.alerts,
            polygons: dto.polygons.map { ring in ring.map { MapPoint(x: $0.x, y: $0.y) } }
        )
    }

    private func map(article dto: GuideArticleDto) -> GuideArticle {
        let section: GuideSection
        switch dto.section {
        case "prevention": section = .prevention
        case "symptoms": section = .symptoms
        default: section = .urgentCare
        }
        return GuideArticle(id: dto.id, section: section, title: dto.title, body: dto.body, symbolName: dto.symbolName)
    }

    private func map(signal dto: SignalDto) -> Signal? {
        guard let url = URL(string: dto.url),
              let publishedAt = parseDate(dto.publishedAt),
              let category = SignalCategory(rawValue: dto.category),
              let severity = AlertSeverity(rawValue: dto.severity) else {
            return nil
        }
        return Signal(
            id: dto.id,
            title: dto.title,
            summary: dto.summary,
            url: url,
            sourceBucket: dto.sourceBucket,
            publishedAt: publishedAt,
            countryISO: dto.countryISO,
            category: category,
            severity: severity,
            postType: dto.postType.flatMap(MapPostType.init(rawValue:)),
            primaryMedia: dto.primaryMedia.flatMap(map(media:))
        )
    }

    private func map(media dto: SignalMediaDto) -> SignalMedia? {
        guard let type = SignalMediaType(rawValue: dto.type),
              let url = URL(string: dto.url) else {
            return nil
        }
        return SignalMedia(
            type: type,
            url: url,
            thumbnailUrl: dto.thumbnailUrl.flatMap(URL.init(string:)),
            provider: dto.provider,
            sourceUrl: dto.sourceUrl.flatMap(URL.init(string:)),
            width: dto.width,
            height: dto.height
        )
    }

    private func map(aggregate dto: CountrySignalAggregateDto) -> CountrySignalAggregate {
        CountrySignalAggregate(
            countryISO: dto.countryISO,
            last30dCount: dto.last30dCount,
            last6mCount: dto.last6mCount,
            last1yCount: dto.last1yCount,
            allTimeCount: dto.allTimeCount,
            activeLevel: CountryActiveLevel(rawValue: dto.activeLevel) ?? .none,
            lastSignalAt: dto.lastSignalAt.flatMap(parseDate)
        )
    }

    private func map(stats dto: AppStatsDto) -> AppStats {
        AppStats(
            updatedAt: parseDate(dto.updatedAt) ?? Date(),
            signalsTotal: dto.signalsTotal,
            signalsLast30d: dto.signalsLast30d,
            countriesActive: dto.countriesActive,
            topSources: dto.topSources.map { AppStats.TopSource(bucket: $0.bucket, count: $0.count) }
        )
    }

    /// Parse RFC-3339 / ISO-8601 timestamps with or without fractional seconds.
    /// Uses `Date.ISO8601FormatStyle` (a value type) instead of the older
    /// `ISO8601DateFormatter` class so this method is Sendable-safe.
    private func parseDate(_ raw: String) -> Date? {
        let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let date = try? withFraction.parse(raw) { return date }
        let plain = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        return try? plain.parse(raw)
    }
}
