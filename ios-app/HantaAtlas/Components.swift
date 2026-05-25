import SwiftUI
import UIKit

// MARK: - Top-of-screen header

/// Large-title screen header that lives inside a `ScrollView`, so the title
/// scrolls with content and never collides with the safe area or Dynamic
/// Island. The trailing slot is for a single circular action.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Space.s)
            trailing()
        }
        .padding(.top, Theme.Space.xs)
    }
}

// MARK: - Circular toolbar buttons

/// A 44 pt glass circle button, used for top-of-screen actions where the
/// system toolbar isn't appropriate (e.g. the centred Map header).
struct ToolbarCircleButton: View {
    let systemName: String
    let label: String
    var size: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.graphite)
        .background {
            GlassChrome(cornerRadius: size / 2, interactive: true) {
                Color.white.opacity(0.05)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Disease mode switcher

/// Preferences-backed wrapper around `DiseaseModeGlassControl`.
struct DiseaseModeSwitcher: View {
    let preferences: LocalPreferences
    var compact: Bool = false

    private var selection: Binding<DiseaseMode> {
        Binding(
            get: { preferences.selectedDiseaseMode },
            set: { preferences.selectedDiseaseMode = $0 }
        )
    }

    var body: some View {
        DiseaseModeGlassControl(selection: selection, compact: compact)
    }
}

/// Native segmented `Picker` — the same control the bottom tab bar and the
/// Map tab's `MapMetricSegmentedControl` rely on. The system owns the selection
/// slide, the glass material, and the press feedback, so it never snaps, never
/// blurs the page behind it, and stays consistent with the rest of the app.
/// Tinted terracotta (the app's orange-red accent) instead of green.
struct DiseaseModeGlassControl: View {
    @Binding var selection: DiseaseMode
    var compact: Bool = false

    var body: some View {
        Picker("Disease tracking mode", selection: $selection) {
            ForEach(DiseaseMode.allCases) { mode in
                Text(compact ? mode.shortTitle : mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(Theme.terracotta)
        .accessibilityLabel("Disease tracking mode")
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Account avatar

/// The signed-in user's avatar, shown wherever we preview their account — the
/// Today header pip and the Profile identity card.
///
/// Apple doesn't expose the Apple ID / iCloud photo to apps (Sign in with Apple
/// gives only name + email), and iOS has no API to read the device owner's
/// Contacts card either — so a real picture can only come from the user
/// choosing one. The fallback chain is: a photo the user picked
/// (`ProfileAvatarStore`, via the PhotosPicker on the Profile screen) → an
/// initials monogram from the SIWA name → a neutral silhouette when signed out.
/// Observes `UserSession` + `ProfileAvatarStore`, so it updates the moment the
/// user signs in/out or sets a photo.
struct AccountAvatarView: View {
    var size: CGFloat = 42

    @State private var session = UserSession.shared
    @State private var avatarStore = ProfileAvatarStore.shared

    private var initials: String? {
        guard let value = session.currentUser?.initials, value != "👤" else { return nil }
        return value
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Theme.amber, Theme.terracotta],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            if session.isAuthenticated, let photo = avatarStore.image {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else if let initials {
                Text(initials)
                    .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.46, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityElement()
        .accessibilityLabel(session.isAuthenticated ? "Signed in" : "Profile")
    }
}

/// Stores the user-chosen profile photo on device and publishes it to
/// `AccountAvatarView`. Apple gives apps no access to the Apple ID / iCloud
/// photo, so the picture is whatever the user picks via the PhotosPicker on the
/// Profile screen. Persisted as a downscaled JPEG in Application Support;
/// `image` is nil until one is set, so the avatar falls back to the monogram.
///
/// Local-only for now — cross-device sync would need a backend image endpoint
/// (the current `PreferencesSync` carries only the small settings payload).
@MainActor
@Observable
final class ProfileAvatarStore {
    static let shared = ProfileAvatarStore()

    private(set) var image: UIImage?

    @ObservationIgnored private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("profile-avatar.jpg")
    }()

    private init() {
        if let data = try? Data(contentsOf: fileURL) { image = UIImage(data: data) }
    }

    /// Persist a chosen photo (downscaled to a 512 pt square-ish JPEG so we
    /// never store a multi-MB original) and publish it.
    func setImage(data rawData: Data) {
        guard let picked = UIImage(data: rawData)?.downscaled(maxDimension: 512),
              let jpeg = picked.jpegData(compressionQuality: 0.85) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? jpeg.write(to: fileURL, options: .atomic)
        image = picked
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        image = nil
    }
}

private extension UIImage {
    /// Aspect-fit downscale so the longest side is at most `maxDimension`.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

// MARK: - Confidence and severity badges

/// A pill badge that summarises confidence with an SF Symbol and short label.
struct ConfidenceBadge: View {
    let level: ConfidenceLevel
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.symbolName)
                .font(.caption.weight(.bold))
            Text(compact ? level.shortTitle : level.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(level.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(level.paperTint, in: Capsule())
        .accessibilityLabel("Confidence: \(level.title). \(level.explanation)")
    }
}

/// Severity badge with three tint bars rather than colour alone.
struct SeverityBadge: View {
    let severity: AlertSeverity

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 1.4, style: .continuous)
                        .fill(index < severity.bars ? severity.tint : severity.tint.opacity(0.25))
                        .frame(width: 3, height: 12 - CGFloat(2 - index) * 2)
                }
            }
            Text(severity.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(severity.tint)
        }
        .accessibilityLabel("Severity: \(severity.title)")
    }
}

/// Source organisation badge — a small `globe` glyph plus organisation label.
struct SourceBadge: View {
    let source: Source

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
            Text(source.organisation)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
                .lineLimit(1)
        }
        .accessibilityLabel("Source: \(source.organisation)")
    }
}

// MARK: - Section header

struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.graphite)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
        }
    }
}

