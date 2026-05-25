import Foundation
import CoreLocation
import MapKit

/// Bundled simplified world country polygons (Natural Earth 1:110m).
/// Stripped to `{ iso, geometry }` and rounded to ~110m precision (190 KB on disk).
///
/// API: `WorldGeometry.shared.rings(for: "AR")` returns the outer rings of every
/// polygon ring that makes up the country. MultiPolygons (archipelagos, antimeridian
/// splits like Russia/US/Fiji) come back as multiple ring arrays.
///
/// The geometry is intentionally NOT used for hit-testing — pin taps stay on
/// `CountryCentroids`. This is a visual-only overlay.
/// `@MainActor @Observable` so SwiftUI re-renders the polygon overlay when
/// the GeoJSON finishes parsing. The 190 KB bundled file is decoded on a
/// background-priority task instead of synchronously on the main thread —
/// the latter caused a ~4 second main-thread freeze the first time the map
/// appeared (the user-visible "FPS drop to 0").
@MainActor
@Observable
final class WorldGeometry {
    static let shared = WorldGeometry()

    /// Country ISO-A2 → array of polygon-outer-rings. Each ring is a polyline of
    /// coordinates, closed (first ≈ last). MultiPolygon countries have N rings.
    /// Empty until the background parse completes; SwiftUI re-renders when it does.
    private(set) var rings: [String: [[CLLocationCoordinate2D]]] = [:]

    /// Endemic countries — established hantavirus-presence regions per WHO + CDC +
    /// Robert Koch Institute + national surveillance. These get a low-alpha yellow
    /// fill on the map even with zero recent signals, to communicate "this is not
    /// a hantavirus-naïve region."
    static let endemicCountries: Set<String> = [
        // Americas — New World hantaviruses (Andes, Sin Nombre, Laguna Negra…)
        "AR", "CL", "BR", "PY", "BO", "UY", "PE", "PA", "US", "CA",
        // Europe — Old World (Puumala, Dobrava, Tula, Saaremaa)
        "FI", "SE", "NO", "DE", "BE", "FR", "AT", "CZ", "SK", "PL", "HU",
        "SI", "HR", "RS", "BA", "BG", "RO", "GR", "EE", "LT", "LV",
        "RU", "BY", "UA",
        // Asia — Hantaan, Seoul, Amur
        "CN", "KR", "JP", "TW", "MN", "VN", "TH", "MY", "ID"
    ]

    private init() {
        // Kick off async parse off the main thread. UI starts empty and
        // populates once the parse completes (typically <1s on device).
        Task.detached(priority: .userInitiated) {
            let parsed = WorldGeometry.loadBundledGeoJSON()
            await MainActor.run {
                WorldGeometry.shared.rings = parsed
            }
        }
    }

    func rings(for isoCode: String) -> [[CLLocationCoordinate2D]]? {
        rings[isoCode.uppercased()]
    }

    nonisolated private static func loadBundledGeoJSON() -> [String: [[CLLocationCoordinate2D]]] {
        guard let url = Bundle.main.url(forResource: "world-countries-110m", withExtension: "geojson") else {
            assertionFailure("world-countries-110m.geojson missing from bundle")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let root = try JSONDecoder().decode(FeatureCollection.self, from: data)
            var out: [String: [[CLLocationCoordinate2D]]] = [:]
            for feature in root.features {
                let iso = feature.properties.iso.uppercased()
                let parsed = feature.geometry.toCoordinateRings()
                guard !parsed.isEmpty else { continue }
                out[iso, default: []].append(contentsOf: parsed)
            }
            return out
        } catch {
            assertionFailure("failed to parse world-countries GeoJSON: \(error)")
            return [:]
        }
    }
}

// MARK: - Minimal GeoJSON decoder

private struct FeatureCollection: Decodable {
    let features: [Feature]
}

private struct Feature: Decodable {
    let properties: FeatureProperties
    let geometry: Geometry
}

private struct FeatureProperties: Decodable {
    let iso: String
}

/// Polygon: `[[[lon,lat], …], …]` (rings; first ring is outer, rest are holes — we ignore holes).
/// MultiPolygon: `[[[[lon,lat], …], …], …]`.
private struct Geometry: Decodable {
    let type: String
    let coordinates: AnyCoordinates

    func toCoordinateRings() -> [[CLLocationCoordinate2D]] {
        switch type {
        case "Polygon":
            // coordinates: [[[lon,lat], …], …]
            guard case .twoLevel(let polygon) = coordinates else { return [] }
            // Outer ring only — holes are visual noise at world-zoom.
            guard let outer = polygon.first else { return [] }
            return [outer.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }]
        case "MultiPolygon":
            // coordinates: [[[[lon,lat], …], …], …]
            guard case .threeLevel(let multi) = coordinates else { return [] }
            return multi.compactMap { polygon in
                guard let outer = polygon.first else { return nil }
                return outer.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
            }
        default:
            return []
        }
    }
}

/// GeoJSON's `coordinates` is shape-polymorphic between Polygon and MultiPolygon.
/// Decode generously: we only ever expect 2-level or 3-level nesting at this scale.
private enum AnyCoordinates: Decodable {
    case twoLevel([[[Double]]])     // Polygon
    case threeLevel([[[[Double]]]]) // MultiPolygon

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let three = try? single.decode([[[[Double]]]].self) {
            self = .threeLevel(three)
            return
        }
        if let two = try? single.decode([[[Double]]].self) {
            self = .twoLevel(two)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: single,
            debugDescription: "Unsupported GeoJSON coordinates shape"
        )
    }
}
