import SwiftUI

/// Live topic-tracker feed. Pulls real signals from `/v1/signals` (already
/// streaming the upstream JSON Feed). Each row is expandable into a
/// full-bleed "artifact" detail screen with the headline, source, time,
/// country, severity, optional summary, and an outbound link to the original.
///
/// Layout:
/// - Top: LIVE indicator (pulsing dot) + last-updated timestamp + filters
/// - Stream: signal rows, animated insertion as new ones arrive
/// - Tap a row: pushes SignalArtifactView (Liquid Glass back, full layout)
///
/// We deliberately keep this signal-centric (not country-centric) so it reads
/// like a topic tracker: "what's being officially signalled, ranked recent".
struct OutbreakFeedView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences
    /// Forwarded down to `SwipeFeedView`. When the user catches up on every
    /// signal, the swipe deck calls this so the host can dismiss the cover
    /// and switch the parent TabView back to Today (no dead-end empty state).
    var onCaughtUp: () -> Void = {}

    enum CountryScope: Hashable { case following, all }

    @State private var selectedCategory: SignalCategory? = nil
    @State private var selectedSeverity: AlertSeverity? = nil
    @State private var selectedCountry: String? = nil
    @State private var countryScope: CountryScope = .following
    @State private var query: String = ""

    /// Default to "following" — feed is auto-filtered to the user's saved
    /// countries when they have any. If they have none saved, falls back to
    /// All so the feed isn't empty on first launch.
    private var effectiveScope: CountryScope {
        if preferences.trackAllCountries { return .all }
        return preferences.savedCountryCodes.isEmpty ? .all : countryScope
    }

    private var streamed: [Signal] {
        var items = repository.signals

        // Auto-filter to saved countries when scope is "following".
        // `isFollowing` normalises casing on both sides — direct
        // `savedCountryCodes.contains(iso)` was silently dropping signals
        // whose `countryISO` differed in case from the user's saved entry.
        if effectiveScope == .following && !preferences.savedCountryCodes.isEmpty {
            items = items.filter { signal in
                preferences.shouldShowCountry(signal.countryISO, includeAllWhenEmpty: false)
            }
        }
        if let cat = selectedCategory { items = items.filter { $0.category == cat } }
        if let sev = selectedSeverity { items = items.filter { $0.severity == sev } }
        if let iso = selectedCountry { items = items.filter { $0.countryISO == iso } }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(q)
                    || ($0.summary?.localizedCaseInsensitiveContains(q) ?? false)
                    || $0.sourceBucket.localizedCaseInsensitiveContains(q)
            }
        }
        return items
    }

    private var savedCountries: [String] {
        Array(Set(repository.signals.compactMap { $0.countryISO })).sorted()
    }

    @State private var showSwipeDeck: Bool = false

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerStrip
                    statsCard
                    if !preferences.savedCountryCodes.isEmpty || preferences.trackAllCountries {
                        scopeBar
                    }
                    searchAndFiltersCard
                    feedSection
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .refreshable { await repository.refresh(preferences: preferences) }

            // Floating "Catch up" FAB — Tinder-style swipe deck for the topic
            // feed. Lives bottom-right above the floating tab bar.
            VStack { Spacer(); HStack {
                Spacer()
                Button { showSwipeDeck = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 16, weight: .heavy))
                        Text("Catch up")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.terracotta, in: Capsule())
                    .shadow(color: Theme.terracotta.opacity(0.30), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 96)
                .accessibilityLabel("Open catch-up swipe deck")
            } }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.30), value: streamed.map(\.id))
        .fullScreenCover(isPresented: $showSwipeDeck) {
            SwipeFeedView(
                repository: repository,
                preferences: preferences,
                onCaughtUp: {
                    // Dismiss first; tab switch fires from the parent. Order
                    // matters — letting fullScreenCover unmount the swipe
                    // deck cleanly before the tab transition runs avoids
                    // a brief frame where both screens fight for the foreground.
                    showSwipeDeck = false
                    onCaughtUp()
                }
            )
        }
    }

    // MARK: - Header (matches Today's bento style — title + LIVE badge)

    private var headerStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Feed")
                        .font(Theme.Fonts.pageTitle)
                        .foregroundStyle(Theme.graphite)
                    HStack(spacing: 6) {
                        liveBadge
                        Text("·").foregroundStyle(Theme.graphiteSecondary.opacity(0.5))
                        Text(updatedAgo)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.graphiteSecondary)
                    }
                }
                Spacer()
            }
            DiseaseModeSwitcher(preferences: preferences)
        }
        .padding(.bottom, 4)
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.red.opacity(0.30)).frame(width: 12, height: 12)
                Circle().fill(Color.red).frame(width: 6, height: 6)
            }
            Text("LIVE")
                .font(.caption.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(Theme.graphite)
            Text("· \(preferences.selectedDiseaseMode.shortTitle.lowercased())")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
        }
    }

    // MARK: - Scope picker (Following / All)

    private func scopeChip(_ scope: CountryScope, label: String, icon: String) -> some View {
        let selected = effectiveScope == scope
        return Button {
            countryScope = scope
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption.weight(.semibold))
                Text(label).font(.caption.weight(.bold))
            }
            .foregroundStyle(selected ? .white : Theme.graphite)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? Theme.terracotta : Theme.bone.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyStateTitle: String {
        if effectiveScope == .following && !preferences.savedCountryCodes.isEmpty {
            return "No signals from saved countries"
        }
        if preferences.trackAllCountries {
            return "No global signals match"
        }
        return "No signals match"
    }

    private var emptyStateMessage: String {
        if effectiveScope == .following && !preferences.savedCountryCodes.isEmpty {
            return "Switch to All countries to see the global stream, or save more countries from the Saved tab."
        }
        if preferences.trackAllCountries {
            return "Every country is in scope. Try a different filter, or wait for the next public signal."
        }
        return "Try a different filter, or wait — new signals come in continuously."
    }

    // MARK: - Stats card (3-column bento — same language as Today)

    private var statsCard: some View {
        HStack(spacing: 0) {
            statColumn(label: "Showing", value: "\(streamed.count)", tint: Theme.graphite)
            verticalDivider
            statColumn(label: "30d total", value: "\(repository.stats?.signalsLast30d ?? 0)", tint: Theme.terracotta)
            verticalDivider
            statColumn(label: "Active", value: "\(Set(streamed.compactMap { $0.countryISO?.uppercased() }).count)", tint: Theme.olive)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    private func statColumn(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(Theme.graphiteSecondary)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 30)
    }

    // MARK: - Scope bar (Following / All)

    private var scopeBar: some View {
        HStack(spacing: 8) {
            scopeChip(
                .following,
                label: preferences.trackAllCountries ? "All tracked" : "Following \(preferences.savedCountryCodes.count)",
                icon: preferences.trackAllCountries ? "globe.europe.africa.fill" : "bookmark.fill"
            )
            .disabled(preferences.trackAllCountries)
            .opacity(preferences.trackAllCountries ? 0.55 : 1)
            scopeChip(.all, label: "All countries", icon: "globe")
            Spacer()
        }
    }

    // MARK: - Search + filters card (one floating paper card)

    private var searchAndFiltersCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.graphiteSecondary)
                TextField("Search this topic", text: $query)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.softGrey)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.bone.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Flow-wrapping chip row — chips that don't fit on one line wrap
            // to the next so none get clipped at the right edge of the card.
            // Was previously a horizontal ScrollView whose last chip was being
            // cut in half by the parent paper card's bounds.
            FilterChipFlow(spacing: 8) {
                FilterChip(
                    title: selectedCategory?.title ?? "Category",
                    systemName: "square.stack.3d.up",
                    isSelected: selectedCategory != nil
                ) {
                    Button("All") { selectedCategory = nil }
                    ForEach(SignalCategory.allCases) { c in
                        Button(c.title) { selectedCategory = c }
                    }
                }
                FilterChip(
                    title: selectedSeverity?.title ?? "Severity",
                    systemName: "exclamationmark.triangle",
                    isSelected: selectedSeverity != nil
                ) {
                    Button("All") { selectedSeverity = nil }
                    ForEach(AlertSeverity.allCases) { s in
                        Button(s.title) { selectedSeverity = s }
                    }
                }
                FilterChip(
                    title: selectedCountry ?? "Country",
                    systemName: "flag",
                    isSelected: selectedCountry != nil
                ) {
                    Button("All") { selectedCountry = nil }
                    ForEach(savedCountries, id: \.self) { iso in
                        Button(iso) { selectedCountry = iso }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    // MARK: - Feed section

    @ViewBuilder
    private var feedSection: some View {
        if streamed.isEmpty {
            EmptyStateCard(
                title: emptyStateTitle,
                message: emptyStateMessage,
                symbolName: "tray"
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(Array(streamed.enumerated()), id: \.element.id) { index, signal in
                    NavigationLink {
                        SignalArtifactView(signal: signal)
                    } label: {
                        SignalLiveRow(signal: signal, isFirst: index == 0)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -8)),
                        removal: .opacity
                    ))
                }
            }
        }
    }

    // MARK: - Last updated

    private var updatedAgo: String {
        guard let updated = repository.stats?.updatedAt else { return "—" }
        let mins = max(0, Int(Date().timeIntervalSince(updated) / 60))
        if mins < 1 { return "updated just now" }
        if mins < 60 { return "updated \(mins)m ago" }
        return "updated \(mins / 60)h ago"
    }
}