// MARK: - Metric tile

/// 2-up metric tile used on Today and Country Detail.
struct MetricTile: View {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Spacer()
                IconTile(systemName: symbolName, tint: tint, size: 30)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let footnote {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(cornerRadius: Theme.Radius.card, padding: 16)
        .accessibilityElement(children: .combine)
    }
}

/// A small filled-tile icon, used as a secondary anchor inside content cards.
struct IconTile: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Date trio tile

/// Small date tile used inside Country Detail and the Map drawer.
struct DateTile: View {
    let icon: String
    let title: String
    let value: String
    let footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.bone.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }
}

// MARK: - Filter chip

/// Filter pill — wraps a `Menu` and adopts Liquid Glass on iOS 26 via the
/// native `.glass` button style. The selected state is conveyed by tinting
/// the foreground icon and label, not by a heavier background, so the
/// surface stays calm. Falls back to a tinted bone capsule on older targets.
struct FilterChip<Content: View>: View {
    let title: String
    let systemName: String
    var isSelected: Bool = false
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu {
            menu()
        } label: {
            chipLabel
        }
        .modifier(FilterChipBackground(isSelected: isSelected))
        .accessibilityLabel("\(title) filter")
    }

    private var chipLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(isSelected ? Theme.moss : Theme.graphite)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

private struct FilterChipBackground: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(isSelected ? Theme.bone.opacity(0.95) : Theme.bone.opacity(0.55)))
        }
    }
}

// MARK: - Country row + flag badge

struct FlagBadge: View {
    let isoCode: String
    var size: CGFloat = 44

    private var flagEmoji: String {
        let normalized = isoCode.uppercased()
        guard normalized.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        var scalars = ""
        for scalar in normalized.unicodeScalars {
            guard scalar.value >= 65 && scalar.value <= 90,
                  let flagScalar = UnicodeScalar(base + scalar.value) else {
                return "🌐"
            }
            scalars.append(String(flagScalar))
        }
        return scalars
    }

    var body: some View {
        ZStack {
            Circle().fill(Theme.bone)
            Text(flagEmoji)
                .font(.system(size: size * 0.56))
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.4))
        .accessibilityHidden(true)
    }
}

/// A saved-country row used on Saved and the Today preview.
struct CountryRow: View {
    let country: CountrySnapshot

    var body: some View {
        HStack(spacing: 14) {
            FlagBadge(isoCode: country.isoCode, size: 46)
            VStack(alignment: .leading, spacing: 6) {
                Text(country.countryName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                ConfidenceBadge(level: country.confidenceLevel, compact: false)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("Last checked")
                    .font(.caption)
                    .foregroundStyle(Theme.graphiteSecondary)
                Text(AppDateFormat.shortMonth.string(from: country.lastCheckedAt))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
                .padding(.leading, 2)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Guide cards

/// The clay-shielded callout at the top of the Guide.
struct GuideCalloutCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.clay)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 16)
    }
}

/// The leading-symbol-tile action row used inside the Guide.
struct GuideActionRow: View {
    let symbolName: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: symbolName, tint: tint, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
                .padding(.top, 14)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Map metric segmented control

/// Wraps the native `Picker(.segmented)` so the map metric picker adopts
/// Liquid Glass automatically on iOS 26 and avoids manual sizing problems
/// such as multi-line segment labels.
struct MapMetricSegmentedControl: View {
    @Binding var selection: MapMetric

