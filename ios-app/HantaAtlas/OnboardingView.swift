import SwiftUI

/// First-launch onboarding. Four informational screens — no permission
/// prompts (Apple HIG: ask in-context). Each step is fronted by a full-bleed,
/// topic-related generated background (editorial risograph cartography in the
/// warm brand palette, produced via OpenRouter `openai/gpt-5.4-image-2`):
///
///  - Step 0 (welcome): warm world map with glowing data points.
///  - Step 1 (informational only): field-notebook contours + compass rose.
///  - Step 2 (mode): grassland + forest habitats with survey routes.
///  - Step 3 (confidence levels): layered archival documents + seals.
///
/// The image is the hero; copy and controls sit on translucent "panel"
/// widgets so they stay legible over the imagery (WCAG contrast), with a warm
/// scrim unifying the whole. The images carry calm copy-space in their upper
/// area by design.
///
/// Persistence: `@AppStorage("hasCompletedOnboarding")` is flipped on
/// completion. The hosting `HantaAtlasApp` swaps between this and ContentView.
struct OnboardingView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL

    @AppStorage("hasCompletedOnboarding") private var hasCompleted: Bool = false
    @AppStorage("hantaatlas.selectedDiseaseMode") private var selectedDiseaseModeRaw: String = DiseaseMode.both.rawValue
    @State private var step: Int = 0

    /// Public legal pages on the marketing site — same canonical URLs the auth
    /// screen and Profile link to. Surfaced here so Terms + Privacy are visible
    /// and reachable throughout onboarding, before any account or tracking.
    private static let termsURL = URL(string: "https://thehantaapp.com/tos")!
    private static let privacyURL = URL(string: "https://thehantaapp.com/privacy")!

    var body: some View {
        ZStack {
            backdrop
                .allowsHitTesting(false)

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 26) {
                        stepIndicator

                        content
                            .id(step)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 14)),
                                removal: .opacity.combined(with: .offset(y: -14))
                            ))
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, proxy.size.height - 108), alignment: .center)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, Theme.Space.xl)
                    .padding(.bottom, 112)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom) {
            actions
                .frame(maxWidth: actionMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 18)
        }
        .animation(.easeOut(duration: 0.35), value: step)
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var contentMaxWidth: CGFloat {
        isRegularWidth ? 560 : .infinity
    }

    private var actionMaxWidth: CGFloat {
        isRegularWidth ? 420 : .infinity
    }

    private var horizontalPadding: CGFloat {
        isRegularWidth ? Theme.Space.xxl : Theme.Space.l
    }

    // MARK: - Full-bleed generated backdrop

    private var stepImageName: String {
        switch step {
        case 0: "OnboardingWelcome"
        case 1: "OnboardingInformational"
        case 2: "OnboardingMode"
        default: "OnboardingConfidence"
        }
    }

    private var backdrop: some View {
        ZStack {
            // Warm base so any letterboxing on unusual aspect ratios reads as
            // paper, never black.
            Theme.paper.ignoresSafeArea()

            Image(stepImageName)
                .resizable()
                .scaledToFill()
                .id(step)                       // crossfade between steps
                .transition(.opacity)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Legibility scrim: keep the image's calm top visible, lift the
            // lower area where the panel + Continue button sit. Warm, never grey.
            LinearGradient(
                colors: [
                    Theme.paper.opacity(0.30),
                    Theme.paper.opacity(0.05),
                    Theme.paper.opacity(0.45),
                    Theme.paper.opacity(0.88)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Theme.terracotta : Theme.stone.opacity(0.55))
                    .frame(width: i == step ? 24 : 12, height: 4)
                    .animation(.easeOut(duration: 0.25), value: step)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: disclaimerStep
        case 2: modeStep
        default: confidenceStep
        }
    }

    // MARK: - Reusable translucent panel ("widget background")

    /// Frosted warm panel that floats the copy/controls above the generated
    /// imagery so text keeps contrast. This is the per-widget background the
    /// redesign adds on top of the main image background.
    private func panel<Content: View>(
        alignment: HorizontalAlignment = .center,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: alignment, spacing: 14, content: content)
            .padding(22)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.paper.opacity(0.90))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Theme.terracotta.opacity(0.14), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.12), radius: 22, y: 10)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        panel {
            Text("HantaAtlas")
                .font(Theme.Fonts.heroWordmark)
                .foregroundStyle(Theme.graphite)

            Text("Officially-reported outbreak signals for Hantavirus, Ebola, or both.")
                .font(.title3.weight(.regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.graphiteSecondary)
                .lineSpacing(2)
                .padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Step 1: Informational only

    private var disclaimerStep: some View {
        panel(alignment: .leading) {
            Text("Informational only")
                .font(.title.weight(.medium))
                .foregroundStyle(Theme.graphite)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("HantaAtlas does not diagnose, predict, or treat. It does not score your risk. It is not for emergency use.")
                .font(.body)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                bullet(symbol: "checkmark.seal", text: "Every metric carries its source.")
                bullet(symbol: "calendar.badge.clock", text: "Every metric carries its date.")
                bullet(symbol: "phone.connection", text: "If you feel unwell, contact a doctor or local health authority.")
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Step 2: Disease mode

    private var modeStep: some View {
        panel {
            DiseaseModeMorphingCard(mode: selectedDiseaseMode)
                .frame(maxWidth: 320)

            Text("Choose what to track")
                .font(.title.weight(.medium))
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)

            Text("You can switch anytime. Each mode uses official sources, confidence labels, and source links.")
                .font(.body)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            DiseaseModeGlassControl(selection: diseaseSelection)
                .padding(.top, 2)

            Text("HantaAtlas does not diagnose, treat, predict personal risk, or provide emergency guidance.")
                .font(.footnote)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Step 3: Confidence

    private var confidenceStep: some View {
        panel(alignment: .leading) {
            Text("How confidence works")
                .font(.title.weight(.medium))
                .foregroundStyle(Theme.graphite)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Each country card tells you how it knows. Hold a card to see the source.")
                .font(.body)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(confidenceData.enumerated()), id: \.offset) { idx, data in
                    confidenceRow(color: data.color, symbol: data.symbol, label: data.label)
                        .transition(.opacity.combined(with: .offset(x: -20)))
                        .animation(.easeOut(duration: 0.4).delay(Double(idx) * 0.08), value: step)
                }
            }
            .padding(.top, 2)
        }
    }

    private var confidenceData: [(color: Color, symbol: String, label: String)] {
        [
            (Theme.moss,        "checkmark.shield.fill",  "Official structured data"),
            (Theme.terracotta,  "shield.lefthalf.filled", "Official alert"),
            (Theme.clay,        "newspaper.fill",         "Media signal"),
            (Theme.amber,       "number.square.fill",     "Counts can change"),
            (Theme.softGrey,    "circle.dashed",          "No recent public data")
        ]
    }

    private func bullet(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.olive)
                .font(.callout.weight(.semibold))
                .frame(width: 22)
            Text(text)
                .font(.callout)
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    private func confidenceRow(color: Color, symbol: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.callout.weight(.semibold))
                .frame(width: 22)
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.graphite)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Action buttons

    private var actions: some View {
        VStack(spacing: 10) {
            primaryButton
            legalLine
        }
    }

    /// Terms of Service + Privacy Policy, visible on every onboarding step and
    /// reachable before sign-in. Each opens the public page in Safari; the
    /// whole line also offers a chooser for larger hit targets / VoiceOver.
    private var legalLine: some View {
        HStack(spacing: 6) {
            Button { openURL(Self.termsURL) } label: {
                Text("Terms of Service")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Terms of Service")
            .accessibilityHint("Opens our Terms of Service in Safari")
            .accessibilityIdentifier("onboarding.termsLink")

            Text("·")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
                .accessibilityHidden(true)

            Button { openURL(Self.privacyURL) } label: {
                Text("Privacy Policy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Privacy Policy")
            .accessibilityHint("Opens our Privacy Policy in Safari")
            .accessibilityIdentifier("onboarding.privacyLink")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var primaryButton: some View {
        Button {
            advance()
        } label: {
            Text(primaryButtonTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Capsule())
                .background {
                    Capsule()
                        .fill(Theme.terracotta)
                        .shadow(color: Theme.terracotta.opacity(0.32), radius: 18, y: 8)
                        .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(primaryButtonTitle))
        .accessibilityIdentifier("onboarding.primaryButton")
    }

    private var primaryButtonTitle: String {
        "Continue"
    }

    private func advance() {
        if step >= 3 {
            withAnimation { hasCompleted = true }
        } else {
            withAnimation { step += 1 }
        }
    }

    private var selectedDiseaseMode: DiseaseMode {
        DiseaseMode(rawValue: selectedDiseaseModeRaw) ?? .both
    }

    private var diseaseSelection: Binding<DiseaseMode> {
        Binding(
            get: { selectedDiseaseMode },
            set: { selectedDiseaseModeRaw = $0.rawValue }
        )
    }
}

// MARK: - Disease mode preview card (kept — a content widget, not a glyph)

private struct DiseaseModeMorphingCard: View {
    let mode: DiseaseMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: mode.accentSymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(mode.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.feedLabel.uppercased())
                        .font(.caption2.weight(.heavy))
                        .tracking(1.0)
                        .foregroundStyle(Theme.graphiteSecondary)
                    Text(mode.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                morphingRow(symbol: "newspaper.fill", text: primaryRowText)
                morphingRow(symbol: "checkmark.shield.fill", text: "Confidence label attached")
                morphingRow(symbol: "link", text: linkRowText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bone.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(mode.tint.opacity(0.20), lineWidth: 1)
        }
        .contentTransition(.opacity)
        .id(mode)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title) mode preview")
    }

    private func morphingRow(symbol: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(mode.tint)
                .frame(width: 18)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var primaryRowText: String {
        switch mode {
        case .both: "Hanta and Ebola signals"
        case .hantavirus: "Public health signal"
        case .ebola: "WHO outbreak notice"
        }
    }

    private var linkRowText: String {
        switch mode {
        case .both: "Separate source trails"
        case .hantavirus: "Country source and limitations"
        case .ebola: "Affected areas and source date"
        }
    }
}

#Preview("Onboarding — light") {
    OnboardingView()
}

#Preview("Onboarding — dark") {
    OnboardingView()
        .preferredColorScheme(.dark)
}
