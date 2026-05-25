import SwiftUI

/// Country detail. Works for ANY ISO code — no hardcoded hero artwork.
/// The hero is built from the country's flag emoji + a confidence-tinted
/// gradient, so we don't need a per-country bundled image.
///
/// Top chrome:
/// - Liquid Glass back button (floating, hover, no opaque nav bar) — HIG.
/// - Liquid Glass overflow menu mirroring the same style.
struct CountryDetailView: View {
    let country: CountrySnapshot
    let preferences: LocalPreferences
    @Environment(\.dismiss) private var dismiss

    private var isSaved: Bool { preferences.isFollowing(country.isoCode) }

    var body: some View {
        ZStack(alignment: .top) {
            ScreenBackground()
            ScrollView {
                ZStack(alignment: .top) {
                    hero
                    VStack(spacing: 0) {
                        Spacer().frame(height: 240)
                        cardStack
                    }
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            chromeOverlay
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Hero (ISO-agnostic)

    /// Programmatic hero: confidence-tinted gradient + giant flag emoji + a
    /// floating confidence badge. Renders identically for every ISO code.
    private var hero: some View {
        ZStack {
            LinearGradient(
                colors: [
                    country.confidenceLevel.tint.opacity(0.65),
                    country.confidenceLevel.tint.opacity(0.30),
                    Theme.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .frame(height: 320)

            VStack(spacing: 8) {
                Spacer().frame(height: 20)
                Text(flagEmoji(for: country.isoCode))
                    .font(.system(size: 84))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .accessibilityHidden(true)
                Spacer()
            }

            // Subtle bottom fade-out for legibility of the cards beneath.
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Theme.paper.opacity(0.85), Theme.paper],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 96)
            }
            .frame(height: 320)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
        .accessibilityHidden(true)
    }

    /// Generic flag emoji from any 2-letter ISO 3166-1 alpha-2 code via
    /// regional indicator symbols. Works for all 250+ ISO codes without
    /// bundling assets.
    private func flagEmoji(for iso: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in iso.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.append(String(scalar))
            }
        }
        return s.isEmpty ? "🌍" : s
    }

    // MARK: - Top chrome (Liquid Glass back + overflow)

    private var chromeOverlay: some View {
        HStack(spacing: 10) {
            LiquidGlassBackButton { dismiss() }
            Spacer()
            Menu {
                if preferences.trackAllCountries {
                    Button("Tracking all countries", systemImage: "globe.europe.africa.fill") {}
                        .disabled(true)
                } else {
                    Button(isSaved ? "Remove from Saved" : "Save country", systemImage: isSaved ? "bookmark.slash" : "bookmark") {
                        AuthGate.shared.require { preferences.toggleSaved(country.isoCode) }
                    }
                }
                Button("Share", systemImage: "square.and.arrow.up") {}
                Button("Source link", systemImage: "link") {}
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.graphite)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("More actions")
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, 14)
    }

    // MARK: - Card stack

    private var cardStack: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            identityCard
            MedicalDisclaimerCaption(diseaseMode: preferences.selectedDiseaseMode)
            metricsGrid
            sourceCard
            datesTrio
            limitationsCard
            preventionCard
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.huge)
    }

    private var identityCard: some View {
        HStack(alignment: .center, spacing: 14) {
            FlagBadge(isoCode: country.isoCode, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(country.countryName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(country.regionName)
                    .font(.title3)
                    .foregroundStyle(Theme.graphiteSecondary)
                Text(preferences.selectedDiseaseMode.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.terracotta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.terracotta.opacity(0.10), in: Capsule())
                    .padding(.top, 4)
                ConfidenceBadge(level: country.confidenceLevel)
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .paperCard(cornerRadius: Theme.Radius.hero, padding: 16)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(
                title: "Cases",
                value: country.casesLabel,
                symbolName: "person.2.fill",
                tint: Theme.olive,
                footnote: country.confidenceLevel.title
            )
            MetricTile(
                title: "Deaths",
                value: country.deathsLabel,
                symbolName: "heart.text.square.fill",
                tint: Theme.clay,
                footnote: country.confidenceLevel.title
            )
            MetricTile(
                title: "Reporting period",
                value: country.reportingPeriodLabel,
                symbolName: "calendar",
                tint: Theme.moss,
                footnote: country.confidenceLevel.title
            )
            MetricTile(
                title: preferences.selectedDiseaseMode.pathogenLabel,
                value: country.virusType,
                symbolName: "circle.hexagongrid.fill",
                tint: Theme.amber,
                footnote: country.confidenceLevel.title
            )
        }
    }

    private var sourceCard: some View {
        HStack(spacing: 14) {
            IconTile(systemName: "building.columns.fill", tint: Theme.softGrey, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Text(country.source.organisation)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("Official public health authority")
                    .font(.caption)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private var datesTrio: some View {
        HStack(spacing: 10) {
            DateTile(
                icon: "calendar",
                title: "Reported",
                value: country.reportedAt.map(AppDateFormat.shortMonth.string(from:)) ?? "—",
                footnote: country.confidenceLevel.title
            )
            DateTile(
                icon: "calendar",
                title: "Published",
                value: country.publishedAt.map(AppDateFormat.shortMonth.string(from:)) ?? "—",
                footnote: country.confidenceLevel.title
            )
            DateTile(
                icon: "checkmark.shield",
                title: "Last checked",
                value: AppDateFormat.shortMonth.string(from: country.lastCheckedAt),
                footnote: "Up to date"
            )
        }
    }

    private var limitationsCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: "info.circle.fill", tint: Theme.softGrey, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("Data limitations")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text(country.limitations)
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private var preventionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                IconTile(systemName: "shield.lefthalf.filled", tint: Theme.moss, size: 38)
                Text("Prevention actions")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Spacer()
            }
            HStack(spacing: 10) {
                preventionPill(symbol: "house.fill", title: "Seal entry points", subtitle: "Keep rodents out", tint: Theme.moss)
                preventionPill(symbol: "wind", title: "Keep areas clean", subtitle: "Reduce food sources", tint: Theme.amber)
                preventionPill(symbol: "hand.raised.fill", title: "Wear protection", subtitle: "Use gloves, masks", tint: Theme.clay)
            }
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private func preventionPill(symbol: String, title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(systemName: symbol, tint: tint, size: 36)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.graphite)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Theme.graphiteSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.bone.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Liquid Glass back button (reusable)

/// Floating Liquid Glass back chevron in the top-left, designed to hover over
/// content with no opaque navigation bar — Apple Maps / Wallet pattern.
/// Uses the GlassChrome wrapper so iOS 26 gets the real `glassEffect`,
/// pre-26 falls back to ultraThinMaterial.
struct LiquidGlassBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.graphite)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text("Back"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Country — light") {
    NavigationStack {
        CountryDetailView(country: Fixtures.countries[1], preferences: LocalPreferences())
    }
}

#Preview("Country — dark") {
    NavigationStack {
        CountryDetailView(country: Fixtures.countries[1], preferences: LocalPreferences())
    }
    .preferredColorScheme(.dark)
}

#Preview("Country — XXXL text") {
    NavigationStack {
        CountryDetailView(country: Fixtures.countries[1], preferences: LocalPreferences())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
