import SwiftUI

/// Saved tab. Default state is empty. The "add a country" affordance lives
/// directly on this page — no extra navigation. Once the user has saved
/// countries, the same picker collapses into a small "+ Add" button next to
/// the section header.
struct WatchlistView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var showInlinePicker: Bool = true  // open by default when empty
    @FocusState private var isSearchFocused: Bool

    private var allCountries: [CountrySnapshot] {
        repository.countries()
    }

    private var savedCountries: [CountrySnapshot] {
        allCountries.filter { preferences.savedCountryCodes.contains($0.isoCode.uppercased()) }
    }

    private var availableCountries: [CountrySnapshot] {
        guard !preferences.trackAllCountries else { return [] }
        return allCountries.filter { !preferences.savedCountryCodes.contains($0.isoCode.uppercased()) }
    }

    private var filteredAvailable: [CountrySnapshot] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return availableCountries }
        return availableCountries.filter { c in
            c.countryName.localizedCaseInsensitiveContains(q)
                || c.regionName.localizedCaseInsensitiveContains(q)
                || c.isoCode.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    ScreenHeader(
                        title: "Saved",
                        subtitle: preferences.trackAllCountries
                            ? "Tracking all \(allCountries.count) countries"
                            : "Countries you follow"
                    ) {
                        // Itinerary toggles are managed inline on this same
                        // screen (the notificationCard below contains the
                        // Itinerary-updates row), so the only meaningful
                        // overflow action is the OS-level notification
                        // settings deep-link. Both buttons used to be empty
                        // closures — opening nothing on tap.
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.graphite)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Open notification settings")
                    }

                    DiseaseModeSwitcher(preferences: preferences)

                    trackingModeCard

                    if preferences.trackAllCountries {
                        notificationCard
                        allCountriesTrackedCard
                    } else if savedCountries.isEmpty {
                        emptyHero
                        inlinePicker
                    } else {
                        notificationCard
                        savedCountriesSection
                        if showInlinePicker {
                            inlinePicker
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, 56)
                .padding(.bottom, Theme.Space.huge)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            LiquidGlassBackButton { dismiss() }
                .padding(.leading, Theme.Space.l)
                .padding(.top, 14)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.25), value: savedCountries.count)
        .animation(.easeOut(duration: 0.25), value: showInlinePicker)
    }

    // MARK: - Empty hero

    private var emptyHero: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.amber.opacity(0.4), Theme.terracotta.opacity(0.25)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 116, height: 116)
                Image(systemName: "bookmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Theme.terracotta)
            }
            .padding(.top, 4)

            Text("Follow a country")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.graphite)

            Text("Pick the places you care about. We'll surface their official notices first and (if you allow it) ping you when something changes.")
                .font(.callout)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Inline picker

    private var trackingModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToggleRow(
                symbolName: "globe.europe.africa.fill",
                tint: Theme.moss,
                title: "Track all countries",
                detail: "Map, feed, catch-up, and alerts include every \(preferences.selectedDiseaseMode.title) country in the catalogue.",
                isOn: Binding(
                    get: { preferences.trackAllCountries },
                    set: { newValue in AuthGate.shared.require { preferences.setTrackAllCountries(newValue) } }
                )
            )
            if !preferences.trackAllCountries {
                Text("\(savedCountries.count) selected · \(allCountries.count) available")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    private var allCountriesTrackedCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: "checkmark.seal.fill", tint: Theme.moss, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Every country is in scope")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("The map shows all country signals. You will be eligible for case-signal and 3+ news-signal alerts anywhere new activity appears.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 16)
    }

    private var inlinePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.graphiteSecondary)
                TextField("Search countries", text: $query)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isSearchFocused)
                    .onSubmit(handleSearchSubmit)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.softGrey)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.bone.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if filteredAvailable.isEmpty {
                EmptyStateCard(
                    title: query.isEmpty ? "Every country saved" : "No matches",
                    message: query.isEmpty
                        ? "You're already following every country we cover."
                        : "Try a different name or ISO code.",
                    symbolName: query.isEmpty ? "checkmark.seal" : "magnifyingglass"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredAvailable.prefix(query.isEmpty ? 8 : 30)) { country in
                        Button {
                            addCountry(country)
                        } label: {
                            AddCountryRow(country: country)
                        }
                        .buttonStyle(.plain)
                    }
                    if query.isEmpty && filteredAvailable.count > 8 {
                        Text("Search to see more")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.graphiteSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .offset(y: 8)))
    }

    private func addCountry(_ country: CountrySnapshot) {
        AuthGate.shared.require { preferences.toggleSaved(country.isoCode) }
        query = ""
        isSearchFocused = false
    }

    private func handleSearchSubmit() {
        let matches = Array(filteredAvailable.prefix(2))
        if matches.count == 1 {
            addCountry(matches[0])
        } else {
            isSearchFocused = false
        }
    }

    // MARK: - Notification card (only when something is saved)

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Alerts & updates")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ToggleRow(
                symbolName: "bell.fill",
                tint: Theme.terracotta,
                title: "Official notices",
                detail: "Get notified when a tracked country has a new official notice.",
                isOn: Binding(
                    get: { preferences.officialNoticeAlerts },
                    set: { preferences.officialNoticeAlerts = $0 }
                )
            )
            Divider().overlay(Theme.stroke).padding(.leading, 78)
            ToggleRow(
                symbolName: "person.crop.circle.badge.exclamationmark.fill",
                tint: Theme.terracotta,
                title: "Case signals",
                detail: "Notify when a case-type signal appears in a tracked country.",
                isOn: Binding(
                    get: { preferences.trackedCountryCaseAlerts },
                    set: { preferences.trackedCountryCaseAlerts = $0 }
                )
            )
            Divider().overlay(Theme.stroke).padding(.leading, 78)
            ToggleRow(
                symbolName: "newspaper.fill",
                tint: Theme.amber,
                title: "3+ news signals",
                detail: "Notify when a tracked country crosses more than three public signals.",
                isOn: Binding(
                    get: { preferences.trackedCountryNewsBurstAlerts },
                    set: { preferences.trackedCountryNewsBurstAlerts = $0 }
                )
            )
            Divider().overlay(Theme.stroke).padding(.leading, 78)
            ToggleRow(
                symbolName: "calendar",
                tint: Theme.olive,
                title: "Itinerary updates",
                detail: "Updates for your saved itineraries and routes.",
                isOn: Binding(
                    get: { preferences.itineraryAlerts },
                    set: { preferences.itineraryAlerts = $0 }
                )
            )
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    // MARK: - Saved list (only when something is saved)

    @ViewBuilder
    private var savedCountriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Saved countries")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Spacer()
                Text("\(savedCountries.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.bone.opacity(0.8), in: Capsule())
                Button {
                    showInlinePicker.toggle()
                } label: {
                    Image(systemName: showInlinePicker ? "minus" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Circle().fill(showInlinePicker ? Theme.softGrey : Theme.moss))
                .shadow(color: Theme.cardShadow, radius: 4, y: 2)
                .accessibilityLabel(Text(showInlinePicker ? "Hide picker" : "Add country"))
                .disabled(availableCountries.isEmpty && !showInlinePicker)
                .opacity(availableCountries.isEmpty && !showInlinePicker ? 0.45 : 1)
            }
            VStack(spacing: 10) {
                ForEach(savedCountries) { country in
                    SavedCountryRow(
                        country: country,
                        preferences: preferences
                    )
                }
            }
        }
    }
}

