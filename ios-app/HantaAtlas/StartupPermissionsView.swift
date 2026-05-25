import SwiftUI
import CoreLocation
import UserNotifications

/// First-run permission gate shown immediately after the launch splash and
/// before onboarding. Every permission remains optional: denial or skip moves
/// forward and never blocks the core app.
struct StartupPermissionsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("hasCompletedStartupPermissions") private var hasCompleted: Bool = false
    @State private var locationService = LocationService.shared
    @State private var notificationService = NotificationService.shared
    @State private var step: Step = .privacy
    @State private var isRequestingLocation = false
    @State private var isRequestingNotifications = false

    private enum Step: Int, CaseIterable {
        case privacy
        case location
        case notifications
        case done
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.paper, Theme.ivory, Theme.bone],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                progress
                content
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .offset(y: 14)))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .bottom) {
            actions
                .frame(maxWidth: actionMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 18)
        }
        .onChange(of: locationService.authorization) { _, status in
            guard isRequestingLocation, status != .notDetermined else { return }
            isRequestingLocation = false
            advance()
        }
        .animation(.smooth(duration: 0.28), value: step)
    }

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var contentMaxWidth: CGFloat { isRegularWidth ? 560 : .infinity }
    private var actionMaxWidth: CGFloat { isRegularWidth ? 420 : .infinity }
    private var horizontalPadding: CGFloat { isRegularWidth ? Theme.Space.xxl : Theme.Space.l }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item == step ? Theme.terracotta : Theme.stone.opacity(0.55))
                    .frame(width: item == step ? 24 : 12, height: 4)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .privacy:
            permissionCard(
                symbol: "lock.shield.fill",
                tint: Theme.moss,
                title: "Your choices come first",
                body: "HantaAtlas asks for optional access before onboarding so nothing surprises you later. Location stays on device. Notifications are local alerts you control.",
                rows: [
                    ("location.viewfinder", "Center the map on your country"),
                    ("bell.badge.fill", "Notify you about tracked-country changes"),
                    ("hand.raised.fill", "Continue even when you decline")
                ]
            )
        case .location:
            permissionCard(
                symbol: "location.fill",
                tint: Theme.terracotta,
                title: "Location for the map",
                body: "Location is used to center the surveillance map near your country and show nearby public signals. It is not sent to HantaAtlas servers.",
                rows: [
                    ("iphone", "On-device only"),
                    ("scope", "Country-level map centering"),
                    ("location.slash", "The app still works without it")
                ]
            )
        case .notifications:
            permissionCard(
                symbol: "bell.badge.fill",
                tint: Theme.amber,
                title: "Optional signal alerts",
                body: "Notifications are for outbreak-signal changes and tracked-country updates. You can turn them off or change the alert level in the app.",
                rows: [
                    ("checkmark.shield.fill", "Health-relevant alerts only"),
                    ("slider.horizontal.3", "Frequency and quiet hours are configurable"),
                    ("bell.slash", "The dashboard still works without alerts")
                ]
            )
        case .done:
            permissionCard(
                symbol: "checkmark.seal.fill",
                tint: Theme.moss,
                title: "Ready",
                body: "Next is onboarding. You can revisit permissions and tracking modes later from Profile.",
                rows: [
                    ("globe.europe.africa.fill", "Track Hantavirus, Ebola, or both"),
                    ("link", "Every signal keeps source context"),
                    ("exclamationmark.triangle", "Not diagnosis or emergency guidance")
                ]
            )
        }
    }

    private func permissionCard(
        symbol: String,
        tint: Color,
        title: String,
        body: String,
        rows: [(String, String)]
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)

            Text(body)
                .font(.body)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: row.0)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 22)
                        Text(row.1)
                            .font(.callout)
                            .foregroundStyle(Theme.graphite)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .padding(22)
        .background(Theme.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                continueTapped()
            } label: {
                HStack(spacing: 8) {
                    if isRequestingNotifications {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Continue")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.terracotta, in: Capsule())
                .shadow(color: Theme.terracotta.opacity(0.28), radius: 18, y: 8)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRequestingLocation || isRequestingNotifications)

            if step == .location || step == .notifications {
                Button("Not now") {
                    skipPermission()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
                .frame(minHeight: 34)
                .buttonStyle(.plain)
                .disabled(isRequestingLocation || isRequestingNotifications)
            }
        }
    }

    private func continueTapped() {
        switch step {
        case .privacy:
            advance()
        case .location:
            switch locationService.authorization {
            case .notDetermined:
                isRequestingLocation = true
                locationService.requestWhenInUse()
            default:
                advance()
            }
        case .notifications:
            guard notificationService.authorization == .notDetermined else {
                advance()
                return
            }
            isRequestingNotifications = true
            Task {
                _ = await notificationService.requestAuthorization()
                isRequestingNotifications = false
                advance()
            }
        case .done:
            hasCompleted = true
        }
    }

    private func skipPermission() {
        isRequestingLocation = false
        isRequestingNotifications = false
        advance()
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            hasCompleted = true
        }
    }
}

#Preview("Startup permissions") {
    StartupPermissionsView()
}
