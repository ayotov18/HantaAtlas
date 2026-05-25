import XCTest
import SwiftUI
@testable import HantaAtlas

/// Image-diff style coverage for the five tabs plus Country Detail. Renders
/// each top-level screen with `ImageRenderer` and asserts that a non-empty
/// CGImage is produced at the expected device-class size. This avoids a
/// third-party snapshot dependency while still failing loudly if any view
/// regresses to a non-rendering state (e.g. layout cycle, infinite frame,
/// missing required environment).
@MainActor
final class HantaAtlasSnapshotTests: XCTestCase {
    private let canvas = CGSize(width: 393, height: 852) // iPhone 15-ish

    func testTodayRenders() throws {
        let view = NavigationStack {
            DashboardView(
                repository: SurveillanceRepository(),
                preferences: LocalPreferences()
            )
        }
        try assertRenders(view, name: "today")
    }

    func testMapRenders() throws {
        let view = NavigationStack {
            WorldMapView(
                repository: SurveillanceRepository(),
                preferences: LocalPreferences()
            )
        }
        try assertRenders(view, name: "map")
    }

    func testFeedRenders() throws {
        let view = NavigationStack {
            OutbreakFeedView(
                repository: SurveillanceRepository(),
                preferences: LocalPreferences()
            )
        }
        try assertRenders(view, name: "feed")
    }

    func testSavedRenders() throws {
        let view = NavigationStack {
            WatchlistView(
                repository: SurveillanceRepository(),
                preferences: LocalPreferences()
            )
        }
        try assertRenders(view, name: "saved")
    }

    func testGuideRenders() throws {
        let view = NavigationStack {
            GuideView(
                repository: SurveillanceRepository(),
                preferences: LocalPreferences()
            )
        }
        try assertRenders(view, name: "guide")
    }

    func testCountryDetailRenders() throws {
        let view = NavigationStack {
            CountryDetailView(
                country: Fixtures.countries[1],
                preferences: LocalPreferences()
            )
        }
        try assertRenders(view, name: "country-detail")
    }

    // MARK: -

    private func assertRenders<V: View>(_ view: V, name: String) throws {
        let host = view.frame(width: canvas.width, height: canvas.height)
        let renderer = ImageRenderer(content: host)
        renderer.scale = 1
        guard let image = renderer.cgImage else {
            return XCTFail("ImageRenderer produced no CGImage for \(name)")
        }
        XCTAssertGreaterThan(image.width, Int(canvas.width * 0.5), "\(name) is unexpectedly narrow")
        XCTAssertGreaterThan(image.height, Int(canvas.height * 0.5), "\(name) is unexpectedly short")
        XCTAssertGreaterThan(image.bytesPerRow, 0, "\(name) has empty bytesPerRow")
    }
}
