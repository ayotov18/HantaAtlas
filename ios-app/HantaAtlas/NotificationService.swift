import Foundation
import UserNotifications
import Observation

/// Wrapper around UNUserNotificationCenter. Surfaces authorization status as
/// an observable property so the onboarding screen and Settings tab can react.
///
/// Apple App Store rules (4.5.4) — notifications are strictly opt-in, must not
/// be required for the app to function, and we may only deliver health-relevant
/// alerts (no marketing). The Guide tab exposes a toggle to revoke this.
@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    /// Cached authorization status. Refreshed on app foreground via `refresh()`.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refresh() }
    }

    /// Request the standard alerts+sound+badge bundle. Per Apple guidance, the
    /// app must work without this — if denied, signal alerts simply aren't
    /// delivered as push notifications (the user can still see them in-app).
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await refresh()
            return granted
        } catch {
            await refresh()
            return false
        }
    }

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorization = settings.authorizationStatus
    }

    /// Schedule a local notification for a classification change. Local-only
    /// (no APNs), respects user's quiet hours + severity threshold + frequency.
    /// Idempotent — uses change.id as the notification identifier so duplicate
    /// scheduling doesn't fire twice.
    ///
    /// - Returns: `true` if a notification was scheduled, `false` if it was
    ///   filtered out by the user's preferences.
    @discardableResult
    func scheduleClassificationChange(
        _ change: ClassificationChange,
        preferences: LocalPreferences
    ) async -> Bool {
        // Gate on authorization first.
        await refresh()
        guard authorization == .authorized || authorization == .provisional else { return false }

        // Frequency = off → never notify.
        guard preferences.alertFrequency != .off else { return false }
        // Only escalations notify (de-escalations are good news, in-app only).
        guard change.isEscalation else { return false }
        // Severity threshold gate.
        guard change.toLevel.severity >= preferences.minAlertLevel.severity else { return false }
        // Quiet hours gate (real-time only — daily/weekly digests run on schedule).
        if preferences.alertFrequency == .realtime && preferences.quietHoursEnabled
            && Self.isInQuietHours(start: preferences.quietHoursStart, end: preferences.quietHoursEnd) {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "\(change.countryName) — \(change.toLevel.title)"
        content.body = "Updated from \(change.fromLevel.title) · source: \(change.sourceOrganisation)"
        content.sound = .default
        content.categoryIdentifier = "CLASSIFICATION_CHANGE"
        content.userInfo = [
            "countryISO": change.countryISO,
            "toLevel": change.toLevel.rawValue,
            "fromLevel": change.fromLevel.rawValue
        ]

        // Trigger immediately for real-time, schedule for the next morning for
        // daily digests, or queue for weekly Monday morning for weekly.
        let trigger: UNNotificationTrigger
        switch preferences.alertFrequency {
        case .realtime:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        case .daily:
            trigger = Self.dailyDigestTrigger()
        case .weekly:
            trigger = Self.weeklyDigestTrigger()
        case .off:
            return false
        }

        let request = UNNotificationRequest(
            identifier: "classification.\(change.id)",
            content: content,
            trigger: trigger
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    /// Schedule a local notification when the signal layer discovers a country
    /// that was not present in the user's last synced signal-country baseline.
    /// This is intentionally labelled as a public/news signal, not an official
    /// outbreak alert, so the app does not overstate unverified reporting.
    @discardableResult
    func scheduleNewSignalCountry(
        isoCode: String,
        countryName: String,
        signalCount: Int,
        preferences: LocalPreferences
    ) async -> Bool {
        await refresh()
        guard authorization == .authorized || authorization == .provisional else { return false }
        guard preferences.officialNoticeAlerts else { return false }
        guard preferences.alertFrequency != .off else { return false }
        if preferences.alertFrequency == .realtime && preferences.quietHoursEnabled
            && Self.isInQuietHours(start: preferences.quietHoursStart, end: preferences.quietHoursEnd) {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "New country signal: \(countryName)"
        content.body = "\(signalCount) public \(preferences.selectedDiseaseMode.title) signal\(signalCount == 1 ? "" : "s") now on the map. Confidence: media signal until verified."
        content.sound = .default
        content.categoryIdentifier = "NEW_SIGNAL_COUNTRY"
        content.userInfo = [
            "countryISO": isoCode,
            "signalCount": signalCount,
            "confidence": ConfidenceLevel.mediaSignal.rawValue
        ]

        let trigger: UNNotificationTrigger
        switch preferences.alertFrequency {
        case .realtime:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        case .daily:
            trigger = Self.dailyDigestTrigger()
        case .weekly:
            trigger = Self.weeklyDigestTrigger()
        case .off:
            return false
        }

        let request = UNNotificationRequest(
            identifier: "new-signal-country.\(isoCode).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func scheduleTrackedCountryCaseSignal(
        signal: Signal,
        countryName: String,
        preferences: LocalPreferences
    ) async -> Bool {
        await refresh()
        guard authorization == .authorized || authorization == .provisional else { return false }
        guard preferences.trackedCountryCaseAlerts else { return false }
        guard preferences.alertFrequency != .off else { return false }
        guard preferences.shouldShowCountry(signal.countryISO, includeAllWhenEmpty: false) else { return false }
        if preferences.alertFrequency == .realtime && preferences.quietHoursEnabled
            && Self.isInQuietHours(start: preferences.quietHoursStart, end: preferences.quietHoursEnd) {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "\(countryName) — case signal"
        content.body = "\(signal.mapPostType.title): \(signal.title)"
        content.sound = .default
        content.categoryIdentifier = "TRACKED_COUNTRY_CASE_SIGNAL"
        content.userInfo = [
            "countryISO": signal.countryISO ?? "",
            "signalID": signal.id,
            "postType": signal.mapPostType.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "case-signal.\(signal.id)",
            content: content,
            trigger: Self.trigger(for: preferences.alertFrequency)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func scheduleTrackedCountryNewsBurst(
        isoCode: String,
        countryName: String,
        signalCount: Int,
        preferences: LocalPreferences
    ) async -> Bool {
        await refresh()
        guard authorization == .authorized || authorization == .provisional else { return false }
        guard preferences.trackedCountryNewsBurstAlerts else { return false }
        guard preferences.alertFrequency != .off else { return false }
        guard preferences.shouldShowCountry(isoCode, includeAllWhenEmpty: false) else { return false }
        if preferences.alertFrequency == .realtime && preferences.quietHoursEnabled
            && Self.isInQuietHours(start: preferences.quietHoursStart, end: preferences.quietHoursEnd) {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "\(countryName) — news activity"
        content.body = "\(signalCount) public \(preferences.selectedDiseaseMode.title) signals are now attached to this country. Review sources before drawing conclusions."
        content.sound = .default
        content.categoryIdentifier = "TRACKED_COUNTRY_NEWS_BURST"
        content.userInfo = [
            "countryISO": isoCode,
            "signalCount": signalCount,
            "confidence": ConfidenceLevel.mediaSignal.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "news-burst.\(isoCode).\(signalCount)",
            content: content,
            trigger: Self.trigger(for: preferences.alertFrequency)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    private static func isInQuietHours(start: Int, end: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if start <= end { return hour >= start && hour < end }
        return hour >= start || hour < end  // wraps midnight
    }

    private static func trigger(for frequency: AlertFrequency) -> UNNotificationTrigger {
        switch frequency {
        case .realtime:
            return UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        case .daily:
            return dailyDigestTrigger()
        case .weekly:
            return weeklyDigestTrigger()
        case .off:
            return UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        }
    }

    private static func dailyDigestTrigger() -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = 8  // 08:00 local time
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private static func weeklyDigestTrigger() -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.weekday = 2  // Monday
        components.hour = 8
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
