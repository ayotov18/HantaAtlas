import SwiftUI

// MARK: - Theme tokens

enum Theme {
    // Warm neutral palette. No purple, no blue.
    static let ivory = Color(red: 0.972, green: 0.948, blue: 0.902)
    static let bone = Color(red: 0.945, green: 0.918, blue: 0.866)
    static let oat = Color(red: 0.918, green: 0.886, blue: 0.824)
    static let paper = Color(red: 0.988, green: 0.972, blue: 0.940)
    static let stone = Color(red: 0.760, green: 0.732, blue: 0.672)
    static let softGrey = Color(red: 0.700, green: 0.685, blue: 0.640)
    static let graphite = Color(red: 0.140, green: 0.130, blue: 0.115)
    static let graphiteSecondary = Color(red: 0.395, green: 0.370, blue: 0.330)

    static let moss = Color(red: 0.420, green: 0.495, blue: 0.330)
    static let olive = Color(red: 0.555, green: 0.555, blue: 0.380)
    static let clay = Color(red: 0.665, green: 0.420, blue: 0.310)
    static let terracotta = Color(red: 0.760, green: 0.380, blue: 0.270)
    static let amber = Color(red: 0.825, green: 0.640, blue: 0.330)

    static let separator = Color.black.opacity(0.07)
    static let stroke = Color.black.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.045)

    // Spacing scale
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let huge: CGFloat = 44
    }

    // Radii
    enum Radius {
        static let pill: CGFloat = 999
        static let tile: CGFloat = 16
        static let card: CGFloat = 22
        static let hero: CGFloat = 28
    }

    // MARK: - Typography
    //
    // Centralised font tokens that respect Apple's iOS 26 HIG (developer
    // .apple.com/design/human-interface-guidelines/typography). Each token
    // either uses a Dynamic Type text style (preferred — scales with the
    // user's preference) or `.system(...relativeTo:)` for cases where we
    // want a custom size that still respects accessibility.
    //
    // Use system typography throughout. SF Pro Display/Text is picked
    // automatically, while SF Pro Rounded is reserved for friendly stats and
    // product identity moments.
    //
    // Use these tokens instead of writing raw `.system(size:weight:)`
    // throughout the codebase. They surface in one place, are easy to
    // audit, and respect Dynamic Type by default.
    enum Fonts {
        /// Product wordmark — clean SF Pro sans at a light, non-bold weight
        /// (no serif, no heavy bold). One token so the boot animation,
        /// onboarding, and auth hero all render in the exact same face.
        static let heroWordmark = Font.system(
            size: 40,
            weight: .medium
        )

        /// Tab-page title (Today, Map, Feed, Alerts headers). Clean, non-bold
        /// SF sans (`.medium`) to match the hero wordmark treatment — no heavy
        /// bold. Stays `.largeTitle` so it still scales with Dynamic Type.
        static let pageTitle = Font.largeTitle.weight(.medium)

        /// Card / section title inside a paper card. SF Pro Display via
        /// the system text-style `.title3` (scales).
        static let cardTitle = Font.title3.weight(.bold)

        /// Card body / longer descriptive text. SF Pro Text via `.callout`.
        static let cardBody = Font.callout

        /// All-caps eyebrow label above a card section. SF Pro caption2,
        /// heavy, tracked. Use with `.tracking(1.0)` at the call site.
        static let eyebrow = Font.caption2.weight(.heavy)

        /// Large stat numerals (Active countries, Following count, etc.).
        /// SF Pro Rounded scaled relative to `.title` so it respects
        /// Dynamic Type without going wild at AX5.
        static let statHero = Font.system(
            .title,
            design: .rounded,
            weight: .heavy
        )

        /// Smaller stat numerals (bento tiles, metric grids).
        static let statTile = Font.system(
            .title2,
            design: .rounded,
            weight: .heavy
        )

        /// Identity card primary line.
        static let identityName = Font.title3.weight(.bold)

        /// Body text in a row (Settings-style row label).
        static let rowLabel = Font.body

        /// Subhead under a section header or identity row.
        static let subhead = Font.subheadline

        /// Footnote-sized prose, e.g. disclaimer captions.
        static let footnote = Font.footnote
    }

    // Convenience
    static let spacing: CGFloat = Space.l
    static let radius: CGFloat = Radius.card

    static var appBackground: some View {
        LinearGradient(
            colors: [paper, ivory, bone],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Confidence and severity colour mapping

extension ConfidenceLevel {
    var tint: Color {
        switch self {
        case .officialStructuredData: Theme.moss
        case .officialAlert: Theme.terracotta
        case .mediaSignal: Theme.clay
        case .noRecentPublicData: Theme.softGrey
        }
    }

    var paperTint: Color {
        switch self {
        case .officialStructuredData: Theme.moss.opacity(0.13)
        case .officialAlert: Theme.terracotta.opacity(0.13)
        case .mediaSignal: Theme.clay.opacity(0.13)
        case .noRecentPublicData: Theme.softGrey.opacity(0.18)
        }
    }

    var symbolName: String {
        switch self {
        case .officialStructuredData: "checkmark.shield.fill"
        case .officialAlert: "shield.lefthalf.filled"
        case .mediaSignal: "newspaper.fill"
        case .noRecentPublicData: "circle.dashed"
        }
    }

    var legendSymbolName: String {
        switch self {
        case .officialStructuredData: "checkmark.circle.fill"
        case .officialAlert: "exclamationmark.triangle.fill"
        case .mediaSignal: "newspaper.fill"
        case .noRecentPublicData: "circle.dashed"
        }
    }

    var legendBlurb: String {
        switch self {
        case .officialStructuredData: "Regular national reporting"
        case .officialAlert: "Recent official alert issued"
        case .mediaSignal: "Unconfirmed media reports"
        case .noRecentPublicData: "No recent official data"
        }
    }
}

extension AlertSeverity {
    var tint: Color {
        switch self {
        case .low: Theme.moss
        case .medium: Theme.amber
        case .high: Theme.terracotta
        }
    }

    var bars: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }
}

// MARK: - Map post-type colours

extension MapPostType {
    /// Colour of the dot on the map. 7 distinct warm-palette tones — no
    /// purple, no blue. Order roughly: most-urgent → least-urgent.
    /// Death gets a deeply-saturated red so it stands out from the rest of
    /// the warm spectrum at a glance — "red dots are the ones that are serious".
    var mapColor: Color {
        switch self {
        case .death:            return Color(red: 0.84, green: 0.18, blue: 0.18)          // saturated red — fatalities only
        case .caseConfirmed:    return Theme.terracotta                                   // urgent red-orange
        case .caseSuspected:    return Theme.amber                                        // alert orange
        case .caseImported:     return Theme.olive                                        // yellow-green
        case .officialResponse: return Theme.moss                                         // forest green — official action
        case .expertVoice:      return Theme.clay                                         // warm-neutral brown — "what's being said"
        case .publicDiscourse:  return Theme.softGrey                                     // neutral grey
        }
    }
}

// MARK: - Map country-fill tints

extension CountryActiveLevel {
    /// Fill colour for the world-map polygon overlay. Alpha is baked in:
    /// brighter for current activity, faint for endemic-only baseline.
    /// `nil` = do not draw a fill.
    var mapFill: Color? {
        switch self {
        case .active:   return Theme.terracotta.opacity(0.55)
        case .imported: return Theme.amber.opacity(0.45)
        case .response: return Color(red: 0.92, green: 0.78, blue: 0.42).opacity(0.30)
        case .endemic:  return Color(red: 0.96, green: 0.86, blue: 0.42).opacity(0.18)
        case .none:     return nil
        }
    }

    /// Stroke colour matched to the fill — slightly more saturated, half alpha.
    var mapStroke: Color? {
        switch self {
        case .active:   return Theme.terracotta.opacity(0.85)
        case .imported: return Theme.amber.opacity(0.75)
        case .response: return Color(red: 0.92, green: 0.78, blue: 0.42).opacity(0.55)
        case .endemic:  return Color(red: 0.96, green: 0.86, blue: 0.42).opacity(0.35)
        case .none:     return nil
        }
    }
}

// MARK: - Surfaces

extension View {
    /// Warm matte content surface — the primary content card style.
    func paperCard(
        cornerRadius: CGFloat = Theme.Radius.card,
        padding: CGFloat = 18,
        tint: Color = Theme.paper
    ) -> some View {
        self
            .padding(padding)
            .background(tint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.66)
            )
            .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

/// Restrained Liquid Glass chrome. Reserved for floating circular controls,
/// the segmented metric control, and small filter chips. Falls back to
/// ultra-thin material on older OS targets.
struct GlassChrome<Content: View>: View {
    let cornerRadius: CGFloat
    let interactive: Bool
    let tint: Color?
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = Theme.Radius.pill,
        interactive: Bool = false,
        tint: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.interactive = interactive
        self.tint = tint
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            content()
                .glassEffect(glassConfig, in: .rect(cornerRadius: cornerRadius))
        } else {
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 0.5)
                )
        }
    }

    @available(iOS 26.0, *)
    private var glassConfig: Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

struct ScreenBackground: View {
    var body: some View {
        Theme.appBackground
    }
}

// MARK: - Reduce motion helper

extension View {
    func reduceMotionFriendly(_ animation: Animation?, value: some Equatable) -> some View {
        modifier(ReducedMotionAnimation(animation: animation, value: value))
    }
}

private struct ReducedMotionAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Shared formatters

enum AppDateFormat {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let shortMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}
