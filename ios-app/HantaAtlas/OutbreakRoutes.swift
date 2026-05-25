import Foundation
import CoreLocation

/// Bundled outbreak-route polylines (e.g. MV Hondius cruise itinerary). Loaded
/// once from `Resources/outbreak-routes.json`. The resource is intentionally
/// app-bundled rather than fetched: routes are extremely low-frequency content
/// and any new ones can ship with the next app update. If/when the volume
/// justifies a backend endpoint, swap this loader to one that hits
/// `/v1/outbreak-routes` — DTOs already match the JSON shape.

struct OutbreakRoute: Identifiable, Sendable {
    let id: String
    let name: String
    let summary: String
    let status: Status
    let lastReportedAt: Date
    let color: ColorToken
    let waypoints: [Waypoint]
    let currentPosition: CLLocationCoordinate2D?

    enum Status: String, Codable, Sendable { case atSea = "AT_SEA", inPort = "IN_PORT", concluded = "CONCLUDED" }
    enum ColorToken: String, Codable, Sendable { case terracotta, amber, moss }

    struct Waypoint: Sendable {
        let name: String
        let iso: String?
        let coordinate: CLLocationCoordinate2D
        let kind: Kind
        let date: Date

        enum Kind: String, Codable, Sendable {
            case portOfDeparture = "PORT_OF_DEPARTURE"
            case portOfCall      = "PORT_OF_CALL"
            case waypointAtSea   = "WAYPOINT_AT_SEA"
            case quarantinePort  = "QUARANTINE_PORT"
        }
    }
}

extension OutbreakRoute {
    /// Polyline coordinates for the SwiftUI MapPolyline overlay.
    var polyline: [CLLocationCoordinate2D] { waypoints.map(\.coordinate) }
}

// MARK: - Bundled loader

@MainActor
@Observable
final class OutbreakRoutes {
    static let shared = OutbreakRoutes()
    private(set) var routes: [OutbreakRoute] = []

    private init() {
        Task.detached(priority: .userInitiated) {
            let loaded = OutbreakRoutes.loadBundled()
            await MainActor.run {
                OutbreakRoutes.shared.routes = loaded
            }
        }
    }

    nonisolated private static func loadBundled() -> [OutbreakRoute] {
        guard let url = Bundle.main.url(forResource: "outbreak-routes", withExtension: "json") else {
            assertionFailure("outbreak-routes.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder.iso8601().decode(RoutesEnvelope.self, from: data)
            return raw.routes.map { $0.toModel() }
        } catch {
            assertionFailure("failed to parse outbreak-routes.json: \(error)")
            return []
        }
    }
}

// MARK: - JSON envelope

private struct RoutesEnvelope: Decodable {
    let schemaVersion: Int
    let routes: [RouteDTO]
}

private struct RouteDTO: Decodable {
    let id: String
    let name: String
    let summary: String
    let status: OutbreakRoute.Status
    let lastReportedAt: Date
    let color: OutbreakRoute.ColorToken
    let waypoints: [WaypointDTO]
    let currentPosition: PositionDTO?

    func toModel() -> OutbreakRoute {
        OutbreakRoute(
            id: id,
            name: name,
            summary: summary,
            status: status,
            lastReportedAt: lastReportedAt,
            color: color,
            waypoints: waypoints.map { $0.toModel() },
            currentPosition: currentPosition.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        )
    }
}

private struct WaypointDTO: Decodable {
    let name: String
    let iso: String?
    let lat: Double
    let lon: Double
    let kind: OutbreakRoute.Waypoint.Kind
    let date: Date

    func toModel() -> OutbreakRoute.Waypoint {
        OutbreakRoute.Waypoint(
            name: name,
            iso: iso,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            kind: kind,
            date: date
        )
    }
}

private struct PositionDTO: Decodable { let lat: Double; let lon: Double }

private extension JSONDecoder {
    static func iso8601() -> JSONDecoder {
        let d = JSONDecoder()
        // Waypoint dates are date-only (`2026-04-12`); top-level `lastReportedAt` is full ISO-8601.
        // Both ISO8601FormatStyle and the year/month/day variant are value-type Sendable.
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(s, strategy: .iso8601) { return date }
            if let date = try? Date(s, strategy: .iso8601.year().month().day()) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognised date format: \(s)"
            )
        }
        return d
    }
}
