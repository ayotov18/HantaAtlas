#if DEBUG
import SwiftUI
import UserNotifications

/// Debug-only sheet that fires every variant of the notification flow on
/// demand, so the path can be verified without waiting for real backend
/// classification changes.
///
/// HantaAtlas only sends one *type* of system notification: a local
/// `UNNotificationRequest` from
/// `NotificationService.scheduleClassificationChange(_:preferences:)`.
/// That single method gates delivery on five filters (authorization,
/// frequency, escalation-only, severity threshold, quiet hours), and
/// wires into three trigger shapes (immediate, daily 08:00, weekly Monday
/// 08:00). The tester exercises every cell in that matrix.
///
/// How to reach it: ProfileView → "Notification tester (Debug)". This
/// section is compiled out of Release builds entirely.
struct NotificationTesterSheet: View {
    let preferences: LocalPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var notificationService = NotificationService.shared
    @State private var lastResult: ResultLine? = nil

    fileprivate struct ResultLine: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let kind: Kind
        enum Kind {
            case fired, filtered, error
            var symbol: String {
                switch self {
                case .fired: "checkmark.circle.fill"
                case .filtered: "line.3.horizontal.decrease.circle.fill"
                case .error: "exclamationmark.triangle.fill"
                }
            }
            var tint: Color {
                switch self {
                case .fired: .green
                case .filtered: .orange
                case .error: .red
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                authSection
                escalationSection
                filterCasesSection
                frequencySection
                rawSection
                resetSection
            }
            .navigationTitle("Notification tester")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let line = lastResult {
                    resultBanner(line)
                        .padding(12)
                        .background(.regularMaterial)
                }
            }
        }
    }

    // MARK: - Sections

    private var authSection: some View {
        Section("Authorization") {
            HStack {
                Text("Status")
                Spacer()
                Text(authStatusLabel(notificationService.authorization))
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            Button("Request authorization") {
                Task {
                    let granted = await notificationService.requestAuthorization()
                    show(.fired,
                         title: "Authorization",
                         detail: granted ? "Granted" : "Denied or undetermined")
                }
            }
        }
    }

    /// Each escalation case fires the canonical filter chain. The default
    /// `realtime` frequency + `advisory` minimum threshold means all four
    /// of these should land as visible banners (after a 1 s delay) on a
    /// device with notifications authorized.
    private var escalationSection: some View {
        Section {
            ForEach(EscalationCase.allCases) { row in
                Button {
                    fire(row.change(), label: row.title)
                } label: {
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text(row.fromTo).foregroundStyle(.secondary).font(.caption2.monospaced())
                    }
                }
            }
        } header: {
            Text("Escalations (should fire)")
        } footer: {
            Text("Each fires `scheduleClassificationChange(_:preferences:)` with a fresh ClassificationChange. Real-time frequency uses a 1 s timer trigger, so the banner lands ~1 s after tap.")
                .font(.caption)
        }
    }

    /// Cases that *should* be silently filtered. Useful for verifying the
    /// logic in `scheduleClassificationChange` actually rejects them.
    private var filterCasesSection: some View {
        Section {
            Button("De-escalation (OUTBREAK → ADVISORY)") {
                let change = ClassificationChange.fixture(
                    iso: "DE", name: "Germany",
                    from: .outbreak, to: .advisory
                )
                fire(change, label: "De-escalation")
            }
            Button("Below severity threshold") {
                // Force-min to OUTBREAK so an ADVISORY escalation is below it.
                let originalMin = preferences.minAlertLevel
                preferences.minAlertLevel = .outbreak
                let change = ClassificationChange.fixture(
                    iso: "FR", name: "France",
                    from: .none, to: .advisory
                )
                fire(change, label: "Below threshold") {
                    preferences.minAlertLevel = originalMin
                }
            }
            Button("Frequency = off") {
                let originalFreq = preferences.alertFrequency
                preferences.alertFrequency = .off
                let change = ClassificationChange.fixture(
                    iso: "AR", name: "Argentina",
                    from: .none, to: .outbreak
                )
                fire(change, label: "Frequency off") {
                    preferences.alertFrequency = originalFreq
                }
            }
            Button("Quiet hours active (real-time)") {
                let originalEnabled = preferences.quietHoursEnabled
                let originalStart = preferences.quietHoursStart
                let originalEnd = preferences.quietHoursEnd
                preferences.quietHoursEnabled = true
                let now = Calendar.current.component(.hour, from: Date())
                preferences.quietHoursStart = now
                preferences.quietHoursEnd = (now + 2) % 24
                let change = ClassificationChange.fixture(
                    iso: "BR", name: "Brazil",
                    from: .advisory, to: .outbreak
                )
                fire(change, label: "Quiet hours") {
                    preferences.quietHoursEnabled = originalEnabled
                    preferences.quietHoursStart = originalStart
                    preferences.quietHoursEnd = originalEnd
                }
            }
        } header: {
            Text("Filter cases (should NOT fire)")
        } footer: {
            Text("Tap to verify each filter rejects the change. Each case temporarily flips the relevant preference and restores it after.")
                .font(.caption)
        }
    }

    private var frequencySection: some View {
        Section {
            Button("Daily digest (scheduled 08:00)") {
                let originalFreq = preferences.alertFrequency
                preferences.alertFrequency = .daily
                let change = ClassificationChange.fixture(
                    iso: "US", name: "United States",
                    from: .advisory, to: .outbreak
                )
                fire(change, label: "Daily digest") {
                    preferences.alertFrequency = originalFreq
                }
            }
            Button("Weekly digest (scheduled Mon 08:00)") {
                let originalFreq = preferences.alertFrequency
                preferences.alertFrequency = .weekly
                let change = ClassificationChange.fixture(
                    iso: "KR", name: "South Korea",
                    from: .advisory, to: .outbreak
                )
                fire(change, label: "Weekly digest") {
                    preferences.alertFrequency = originalFreq
                }
            }
        } header: {
            Text("Digest schedules")
        } footer: {
            Text("These DO schedule but with a UNCalendarNotificationTrigger pointed at the next 08:00 (daily) or next Monday 08:00 (weekly), so you won't see the banner immediately. Inspect via the device Settings → Notifications page or add a trigger override below to receive immediately.")
                .font(.caption)
        }
    }

    private var rawSection: some View {
        Section {
            Button("Raw test notification (bypass all filters)") {
                Task { await fireRaw() }
            }
        } header: {
            Text("Raw delivery")
        } footer: {
            Text("Fires a `UNNotificationRequest` directly via the system center, bypassing scheduleClassificationChange and every preference filter. Use this to verify authorization + sound + badge work.")
                .font(.caption)
        }
    }

    private var resetSection: some View {
        Section {
            Button("Cancel all pending notifications", role: .destructive) {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                show(.fired, title: "Cleared", detail: "All pending requests removed")
            }
        }
    }

    // MARK: - Fire / Result helpers

    private func fire(_ change: ClassificationChange, label: String, after: (() -> Void)? = nil) {
        Task {
            let scheduled = await notificationService.scheduleClassificationChange(change, preferences: preferences)
            after?()
            if scheduled {
                show(.fired,
                     title: label,
                     detail: "Scheduled · \(change.fromLevel.rawValue) → \(change.toLevel.rawValue)")
            } else {
                show(.filtered,
                     title: label,
                     detail: filterReason(change))
            }
        }
    }

    private func fireRaw() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            show(.error, title: "Raw test", detail: "Not authorized; tap Request authorization first")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "HantaAtlas test"
        content.body = "Raw delivery — bypassed scheduleClassificationChange filters"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "raw-test-\(UUID())", content: content, trigger: trigger)
        do {
            try await center.add(request)
            show(.fired, title: "Raw test", detail: "Banner in ~1 s")
        } catch {
            show(.error, title: "Raw test failed", detail: error.localizedDescription)
        }
    }

    /// Best-effort summary of why a `scheduleClassificationChange` returned
    /// false. Mirrors the conditional chain inside the function so we can
    /// show a precise reason without exposing internal state.
    private func filterReason(_ change: ClassificationChange) -> String {
        if notificationService.authorization != .authorized
            && notificationService.authorization != .provisional {
            return "Authorization not granted"
        }
        if preferences.alertFrequency == .off {
            return "Frequency = off"
        }
        if !change.isEscalation {
            return "Not an escalation"
        }
        if change.toLevel.severity < preferences.minAlertLevel.severity {
            return "Below severity threshold (min = \(preferences.minAlertLevel.rawValue))"
        }
        if preferences.alertFrequency == .realtime,
           preferences.quietHoursEnabled {
            return "In quiet hours window"
        }
        return "Filtered (reason not derivable client-side)"
    }

    @MainActor
    private func show(_ kind: ResultLine.Kind, title: String, detail: String) {
        lastResult = ResultLine(title: title, detail: detail, kind: kind)
    }

    private func resultBanner(_ line: ResultLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: line.kind.symbol)
                .foregroundStyle(line.kind.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title).font(.subheadline.weight(.semibold))
                Text(line.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func authStatusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: "authorized"
        case .denied: "denied"
        case .notDetermined: "notDetermined"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }
}

