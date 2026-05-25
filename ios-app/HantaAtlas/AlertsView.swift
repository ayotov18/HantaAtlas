import SwiftUI

/// Alerts tab — focused per-country emergency-level widgets.
///
/// Stripped-down per user feedback: this page tracks ONLY the alert level of
/// each country the user follows. One widget per country. No discourse feed,
/// no sources card. The "Edit tracked countries" link replaces the standalone
/// Saved tab (4-tab navbar: Today / Map / Feed / Alerts).
///
/// Notification scheduling and preferences moved to a small in-page footer
/// menu so the page is purely about *what's happening in countries you care
/// about*. Tap any widget → push the full country detail.
struct AlertsView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences

    @State private var notificationService = NotificationService.shared
    @State private var showNotificationPrimer: Bool = false
    @State private var showSettings: Bool = false
    @State private var lastSyncedAt: Date = Date()

    /// The medical disclaimer is shown as a dismissible banner (mirrors the
    /// Today tab's "Review data sources?" prompt) rather than a permanent
    /// caption. `@State` resets on cold launch, so the disclosure re-appears
    /// every session — the same disclosure cadence as Today.
    @State private var disclaimerDismissed: Bool = false

    private var trackedClassifications: [CountryClassification] {
        // Show one widget per saved country, sorted by severity desc.
        // `isFollowing` is case-insensitive — a previous version compared
        // raw Set membership, which silently dropped widgets whenever
        // backend ISO codes differed in case from the user's saved entries.
        return repository.classifications()
            .filter { preferences.isFollowing($0.countryISO) }
            .sorted { $0.level.severity > $1.level.severity }
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerStrip
                    if !disclaimerDismissed {
                        disclaimerBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if notificationService.authorization == .notDetermined {
                        notificationPrimerCard
                    }
                    if preferences.savedCountryCodes.isEmpty && !preferences.trackAllCountries {
                        emptyTrackedCard
                    } else {
                        widgetGrid
                    }
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refreshAndNotify() }

            // Floating settings button bottom-right (replaces the inline
            // settings card so the page stays widget-focused).
            VStack { Spacer(); HStack {
                Spacer()
                Button { AuthGate.shared.require { showSettings = true } } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(Theme.graphite))
                .shadow(color: Theme.graphite.opacity(0.30), radius: 12, y: 6)
                .padding(.trailing, 18)
                .padding(.bottom, 96)
                .accessibilityLabel("Notification settings")
            } }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await refreshAndNotify() }
        .sheet(isPresented: $showNotificationPrimer) {
            NotificationPrimerSheet(
                onAllow: {
                    Task {
                        _ = await notificationService.requestAuthorization()
                        showNotificationPrimer = false
                    }
                },
                onDecline: { showNotificationPrimer = false }
            )
            .presentationDetents([.height(440)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            AlertSettingsSheet(preferences: preferences)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var headerStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alerts")
                        .font(Theme.Fonts.pageTitle)
                        .foregroundStyle(Theme.graphite)
                    Text("\(preferences.selectedDiseaseMode.title) · \(preferences.trackedCountryCount(totalAvailable: repository.countries().count)) tracked · last synced \(syncedAgo)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                Spacer()
                NavigationLink {
                    WatchlistView(repository: repository, preferences: preferences)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.semibold))
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.terracotta)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.terracotta.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit tracked countries")
            }
            DiseaseModeSwitcher(preferences: preferences)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Medical disclaimer (dismissible — mirrors Today's source prompt)

    /// App Review (1.4.1) wants the informational-only disclosure present and
    /// the source methodology reachable. This banner carries both — the
    /// "not for diagnosis" disclosure and a "View sources" link to
    /// `SourceTransparencyView` — and is dismissible like the Today tab's
    /// "Review data sources?" prompt. Dismissal is per-session (`@State`), so
    /// the disclosure re-appears on the next cold launch.
    private var disclaimerBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.terracotta)
                .frame(width: 36, height: 36)
                .background(Theme.terracotta.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(preferences.selectedDiseaseMode.title) information only")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("Not for diagnosis — consult a healthcare professional. See how alerts, public reports, and confidence labels are sourced.")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        SourceTransparencyView(diseaseMode: preferences.selectedDiseaseMode)
                            .onAppear { disclaimerDismissed = true }
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
                        withAnimation(.easeOut(duration: 0.20)) { disclaimerDismissed = true }
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preferences.selectedDiseaseMode.title) information only, not for diagnosis. Consult a healthcare professional. View sources, or dismiss.")
    }

    // MARK: - Notification priming card (only when status is .notDetermined)

    private var notificationPrimerCard: some View {
        Button {
            showNotificationPrimer = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.terracotta, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Get notified on escalations")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("Tracked-country alerts only — never marketing.")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyTrackedCard: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.terracotta)
                .padding(.top, 8)
            Text("No countries tracked yet")
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.graphite)
            Text("Add countries you care about — each one gets its own live alert-level widget here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.graphiteSecondary)
                .padding(.horizontal, 16)
                .lineSpacing(2)
            NavigationLink {
                WatchlistView(repository: repository, preferences: preferences)
            } label: {
                Text("Add countries")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Theme.terracotta, in: Capsule())
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    // MARK: - Widget grid (one per tracked country)

    private var widgetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(trackedClassifications, id: \.id) { classification in
                NavigationLink {
                    if let snap = repository.country(isoCode: classification.countryISO) {
                        CountryDetailView(country: snap, preferences: preferences)
                    } else {
                        // Fallback view if backend doesn't have the country snapshot.
                        Text(classification.countryName)
                    }
                } label: {
                    classificationWidget(classification)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func classificationWidget(_ c: CountryClassification) -> some View {
        let recentSignalsCount = repository.signals.filter { $0.countryISO == c.countryISO }.count
        let (tint, accent) = badgeColors(level: c.level)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text(flagEmoji(for: c.countryISO))
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.countryName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(c.sourceOrganisation)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary.opacity(0.6))
            }

            // Big level badge — the "widget" payload.
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 10, height: 10)
                Text(c.level.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                Text("\(recentSignalsCount)")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.graphiteSecondary)
                Text("signals")
                    .font(.caption2)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Status sentence.
            Text(c.level.blurb)
                .font(.caption)
                .foregroundStyle(Theme.graphiteSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    private func badgeColors(level: EmergencyClassification) -> (Color, Color) {
        switch level {
        case .none:                  return (Theme.softGrey, Theme.bone)
        case .advisory:              return (Color(red: 0.78, green: 0.62, blue: 0.30), Theme.bone.opacity(0.7))
        case .outbreak:              return (Theme.terracotta, Theme.terracotta.opacity(0.10))
        case .nationalEmergency:     return (Color(red: 0.84, green: 0.18, blue: 0.18), Color(red: 0.84, green: 0.18, blue: 0.18).opacity(0.10))
        case .internationalConcern:  return (.white, Color(red: 0.84, green: 0.18, blue: 0.18))
        }
    }

    // MARK: - Helpers

    private func flagEmoji(for iso: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in iso.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) { s.append(String(scalar)) }
        }
        return s.isEmpty ? "🌍" : s
    }

    private var syncedAgo: String {
        let mins = max(0, Int(Date().timeIntervalSince(lastSyncedAt) / 60))
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    @MainActor
    private func refreshAndNotify() async {
        await repository.refresh(preferences: preferences)
        let changes = repository.recentChanges(limit: 100).filter {
            preferences.isFollowing($0.countryISO)
        }
        for change in changes {
            _ = await notificationService.scheduleClassificationChange(change, preferences: preferences)
        }
        repository.commitClassificationSnapshot()
        lastSyncedAt = Date()
    }
}

// MARK: - Permission priming sheet

private struct NotificationPrimerSheet: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.terracotta)
                .padding(.top, 24)
            Text("Get notified on escalations")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)
            Text("HantaAtlas will send a notification when a country you've saved escalates its emergency classification. Source-attributed, no marketing.")
                .font(.callout)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 20)
            VStack(alignment: .leading, spacing: 8) {
                Label("Tracked-country escalations only", systemImage: "bookmark.fill")
                Label("Tune frequency, threshold, quiet hours", systemImage: "slider.horizontal.3")
                Label("Disable any time in Alerts → Settings", systemImage: "hand.raised")
            }
            .font(.footnote)
            .foregroundStyle(Theme.graphiteSecondary)
            .padding(.horizontal, 36)
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Button(action: onAllow) {
                    Text("Allow notifications")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.terracotta, in: RoundedRectangle(cornerRadius: 14))
                }
                Button(action: onDecline) {
                    Text("Not now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Settings sheet (frequency / threshold / quiet hours)

private struct AlertSettingsSheet: View {
    let preferences: LocalPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Frequency") {
                    Picker("Alert frequency", selection: Binding(
                        get: { preferences.alertFrequency },
                        set: { preferences.alertFrequency = $0 }
                    )) {
                        ForEach(AlertFrequency.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Toggle("Case signals", isOn: Binding(
                        get: { preferences.trackedCountryCaseAlerts },
                        set: { preferences.trackedCountryCaseAlerts = $0 }
                    ))
                    Toggle("More than 3 news signals", isOn: Binding(
                        get: { preferences.trackedCountryNewsBurstAlerts },
                        set: { preferences.trackedCountryNewsBurstAlerts = $0 }
                    ))
                    Toggle("Official notices", isOn: Binding(
                        get: { preferences.officialNoticeAlerts },
                        set: { preferences.officialNoticeAlerts = $0 }
                    ))
                } header: {
                    Text("Tracked-country rules")
                } footer: {
                    Text("Case and news-volume alerts only apply to countries you track, or every country when Track all countries is enabled.")
                }
                Section {
                    Picker("Minimum level", selection: Binding(
                        get: { preferences.minAlertLevel },
                        set: { preferences.minAlertLevel = $0 }
                    )) {
                        ForEach(EmergencyClassification.allCases) { lvl in
                            Text(lvl.title).tag(lvl)
                        }
                    }
                } header: {
                    Text("Minimum level")
                } footer: {
                    Text("Notify only when a country reaches this level or higher.")
                }
                Section {
                    Toggle("Enable quiet hours", isOn: Binding(
                        get: { preferences.quietHoursEnabled },
                        set: { preferences.quietHoursEnabled = $0 }
                    ))
                    if preferences.quietHoursEnabled {
                        Stepper("Start: \(String(format: "%02d:00", preferences.quietHoursStart))",
                                value: Binding(get: { preferences.quietHoursStart }, set: { preferences.quietHoursStart = $0 }),
                                in: 0...23)
                        Stepper("End: \(String(format: "%02d:00", preferences.quietHoursEnd))",
                                value: Binding(get: { preferences.quietHoursEnd }, set: { preferences.quietHoursEnd = $0 }),
                                in: 0...23)
                    }
                } header: {
                    Text("Quiet hours")
                } footer: {
                    Text("No real-time notifications during quiet hours. Daily and weekly digests still deliver on schedule.")
                }
                Section {
                    Text("Sources: WHO Disease Outbreak News, ECDC, CDC HAN, PAHO. Informational only — not for emergency use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Alert settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
