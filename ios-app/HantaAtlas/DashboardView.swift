import SwiftUI

/// Today tab — bento-style dashboard.
///
/// Design language inspired by health/fitness dashboards: mixed-size cards in
/// a grid that breathes, generous spacing, monospaced numerics, tiny uppercase
/// labels, single floating action button. Each card stands on its own —
/// nothing is jammed against its neighbour.
///
/// Visual rules:
///  - Card spacing: 14pt between cards
///  - Card padding: 18pt internal (16pt for tighter tiles)
///  - Card radius: 24pt (Theme.Radius.card+)
///  - Hero number: SF Pro Rounded, .heavy, ~44pt, `.monospacedDigit()`
///  - Tile number: SF Pro Rounded, .heavy, ~28pt
///  - Eyebrow label: caption2 .heavy, tracking 1.0, uppercased
struct DashboardView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences

    @State private var showProfile: Bool = false
    /// Drives the Following card's inline expand-with-search affordance.
    /// When true the card swaps its 5-row preview for a search field + a
    /// full followed list + an "add from catalogue" results list, all
    /// within the same card body — no sheet, no navigation push.
    @State private var followingExpanded: Bool = false
    /// Query string used by the expanded Following card. Bound to a single
    /// TextField; resets when the card collapses.
    @State private var addCountryQuery: String = ""
    @State private var showSourcePrompt: Bool = false
    @State private var sourcePromptDismissed: Bool = false
    @State private var skeletonPhase: CGFloat = -1

    /// Countries the user has explicitly saved. Reads `savedCountryCodes`
    /// directly rather than going through `preferences.isFollowing(_:)` —
    /// `isFollowing` returns true for every country when `trackAllCountries`
    /// is on (by design — the rest of the app uses that semantics to
    /// include every country in feed / map filters), which used to make
    /// this card dump the entire alphabetical catalogue into the Following
    /// section of Today (Afghanistan, Åland Islands, Albania, …). The
    /// Following list is meant to be the user's curated picks, so it
    /// reads only from `savedCountryCodes`.
    private var savedCountries: [CountrySnapshot] {
        let saved = Set(preferences.savedCountryCodes.map { $0.uppercased() })
        guard !saved.isEmpty else { return [] }
        return repository.countries().filter { saved.contains($0.isoCode.uppercased()) }
    }

    private var totalCountryCount: Int {
        repository.countries().count
    }

    private var trackedCountryCount: Int {
        preferences.trackedCountryCount(totalAvailable: totalCountryCount)
    }

    private var dashboardSignals: [Signal] {
        repository.signals.filter { preferences.shouldShowCountry($0.countryISO) }
    }

    private var summary: AppSummary { repository.summary() }

    private var isInitialLoading: Bool {
        repository.isRefreshing && (!repository.hasLoadedFromNetwork || repository.isSwitchingMode)
    }

    private var activeCountriesCount: Int {
        Set(dashboardSignals.compactMap { $0.countryISO?.uppercased() }).count
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerStrip
                    dashboardContent
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 100)
                // Owns the skeleton↔content fade for both first load and
                // mode switches (`isInitialLoading` covers
                // !hasLoadedFromNetwork and isSwitchingMode). Scoped to this
                // VStack on purpose — a container-wide animation on the parent
                // TabView animated its internal horizontal tab layout and left
                // the page translated/clipped (see ContentView note).
                .animation(.easeOut(duration: 0.28), value: isInitialLoading)
            }
            .scrollIndicators(.hidden)

            // Floating action — quick jump to map (matches the reference's
            // single-button affordance).
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    NavigationLink {
                        SourceTransparencyView(diseaseMode: preferences.selectedDiseaseMode)
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(.plain)
                    .background(Circle().fill(Theme.graphite))
                    .shadow(color: Theme.graphite.opacity(0.30), radius: 12, y: 6)
                    .padding(.trailing, 18)
                    .padding(.bottom, 96)  // clear floating tab bar
                    .accessibilityLabel("About the data")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await repository.refresh(preferences: preferences) }
        .task(id: isInitialLoading) {
            if isInitialLoading {
                skeletonPhase = -1
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    skeletonPhase = 1
                }
            }
        }
        .task(id: repository.hasLoadedFromNetwork) {
            guard repository.hasLoadedFromNetwork, !sourcePromptDismissed else { return }
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, !isInitialLoading else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                showSourcePrompt = true
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if isInitialLoading {
            dashboardSkeletonContent
                .transition(.opacity)
        } else {
            if showSourcePrompt {
                sourceReviewPrompt
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            overviewSection
            activitySection
            latestAndFollowingSection
            // Three-way branch (was two-way). The previous logic was:
            //   savedCountries.empty ? CTA : followingCard
            // which conflated two unrelated states because
            // `isFollowing` returns true for everything when
            // `trackAllCountries` is on, so the alphabetical
            // catalogue head poured into the Following list. Branching
            // explicitly on trackAllCountries gives that mode its own honest
            // card, and the "no countries tracked" CTA only fires
            // when there's genuinely nothing being followed.
            if preferences.trackAllCountries {
                trackingAllCountriesCard
            } else if savedCountries.isEmpty {
                trackCountriesCTACard
            } else {
                followingCard
            }
        }
    }

    private var sourceReviewPrompt: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.terracotta)
                .frame(width: 36, height: 36)
                .background(Theme.terracotta.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Review data sources?")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("See how official alerts, public reports, and confidence labels are sourced before reading the dashboard.")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        SourceTransparencyView(diseaseMode: preferences.selectedDiseaseMode)
                            .onAppear {
                                sourcePromptDismissed = true
                                showSourcePrompt = false
                            }
                    } label: {
                        Text("View sources")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.terracotta, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        sourcePromptDismissed = true
                        withAnimation(.easeOut(duration: 0.20)) {
                            showSourcePrompt = false
                        }
                    } label: {
                        Text("Not now")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.graphiteSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.bone.opacity(0.70), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var dashboardSkeletonContent: some View {
        VStack(spacing: 14) {
            skeletonHeroActivityCard
            HStack(spacing: 14) {
                skeletonTile(lines: [64, 120])
                skeletonTile(lines: [44, 92])
            }
        }

        VStack(spacing: 14) {
            skeletonActivityGridCard
            HStack(spacing: 14) {
                skeletonTile(lines: [40, 118])
                skeletonTile(lines: [54, 136])
            }
        }

        skeletonLatestAlertCard
        skeletonFollowingCard
    }

    private var skeletonHeroActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SkeletonBlock(width: 192, height: 14, radius: 7, phase: skeletonPhase)
                Spacer()
                SkeletonBlock(width: 78, height: 24, radius: 12, phase: skeletonPhase)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SkeletonBlock(width: 178, height: 58, radius: 12, phase: skeletonPhase)
                SkeletonBlock(width: 72, height: 22, radius: 8, phase: skeletonPhase)
                Spacer()
            }

            skeletonSparkline
                .frame(height: 42)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
        .accessibilityHidden(true)
    }

    private func skeletonTile(lines: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 96, height: 12, radius: 6, phase: skeletonPhase)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, width in
                    SkeletonBlock(width: width, height: idx == 0 ? 34 : 16, radius: 8, phase: skeletonPhase)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        .accessibilityHidden(true)
    }

    private var skeletonActivityGridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SkeletonBlock(width: 148, height: 14, radius: 7, phase: skeletonPhase)
                Spacer()
                SkeletonBlock(width: 112, height: 12, radius: 6, phase: skeletonPhase)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<30, id: \.self) { idx in
                    let opacity = 0.55 + (Double(idx % 6) * 0.04)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.bone.opacity(opacity))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            SkeletonBlock(width: nil, height: nil, radius: 5, phase: skeletonPhase)
                        }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
        .accessibilityHidden(true)
    }

    private var skeletonLatestAlertCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(width: 174, height: 14, radius: 7, phase: skeletonPhase)
            HStack(alignment: .top, spacing: 14) {
                SkeletonBlock(width: 56, height: 56, radius: 16, phase: skeletonPhase)
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(width: 104, height: 16, radius: 8, phase: skeletonPhase)
                    SkeletonBlock(width: nil, height: 22, radius: 8, phase: skeletonPhase)
                    SkeletonBlock(width: nil, height: 22, radius: 8, phase: skeletonPhase)
                    SkeletonBlock(width: 198, height: 14, radius: 7, phase: skeletonPhase)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
        .accessibilityHidden(true)
    }

    private var skeletonFollowingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SkeletonBlock(width: 112, height: 14, radius: 7, phase: skeletonPhase)
                Spacer()
                SkeletonBlock(width: 82, height: 24, radius: 12, phase: skeletonPhase)
            }
            ForEach(0..<2, id: \.self) { idx in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 28, height: 22, radius: 5, phase: skeletonPhase)
                    VStack(alignment: .leading, spacing: 7) {
                        SkeletonBlock(width: idx == 0 ? 122 : 136, height: 18, radius: 8, phase: skeletonPhase)
                        SkeletonBlock(width: 96, height: 12, radius: 6, phase: skeletonPhase)
                    }
                    Spacer()
                    SkeletonBlock(width: 96, height: 26, radius: 13, phase: skeletonPhase)
                }
                if idx == 0 {
                    Divider().overlay(Theme.stroke).padding(.leading, 40)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
        .accessibilityHidden(true)
    }

    private var skeletonSparkline: some View {
        GeometryReader { geo in
            let heights: [CGFloat] = [3, 3, 3, 3, 4, 4, 5, 4, 6, 5, 5, 6, 7, 6, 7, 8, 7, 9, 11, 10, 13, 16, 22, 34, 26, 18, 10, 6, 4, 3]
            let totalSpacing = CGFloat(heights.count - 1) * 3
            let barWidth = max(2, (geo.size.width - totalSpacing) / CGFloat(heights.count))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                    SkeletonBlock(width: barWidth, height: height, radius: barWidth / 2, phase: skeletonPhase)
                }
            }
        }
    }

    // MARK: - Header strip (title + profile entry)

    private var headerStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(Theme.Fonts.pageTitle)
                        .foregroundStyle(Theme.graphite)
                    Text("\(preferences.selectedDiseaseMode.title) · last checked \(updatedAgo)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                Spacer()
                Button { AuthGate.shared.require { showProfile = true } } label: {
                    avatarPip
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")
                .sheet(isPresented: $showProfile) {
                    ProfileView(preferences: preferences)
                }
            }
            DiseaseModeSwitcher(preferences: preferences)
        }
        .padding(.bottom, 4)
    }

    /// Header avatar in the Today tab. Shows the signed-in user's initials
    /// monogram (Sign in with Apple doesn't expose the Apple ID photo, so a
    /// monogram is the avatar) and falls back to a neutral silhouette when
    /// signed out — see `AccountAvatarView`.
    private var avatarPip: some View {
        AccountAvatarView(size: 42)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    // MARK: - Hero card — big 30-day activity number with sparkline

    private var overviewSection: some View {
        VStack(spacing: 14) {
            heroActivityCard
            HStack(spacing: 14) {
                activeCountriesTile
                alertsTile
            }
        }
    }

    private var activitySection: some View {
        VStack(spacing: 14) {
            activityGridCard
            HStack(spacing: 14) {
                savedTile
                lastCheckTile
            }
        }
    }

    @ViewBuilder
    private var latestAndFollowingSection: some View {
        latestAlertCard
    }

    private var heroActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                eyebrow("Global activity · last 30 days")
                Spacer()
                trendChip
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(summary.officialAlertCount + dashboardSignals.count)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.graphite)
                    .minimumScaleFactor(0.7)
                Text("signals")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Spacer()
            }

            sparkline
                .frame(height: 42)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
    }

    private var trendChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.right")
                .font(.caption2.weight(.heavy))
            Text("\(activeCountriesCount) active")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Theme.terracotta, in: Capsule())
    }

    private var sparkline: some View {
        GeometryReader { geo in
            let bars = sparklineData
            let maxV = max(1, bars.max() ?? 1)
            let barCount = bars.count
            let totalSpacing = CGFloat(barCount - 1) * 3
            let barWidth = max(2, (geo.size.width - totalSpacing) / CGFloat(barCount))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(bars.enumerated()), id: \.offset) { idx, value in
                    Capsule()
                        .fill(barTint(forIndex: idx))
                        .frame(width: barWidth,
                               height: max(3, CGFloat(value) / CGFloat(maxV) * geo.size.height))
                }
            }
        }
    }

    private func barTint(forIndex idx: Int) -> Color {
        // Today highlighted; older days fade.
        let isToday = idx == sparklineData.count - 1
        if isToday { return Theme.terracotta }
        let progress = Double(idx) / Double(max(1, sparklineData.count - 1))
        return Theme.terracotta.opacity(0.20 + 0.55 * progress)
    }

    // MARK: - Tiles

    private var activeCountriesTile: some View {
        bentoTile(eyebrow: "Active") {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(activeCountriesCount)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.graphite)
                Text("countries with recent signals")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.graphiteSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var alertsTile: some View {
        bentoTile(eyebrow: "Official alerts") {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summary.officialAlertCount)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.graphite)
                    Circle()
                        .fill(Theme.terracotta)
                        .frame(width: 7, height: 7)
                        .padding(.bottom, 6)
                }
                Text("active in feed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
        }
    }

    private var savedTile: some View {
        // Tappable entry point to the country-tracking flow. Previously the
        // tile rendered as a static stat — there was no surface on Today
        // that let users actually *add* a country, so the only paths in
        // were buried (the Alerts tab's "Edit watchlist" link or
        // right-swiping a card in the Catch-up deck). NavigationLink pushes
        // WatchlistView, which has the full search + add-country picker.
        NavigationLink {
            WatchlistView(repository: repository, preferences: preferences)
        } label: {
            bentoTile(eyebrow: "Saved") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(trackedCountryCount)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.graphite)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.graphiteSecondary)
                    }
                    Text(savedTileSubtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.graphiteSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            trackedCountryCount == 0
                ? "No countries saved. Tap to add."
                : "\(trackedCountryCount) countries tracked. Tap to manage."
        )
    }

    private var savedTileSubtitle: String {
        if preferences.trackAllCountries { return "all countries tracked" }
        return preferences.savedCountryCodes.isEmpty ? "tap to add countries" : "countries followed"
    }

    private var lastCheckTile: some View {
        bentoTile(eyebrow: "Last check") {
            VStack(alignment: .leading, spacing: 4) {
                Text(updatedAgoCompact)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.graphite)
                Text("auto-refresh on open")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
        }
    }

    // MARK: - Activity grid (30-day dot matrix)

    private var activityGridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                eyebrow("Activity · 30 days")
                Spacer()
                legendDot(color: Theme.terracotta, label: "high")
                legendDot(color: Theme.amber, label: "med")
                legendDot(color: Theme.olive, label: "low")
            }

            // 30 cells, 6 columns × 5 rows. Today is bottom-right.
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(sparklineData.enumerated()), id: \.offset) { idx, value in
                    activityCell(count: value, isToday: idx == sparklineData.count - 1)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
    }

    private func activityCell(count: Int, isToday: Bool) -> some View {
        let cellTint: Color = {
            if count == 0 { return Theme.bone }
            if count >= 8  { return Theme.terracotta }
            if count >= 4  { return Theme.amber }
            return Theme.olive
        }()
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(cellTint)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Theme.graphite, lineWidth: 1.5)
                }
            }
            .accessibilityHidden(true)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
        }
    }

    // MARK: - Latest alert (full-width, live)

    /// The most recent live signal in scope, preferring an official-source item
    /// so the "Latest official alert" framing stays honest, falling back to the
    /// latest signal of any source. Previously this card was bound to the
    /// fixture-backed `/v1/feed` (always stale — `repository.alerts()` never
    /// updates in prod) and, worse, every tap routed to the static
    /// source-methodology page instead of the post itself.
    private var latestOfficialSignal: Signal? {
        let scoped = dashboardSignals.sorted { $0.publishedAt > $1.publishedAt }
        return scoped.first(where: { $0.isOfficialSource }) ?? scoped.first
    }

    @ViewBuilder
    private var latestAlertCard: some View {
        if let signal = latestOfficialSignal {
            VStack(alignment: .leading, spacing: 14) {
                eyebrow(signal.isOfficialSource ? "Latest official alert" : "Latest signal")
                NavigationLink {
                    SignalArtifactView(signal: signal)
                } label: {
                    SignalLiveRow(signal: signal, isFirst: true)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
        }
    }

    // MARK: - Following list

    private var followingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                eyebrow("Following · \(savedCountries.count)")
                Spacer()
                expandToggleButton
                manageButton
            }
            if followingExpanded {
                expandedFollowingContent
            } else {
                collapsedFollowingList
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: followingExpanded)
    }

    /// Default tile presentation: up to five followed countries, each a
    /// `NavigationLink` to its detail screen. Matches the layout shipped
    /// before this commit, but only renders when the card is collapsed.
    @ViewBuilder
    private var collapsedFollowingList: some View {
        VStack(spacing: 0) {
            ForEach(Array(savedCountries.prefix(5).enumerated()), id: \.element.id) { idx, country in
                NavigationLink {
                    CountryDetailView(country: country, preferences: preferences)
                } label: {
                    followingRow(country)
                }
                .buttonStyle(.plain)
                if idx < min(savedCountries.count, 5) - 1 {
                    Divider().overlay(Theme.stroke).padding(.leading, 38)
                }
            }
        }
    }

    /// Expanded presentation: search field + the user's full followed list
    /// + an "Add" section that surfaces matching catalogue entries the user
    /// hasn't added yet. Tap a saved row to drill into detail, tap a
    /// catalogue row's `+` to add it inline. All within this card — no
    /// sheet, no nav push.
    private var expandedFollowingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            searchField
            if savedCountries.isEmpty {
                Text("No countries saved yet — search above to add one.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.graphiteSecondary)
                    .padding(.top, 2)
            } else {
                expandedSavedSection
            }
            expandedAddSection
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
            TextField("Search countries to add", text: $addCountryQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.subheadline)
                .foregroundStyle(Theme.graphite)
            if !addCountryQuery.isEmpty {
                Button {
                    addCountryQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.graphiteSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Theme.bone.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var expandedSavedSection: some View {
        let visible = expandedSavedMatches
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                eyebrow("Tracking")
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { idx, country in
                        NavigationLink {
                            CountryDetailView(country: country, preferences: preferences)
                        } label: {
                            HStack {
                                followingRow(country)
                                Button {
                                    AuthGate.shared.require { preferences.toggleSaved(country.isoCode) }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.terracotta)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
                                .accessibilityLabel("Unfollow \(country.countryName)")
                            }
                        }
                        .buttonStyle(.plain)
                        if idx < visible.count - 1 {
                            Divider().overlay(Theme.stroke).padding(.leading, 38)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var expandedAddSection: some View {
        let matches = expandedAddMatches
        if !addCountryQuery.isEmpty && !matches.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                eyebrow("Add")
                VStack(spacing: 0) {
                    ForEach(Array(matches.prefix(8).enumerated()), id: \.element.id) { idx, country in
                        Button {
                            AuthGate.shared.require { preferences.toggleSaved(country.isoCode) }
                        } label: {
                            HStack(spacing: 12) {
                                Text(flagEmoji(for: country.isoCode))
                                    .font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(country.countryName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.graphite)
                                    Text(country.regionName)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.graphiteSecondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.olive)
                                    .accessibilityLabel("Follow \(country.countryName)")
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx < min(matches.count, 8) - 1 {
                            Divider().overlay(Theme.stroke).padding(.leading, 38)
                        }
                    }
                }
            }
        } else if !addCountryQuery.isEmpty {
            // No catalogue matches at all (typo or ultra-specific query).
            Text("No countries match \"\(addCountryQuery)\".")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.graphiteSecondary)
                .padding(.top, 2)
        }
    }

    /// Saved countries filtered by the inline query.
    private var expandedSavedMatches: [CountrySnapshot] {
        guard !addCountryQuery.isEmpty else { return savedCountries }
        let q = addCountryQuery
        return savedCountries.filter {
            $0.countryName.localizedCaseInsensitiveContains(q)
                || $0.isoCode.localizedCaseInsensitiveContains(q)
        }
    }

    /// Catalogue countries matching the query, excluding ones already saved.
    private var expandedAddMatches: [CountrySnapshot] {
        guard !addCountryQuery.isEmpty else { return [] }
        let saved = Set(preferences.savedCountryCodes.map { $0.uppercased() })
        let q = addCountryQuery
        return repository.countries()
            .filter { !saved.contains($0.isoCode.uppercased()) }
            .filter {
                $0.countryName.localizedCaseInsensitiveContains(q)
                    || $0.isoCode.localizedCaseInsensitiveContains(q)
            }
            .sorted { $0.countryName.localizedCaseInsensitiveCompare($1.countryName) == .orderedAscending }
    }

    private var expandToggleButton: some View {
        Button {
            followingExpanded.toggle()
            if !followingExpanded { addCountryQuery = "" }
        } label: {
            Image(systemName: followingExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.graphite)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.bone.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(followingExpanded ? "Collapse Following" : "Expand Following to search and add")
    }

    /// "Manage" link → WatchlistView. Kept alongside the inline expand for
    /// users who prefer the full-screen flow (bulk edit, region grouping,
    /// etc.). The inline expand is the quick-edit affordance.
    private var manageButton: some View {
        NavigationLink {
            WatchlistView(repository: repository, preferences: preferences)
        } label: {
            HStack(spacing: 4) {
                Text("Manage")
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(Theme.terracotta)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.terracotta.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manage tracked countries")
    }

    /// Shown instead of `followingCard` when `preferences.trackAllCountries`
    /// is enabled. Previously the followingCard rendered the alphabetical
    /// catalogue head because `isFollowing` returns true for everything in
    /// trackAll mode. That list (Afghanistan, Åland Islands, Albania, …)
    /// wasn't actionable and confused users — it looked like an explicit
    /// follow list that they had no memory of curating.
    ///
    /// In trackAll mode the Following section has no curated content to
    /// show, so this card is a single-purpose surface: confirm the mode
    /// is on, offer the count, and provide a one-tap exit back to selected
    /// mode plus the existing "Manage" path for fine-grained edits.
    private var trackingAllCountriesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                    .frame(width: 36, height: 36)
                    .background(Theme.terracotta.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tracking all \(totalCountryCount) countries")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("Feed, alerts, and map are unfiltered. Switch to selected countries to curate this list and get focused alerts.")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button {
                    AuthGate.shared.require { preferences.setTrackAllCountries(false) }
                } label: {
                    Text("Switch to selected")
                        .font(.caption.weight(.heavy))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.terracotta, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Stop tracking every country and pick specific ones")
                NavigationLink {
                    WatchlistView(repository: repository, preferences: preferences)
                } label: {
                    HStack(spacing: 4) {
                        Text("Manage")
                            .font(.caption.weight(.heavy))
                            .tracking(0.4)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.heavy))
                    }
                    .foregroundStyle(Theme.terracotta)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.terracotta.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 4)
    }

    /// Empty-state card shown on Today when the user has zero saved
    /// countries. Replaces the previously-blank slot below the activity
    /// grid with an explicit invitation into the tracking feature — the
    /// motivating fix for "there is NO OPTION for users to store and save
    /// countries from Today".
    private var trackCountriesCTACard: some View {
        NavigationLink {
            WatchlistView(repository: repository, preferences: preferences)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bookmark.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                    .frame(width: 36, height: 36)
                    .background(Theme.terracotta.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track countries that matter to you")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                        .multilineTextAlignment(.leading)
                    Text("Pin selected countries or track all countries to scope the map, feed, catch-up deck, and alerts.")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add countries to track. Opens watchlist.")
    }

    private func followingRow(_ country: CountrySnapshot) -> some View {
        HStack(spacing: 12) {
            Text(flagEmoji(for: country.isoCode))
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 1) {
                Text(country.countryName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Text(country.regionName)
                    .font(.caption2)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            Spacer()
            ConfidenceBadge(level: country.confidenceLevel, compact: true)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.graphiteSecondary.opacity(0.6))
        }
        .padding(.vertical, 10)
    }

    // MARK: - About

    private var aboutCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.graphite)
                .frame(width: 36, height: 36)
                .background(Theme.bone, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("About the data")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("Every metric retains its source, confidence label, dates, and known limitations. Informational only — not for emergency use.")
                    .font(.caption)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    private func bentoTile<Content: View>(
        eyebrow text: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            self.eyebrow(text)
            content()
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(1.0)
            .foregroundStyle(Theme.graphiteSecondary)
    }

    private func flagEmoji(for iso: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in iso.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) { s.append(String(scalar)) }
        }
        return s.isEmpty ? "🌍" : s
    }

    private var updatedAgo: String {
        let mins = max(0, Int(Date().timeIntervalSince(summary.checkedAt) / 60))
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        if mins < 60 * 24 { return "\(mins / 60)h ago" }
        return AppDateFormat.shortMonth.string(from: summary.checkedAt)
    }

    private var updatedAgoCompact: String {
        let mins = max(0, Int(Date().timeIntervalSince(summary.checkedAt) / 60))
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m" }
        if mins < 60 * 24 { return "\(mins / 60)h" }
        return "\(mins / 1440)d"
    }

    // MARK: - Sparkline / activity-grid data

    /// Counts of signals per day for the last 30 days (oldest → newest, today last).
    private var sparklineData: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var bucket: [Date: Int] = [:]
        for s in dashboardSignals {
            let day = cal.startOfDay(for: s.publishedAt)
            bucket[day, default: 0] += 1
        }
        return (0..<30).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return bucket[day] ?? 0
        }
    }
}

private struct SkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat?
    let radius: CGFloat
    let phase: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.bone.opacity(0.72))
            .frame(width: width, height: height)
            .overlay {
                GeometryReader { proxy in
                    let travel = proxy.size.width + 140
                    LinearGradient(
                        colors: [
                            .white.opacity(0.00),
                            .white.opacity(0.34),
                            .white.opacity(0.00)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(70, proxy.size.width * 0.42))
                    .rotationEffect(.degrees(8))
                    .offset(x: (phase * travel) - 70)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .accessibilityHidden(true)
    }
}

#Preview("Today — light") {
    NavigationStack {
        DashboardView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
}

#Preview("Today — dark") {
    NavigationStack {
        DashboardView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
    .preferredColorScheme(.dark)
}