// MARK: - Test fixtures

private enum EscalationCase: String, CaseIterable, Identifiable {
    case toAdvisory
    case toOutbreak
    case toNationalEmergency
    case toInternationalConcern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toAdvisory:             "→ Health advisory (low)"
        case .toOutbreak:             "→ Outbreak (medium)"
        case .toNationalEmergency:    "→ National emergency (high)"
        case .toInternationalConcern: "→ PHEIC (max)"
        }
    }

    var fromTo: String {
        let (f, t) = pair
        return "\(f.rawValue) → \(t.rawValue)"
    }

    var pair: (EmergencyClassification, EmergencyClassification) {
        switch self {
        case .toAdvisory:             (.none, .advisory)
        case .toOutbreak:             (.advisory, .outbreak)
        case .toNationalEmergency:    (.outbreak, .nationalEmergency)
        case .toInternationalConcern: (.nationalEmergency, .internationalConcern)
        }
    }

    func change() -> ClassificationChange {
        let (from, to) = pair
        return ClassificationChange.fixture(iso: "TEST", name: "Test Country", from: from, to: to)
    }
}

private extension ClassificationChange {
    static func fixture(
        iso: String,
        name: String,
        from: EmergencyClassification,
        to: EmergencyClassification
    ) -> ClassificationChange {
        ClassificationChange(
            countryISO: iso,
            countryName: name,
            fromLevel: from,
            toLevel: to,
            changedAt: Date(),
            sourceOrganisation: "WHO",
            sourceUrl: URL(string: "https://www.who.int")!
        )
    }
}

#endif