    var body: some View {
        Picker("Map metric", selection: $selection) {
            ForEach(MapMetric.allCases) { metric in
                Text(metric.title).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .tint(Theme.moss)
        .accessibilityLabel("Map metric")
    }
}

// MARK: - Legend

struct LegendPlate: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(ConfidenceLevel.allCases) { level in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(level.tint)
                        .frame(width: 22, height: 22)
                    Text(level.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.graphite)
                    Spacer(minLength: 8)
                    Text(level.legendBlurb)
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map legend")
    }
}

// MARK: - Country drawer (Map)

struct CountryDrawer: View {
    let country: CountrySnapshot
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Theme.softGrey.opacity(0.55))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
            HStack(alignment: .center, spacing: 14) {
                FlagBadge(isoCode: country.isoCode, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(country.countryName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text(country.regionName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                Spacer()
                ConfidenceBadge(level: country.confidenceLevel)
            }
            HStack(spacing: 10) {
                DateTile(
                    icon: "calendar",
                    title: "Reported",
                    value: country.cases.map { "\($0)" } ?? "—",
                    footnote: country.reportingPeriodLabel
                )
                DateTile(
                    icon: "calendar",
                    title: "Published",
                    value: country.publishedAt.map(AppDateFormat.shortMonth.string(from:)) ?? "—",
                    footnote: "Latest update"
                )
                DateTile(
                    icon: "building.columns",
                    title: "Source",
                    value: country.source.organisation,
                    footnote: country.regionName
                )
            }
            Button(action: onViewDetails) {
                HStack {
                    Text("View country details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.graphite)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.bone.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .paperCard(cornerRadius: Theme.Radius.hero, padding: 18)
    }
}

// MARK: - Empty state and About card

struct EmptyStateCard: View {
    let title: String
    let message: String
    let symbolName: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
                .foregroundStyle(Theme.graphite)
        } description: {
            Text(message)
                .foregroundStyle(Theme.graphiteSecondary)
        }
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: Theme.Radius.card, padding: 16)
    }
}

struct AboutDataCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
                .frame(width: 32, height: 32)
                .background(Theme.bone.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Alert row (Feed cards)

struct AlertRowCard: View {
    let alert: OfficialAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(
                    systemName: alert.confidenceLevel == .officialStructuredData ? "chart.bar.fill" : "exclamationmark.triangle.fill",
                    tint: alert.confidenceLevel.tint,
                    size: 48
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(alert.confidenceLevel.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(alert.confidenceLevel.tint)
                    Text(alert.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.graphiteSecondary)
                        Text(alert.countryName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.graphiteSecondary)
                            .lineLimit(2)
                    }
                    Text(alert.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 10) {
                    ConfidenceBadge(level: alert.confidenceLevel, compact: true)
                    SourceBadge(source: alert.source)
                    SeverityBadge(severity: alert.severity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            Divider()
                .overlay(Theme.stroke)
            HStack(spacing: 12) {
                MiniDate(icon: "calendar", title: "Reported", value: AppDateFormat.shortMonth.string(from: alert.reportedAt))
                MiniDate(icon: "calendar", title: "Published", value: AppDateFormat.shortMonth.string(from: alert.publishedAt))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

private struct MiniDate: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
            }
        }
    }
}

// MARK: - Disclaimer card (kept for callers)

struct DisclaimerCard: View {
    var body: some View {
        GuideCalloutCard(
            title: "Informational only, not diagnosis",
            message: "This guidance helps reduce risk. It does not replace medical care — consult a healthcare professional before making medical decisions."
        )
    }
}

/// Compact one-line "informational only" caption that links to the full
/// source-methodology screen. Surfaced on every screen that renders public-
/// health metrics — Today, Alerts, country detail — so the disclaimer travels
/// with the data instead of being buried behind a floating-action button.
///
/// Why this exists: App Review guideline 1.4.1 requires medical / health-
/// adjacent apps to clearly disclose data and methodology. A single banner per
/// screen, immediately above the metrics, is the cleanest way to satisfy it
/// without bloating the layout.
struct MedicalDisclaimerCaption: View {
    var diseaseMode: DiseaseMode = .both

    var body: some View {
        NavigationLink {
            SourceTransparencyView(diseaseMode: diseaseMode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Text(captionAttributed)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.bone.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(diseaseMode.title) information only, not for diagnosis. Consult a doctor. Tap to view sources and methodology.")
    }

    /// Per-segment styling via `AttributedString`. The previous implementation
    /// used `Text(...) + Text(...)` which iOS 26 deprecates with: `'+' was
    /// deprecated in iOS 26.0: Use string interpolation on Text instead`.
    /// Interpolation doesn't carry per-segment foreground colour or underline,
    /// so AttributedString is the right replacement.
    private var captionAttributed: AttributedString {
        var disclaimer = AttributedString("\(diseaseMode.title) information only — not for diagnosis. Consult a doctor. ")
        disclaimer.foregroundColor = Theme.graphiteSecondary
        var link = AttributedString("View sources")
        link.foregroundColor = Theme.terracotta
        link.underlineStyle = .single
        return disclaimer + link
    }
}
