import SwiftUI
import Translation

/// Full-bleed "artifact" detail for a single Signal. Pushed onto the stack
/// from the live Feed. Liquid Glass back button hovers over a confidence-tinted
/// hero. The title, source, country, time, severity, and full summary are all
/// shown, plus an outbound link to the original publisher (5.2.x compliance:
/// always cite + link to source, never reproduce full article body).
///
/// Tap-to-translate uses the iOS 26 Translation framework presentation modal —
/// on-device, no API key, no network call.
struct SignalArtifactView: View {
    let signal: Signal
    @Environment(\.dismiss) private var dismiss
    @State private var translatingText: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            ScreenBackground()
            ScrollView {
                ZStack(alignment: .top) {
                    hero
                    VStack(spacing: 0) {
                        Spacer().frame(height: 220)
                        content
                    }
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            chromeOverlay
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .translationPresentation(
            isPresented: Binding(
                get: { translatingText != nil },
                set: { if !$0 { translatingText = nil } }
            ),
            text: translatingText ?? ""
        )
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            LinearGradient(
                colors: [
                    severityTint.opacity(0.55),
                    severityTint.opacity(0.20),
                    Theme.paper
                ],
                startPoint: .topLeading, endPoint: .bottom
            )
            .frame(height: 280)

            VStack(spacing: 6) {
                Spacer().frame(height: 60)
                if let iso = signal.countryISO {
                    Text(flagEmoji(for: iso))
                        .font(.system(size: 56))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(signal.severity.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(severityTint.opacity(0.85), in: Capsule())
                Spacer()
            }

            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Theme.paper.opacity(0.85), Theme.paper],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
            }
            .frame(height: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: 280)
        .clipped()
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            metadataRow
            titleCard
            if let summary = signal.summary, !summary.isEmpty {
                summaryCard(summary)
            }
            if signal.isInForeignLanguage {
                translatePromptCard
            }
            sourceCard
            disclaimerCard
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.huge)
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Text(signal.sourceBucket)
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(Theme.graphiteSecondary)
            Text("·").foregroundStyle(Theme.softGrey)
            Text(formatted(signal.publishedAt))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
            if let iso = signal.countryISO {
                Text("·").foregroundStyle(Theme.softGrey)
                Text(iso)
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Theme.bone, in: Capsule())
                    .foregroundStyle(Theme.graphite)
            }
            Spacer()
        }
    }

    private var titleCard: some View {
        TranslatedSignalText(
            signal.title,
            sourceLanguage: signal.detectedLanguage,
            font: .title2.weight(.bold),
            lineLimit: nil
        )
        .foregroundStyle(Theme.graphite)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMARY")
                .font(.caption2.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.graphiteSecondary)
            TranslatedSignalText(
                summary,
                sourceLanguage: signal.detectedLanguage,
                font: .body,
                lineLimit: nil
            )
            .foregroundStyle(Theme.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private var translatePromptCard: some View {
        Button {
            translatingText = signal.title + (signal.summary.map { "\n\n\($0)" } ?? "")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.olive, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Translate")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    if let lang = signal.detectedLanguage {
                        Text("From \(Locale.current.localizedString(forLanguageCode: lang) ?? lang.uppercased()) — on-device, by Apple Translate")
                            .font(.caption)
                            .foregroundStyle(Theme.graphiteSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(cornerRadius: Theme.Radius.card, padding: 12)
        }
        .buttonStyle(.plain)
    }

    private var sourceCard: some View {
        Button {
            UIApplication.shared.open(signal.url)
        } label: {
            HStack(spacing: 14) {
                IconTile(systemName: "arrow.up.right.square", tint: Theme.softGrey, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open at source")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                    Text(signal.url.host ?? signal.url.absoluteString)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Opens in Safari")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Theme.softGrey)
                Text("Informational only")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
            }
            Text("Headlines are reproduced under fair use as part of public-health surveillance. HantaAtlas does not edit, rewrite, or rank for sensational content. Tap \"Open at source\" to read the full article from the original publisher. Not for emergency use.")
                .font(.footnote)
                .foregroundStyle(Theme.graphiteSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    // MARK: - Chrome

    private var chromeOverlay: some View {
        HStack {
            LiquidGlassBackButton { dismiss() }
            Spacer()
            ShareLink(item: signal.url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.graphite)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Share signal")
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, 14)
    }

    // MARK: - Helpers

    private var severityTint: Color {
        switch signal.severity {
        case .high: return Theme.terracotta
        case .medium: return Theme.amber
        case .low: return Theme.olive
        }
    }

    private func flagEmoji(for iso: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in iso.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.append(String(scalar))
            }
        }
        return s.isEmpty ? "🌍" : s
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