// MARK: - Rows

private struct AddCountryRow: View {
    let country: CountrySnapshot

    var body: some View {
        HStack(spacing: 14) {
            FlagBadge(isoCode: country.isoCode, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(country.countryName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Text(country.regionName)
                    .font(.caption)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            Spacer()
            ConfidenceBadge(level: country.confidenceLevel, compact: true)
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.moss)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 12)
    }
}

/// Saved country row — the unsave button is a SIBLING of the NavigationLink,
/// not nested inside it, because nesting a Button inside a NavigationLink
/// causes the link to swallow the inner tap. That was the bug: "the option
/// to remove countries was removed" — the bookmark button was visible but
/// taps fell through to the navigation push instead.
private struct SavedCountryRow: View {
    let country: CountrySnapshot
    let preferences: LocalPreferences

    var body: some View {
        HStack(spacing: 0) {
            // Tappable region pushes the country detail.
            NavigationLink {
                CountryDetailView(country: country, preferences: preferences)
            } label: {
                HStack(spacing: 14) {
                    FlagBadge(isoCode: country.isoCode, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.countryName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.graphite)
                        Text(country.regionName)
                            .font(.caption)
                            .foregroundStyle(Theme.graphiteSecondary)
                    }
                    Spacer()
                    ConfidenceBadge(level: country.confidenceLevel, compact: true)
                }
                .padding(.vertical, 12).padding(.leading, 12)
            }
            .buttonStyle(.plain)

            // Sibling button — NOT inside the NavigationLink. Receives its own taps.
            Button {
                AuthGate.shared.require { preferences.toggleSaved(country.isoCode) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.terracotta)
                    .frame(width: 34, height: 34)
                    .background(Theme.terracotta.opacity(0.12), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove \(country.countryName) from saved"))
            .padding(.trailing, 10)
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }
}

private struct ToggleRow: View {
    let symbolName: String
    let tint: Color
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemName: symbolName, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.terracotta)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview("Saved — empty") {
    NavigationStack {
        WatchlistView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
}

#Preview("Saved — dark") {
    NavigationStack {
        WatchlistView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
    .preferredColorScheme(.dark)
}

#Preview("Saved — XXXL text") {
    NavigationStack {
        WatchlistView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
