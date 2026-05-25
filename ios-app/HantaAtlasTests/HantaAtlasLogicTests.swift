import XCTest
@testable import HantaAtlas

@MainActor
final class HantaAtlasLogicTests: XCTestCase {
    func testConfidenceLabelsAreUserReadable() {
        XCTAssertEqual(ConfidenceLevel.officialStructuredData.title, "Official structured data")
        XCTAssertEqual(ConfidenceLevel.noRecentPublicData.title, "No recent public data")
        XCTAssertTrue(ConfidenceLevel.officialAlert.explanation.contains("official"))
    }

    func testRepositoryReturnsArgentinaSeedDetail() {
        let repository = SurveillanceRepository()
        let country = repository.country(isoCode: "AR")
        XCTAssertEqual(country?.virusType, "Andes virus")
        XCTAssertEqual(country?.confidenceLevel, .officialAlert)
    }

    func testRepositoryExposesCompleteCountryCatalogue() {
        let repository = SurveillanceRepository()
        XCTAssertGreaterThan(repository.countries().count, 200)
        XCTAssertNotNil(repository.country(isoCode: "JP"))
        XCTAssertNotNil(repository.country(isoCode: "ZA"))
    }

    func testMapDefaultsToConfidenceMetric() {
        let preferences = LocalPreferences()
        XCTAssertNotNil(MapMetric(rawValue: preferences.lastSelectedMetric.rawValue))
    }

    func testTrackAllCountriesIncludesAnyISO() {
        let preferences = LocalPreferences()
        let previousSaved = preferences.savedCountryCodes
        let previousTrackAll = preferences.trackAllCountries
        defer {
            preferences.savedCountryCodes = previousSaved
            preferences.setTrackAllCountries(previousTrackAll)
        }

        preferences.savedCountryCodes = []
        preferences.setTrackAllCountries(true)

        XCTAssertTrue(preferences.isFollowing("JP"))
        XCTAssertTrue(preferences.shouldShowCountry("ZA", includeAllWhenEmpty: false))
    }
}
