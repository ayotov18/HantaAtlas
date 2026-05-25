import SwiftUI
@preconcurrency import Translation

/// Renders a signal's title (or any text) translated to English on-device via
/// Apple's iOS 26 `Translation` framework. No API key, no network call —
/// translation happens locally using the language pair the user has downloaded
/// (the system prompts to download on first use, or runs immediately if
/// already cached).
///
/// Falls back to the original text when:
/// - source language is already English
/// - source language is not detected
/// - the on-device model isn't available for that pair
///
/// Used by the map's bottom hub and the artifact view to satisfy the user's
/// rule: "ALL the data/text on the map from the source track is in ENGLISH".
struct TranslatedSignalText: View {
    let original: String
    let sourceLanguage: String?
    let font: Font
    let lineLimit: Int?

    @State private var translated: String? = nil
    @State private var configuration: TranslationSession.Configuration? = nil

    init(_ original: String, sourceLanguage: String?, font: Font = .callout, lineLimit: Int? = nil) {
        self.original = original
        self.sourceLanguage = sourceLanguage
        self.font = font
        self.lineLimit = lineLimit
    }

    var body: some View {
        Text(translated ?? original)
            .font(font)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { triggerTranslation() }
            .translationTask(configuration) { session in
                // `@preconcurrency import Translation` opts the framework's
                // non-Sendable types out of Swift 6 strict checks for this
                // file — a known beta-period gap in Apple's annotations.
                guard translated == nil else { return }
                if let response = try? await session.translate(original) {
                    translated = response.targetText
                }
            }
    }

    private func triggerTranslation() {
        // Skip if source is already English or unknown.
        guard let lang = sourceLanguage?.lowercased(), lang != "en" else { return }
        guard configuration == nil else { return }
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: lang),
            target: Locale.Language(identifier: "en")
        )
    }
}
