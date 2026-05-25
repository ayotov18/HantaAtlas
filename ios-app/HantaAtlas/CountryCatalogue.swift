import Foundation

/// Complete country picker catalogue.
///
/// Surveillance snapshots are sparse by design: many countries have no recent
/// public hantavirus data. The product still has to let users track any country
/// before a signal appears there, so the picker cannot depend only on
/// `/v1/countries`. This catalogue supplies ISO-backed placeholder countries
/// and then overlays any real surveillance snapshots from the repository.
enum CountryCatalogue {
    private static let catalogueSource = Source(
        id: "country-catalogue",
        organisation: "Country catalogue",
        url: URL(string: "https://www.iso.org/iso-3166-country-codes.html")!
    )

    static func merged(with snapshots: [CountrySnapshot]) -> [CountrySnapshot] {
        let snapshotByISO = snapshots.reduce(into: [String: CountrySnapshot]()) { result, snapshot in
            result[snapshot.isoCode.uppercased()] = snapshot
        }
        let catalogue = allCountries.map { snapshotByISO[$0.isoCode.uppercased()] ?? $0 }
        let catalogueISOs = Set(catalogue.map { $0.isoCode.uppercased() })
        let extraSnapshots = snapshots.filter { !catalogueISOs.contains($0.isoCode.uppercased()) }
        return (catalogue + extraSnapshots)
            .sorted {
                $0.countryName.localizedCaseInsensitiveCompare($1.countryName) == .orderedAscending
            }
    }

    private static let allCountries: [CountrySnapshot] = Locale.Region.isoRegions.compactMap { region in
        let rawCode = region.identifier
        let iso = rawCode.uppercased()
        guard iso.count == 2,
              iso.allSatisfy({ $0.isLetter }),
              let name = Locale.current.localizedString(forRegionCode: iso) else {
            return nil
        }

        return CountrySnapshot(
            id: "catalogue-\(iso)",
            isoCode: iso,
            countryName: name,
            regionName: "Country catalogue",
            cases: nil,
            deaths: nil,
            reportingPeriodLabel: "No recent public data",
            reportedAt: nil,
            publishedAt: nil,
            lastCheckedAt: Fixtures.checkedAt,
            source: catalogueSource,
            sourceUrl: catalogueSource.url,
            summary: "No recent public country-level hantavirus surveillance is cached for this country yet.",
            virusType: "Not specified",
            limitations: "No recent public data is not the same as zero cases. Public signals and official notices will be attached when available.",
            confidenceLevel: .noRecentPublicData,
            trend: []
        )
    }
}