// MARK: - Live row

/// Single live-signal row. Used by the Feed list and reused standalone
/// (`isFirst: true`) by the Today dashboard's latest-alert card.
struct SignalLiveRow: View {
    let signal: Signal
    let isFirst: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Circle()
                    .fill(severityTint)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(Theme.paper, lineWidth: 2))
                if !isFirst {
                    Capsule()
                        .fill(Theme.stroke)
                        .frame(width: 1.5)
                }
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(signal.sourceBucket)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.4)
                        .foregroundStyle(Theme.graphiteSecondary)
                    Text("·").foregroundStyle(Theme.softGrey)
                    Text(timeAgo(signal.publishedAt))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                    if let iso = signal.countryISO {
                        Text("·").foregroundStyle(Theme.softGrey)
                        Text(iso)
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.bone, in: Capsule())
                            .foregroundStyle(Theme.graphite)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                TranslatedSignalText(
                    signal.title,
                    sourceLanguage: signal.detectedLanguage,
                    font: .body.weight(.semibold),
                    lineLimit: 3
                )
                .foregroundStyle(Theme.graphite)
                if let summary = signal.summary, !summary.isEmpty {
                    TranslatedSignalText(
                        summary,
                        sourceLanguage: signal.detectedLanguage,
                        font: .subheadline,
                        lineLimit: 2
                    )
                    .foregroundStyle(Theme.graphiteSecondary)
                }
                HStack(spacing: 6) {
                    categoryPill(signal.category)
                    severityPill
                    if signal.isInForeignLanguage, let lang = signal.detectedLanguage {
                        languagePill(lang)
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        )
        .shadow(color: Theme.cardShadow, radius: 6, y: 2)
    }

    private var severityTint: Color {
        switch signal.severity {
        case .high: return Theme.terracotta
        case .medium: return Theme.amber
        case .low: return Theme.olive
        }
    }

    private func categoryPill(_ category: SignalCategory) -> some View {
        let (label, color) = pillColor(category)
        return Text(label)
            .font(.caption2.weight(.heavy))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
    }

    private func pillColor(_ category: SignalCategory) -> (String, Color) {
        switch category {
        case .local:    return ("LOCAL", Theme.terracotta)
        case .imported: return ("IMPORTED", Theme.amber)
        case .response: return ("RESPONSE", Color(red: 0.78, green: 0.62, blue: 0.30))
        case .media:    return ("MEDIA", Theme.softGrey)
        }
    }

    private var severityPill: some View {
        Text(signal.severity.title.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(0.4)
            .foregroundStyle(severityTint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(severityTint.opacity(0.13), in: Capsule())
    }

    private func languagePill(_ lang: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "globe").font(.system(size: 9, weight: .bold))
            Text(lang.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(0.4)
        }
        .foregroundStyle(Theme.graphiteSecondary)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Theme.bone, in: Capsule())
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = max(0, Int(Date().timeIntervalSince(date) / 60))
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m" }
        if mins < 60 * 24 { return "\(mins / 60)h" }
        return "\(mins / 1440)d"
    }
}

/// Wraps subviews onto multiple rows when they don't fit on one. Used by the
/// Feed filter row so the last chip can never be clipped by its parent card.
private struct FilterChipFlow: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) { self.spacing = spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(subviews: subviews, maxWidth: maxWidth)
        let totalHeight = rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        let totalWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: min(maxWidth, totalWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let projected = (rows.last?.width ?? 0) + (rows.last?.indices.isEmpty == true ? 0 : spacing) + size.width
            if rows.last!.indices.isEmpty || projected <= maxWidth {
                rows[rows.count - 1].indices.append(i)
                rows[rows.count - 1].width = projected
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            } else {
                var newRow = Row()
                newRow.indices.append(i)
                newRow.width = size.width
                newRow.height = size.height
                rows.append(newRow)
            }
            _ = i  // silence unused warning if any
        }
        return rows
    }
}

#Preview("Feed — light") {
    NavigationStack {
        OutbreakFeedView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
}

#Preview("Feed — dark") {
    NavigationStack {
        OutbreakFeedView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
    .preferredColorScheme(.dark)
}
