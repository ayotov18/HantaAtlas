import SwiftUI

struct GuideView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var section: GuideSection = .prevention
    @State private var showInfo = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    ScreenHeader(
                        title: "\(preferences.selectedDiseaseMode.title) Guide",
                        subtitle: "Official prevention and care context"
                    ) {
                        Button {
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.graphite)
                        .background {
                            GlassChrome(cornerRadius: 18, interactive: true) {
                                Color.white.opacity(0.06).frame(width: 36, height: 36)
                            }
                        }
                        .accessibilityLabel("About this guide")
                    }
                    DiseaseModeSwitcher(preferences: preferences)
                    GuideCalloutCard(
                        title: "Informational only, not diagnosis",
                        message: "This guidance helps reduce risk. It does not replace medical care — consult a healthcare professional before making medical decisions."
                    )
                    sectionPicker
                    actionList
                    regionNote
                    officialGuidance
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, 56)
                .padding(.bottom, Theme.Space.huge)
            }
            .scrollIndicators(.hidden)
            LiquidGlassBackButton { dismiss() }
                .padding(.leading, Theme.Space.l)
                .padding(.top, 14)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showInfo) {
            GuideInfoSheet().presentationDetents([.medium])
        }
    }

    private var sectionPicker: some View {
        Picker("Guide section", selection: $section) {
            ForEach(GuideSection.allCases) { value in
                Text(value.title).tag(value)
            }
        }
        .pickerStyle(.segmented)
        .tint(Theme.moss)
        .accessibilityLabel("Guide section")
    }

    private var actionList: some View {
        VStack(spacing: 12) {
            let articles = repository.guideArticles(section: section)
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                GuideActionRow(
                    symbolName: article.symbolName,
                    title: article.title,
                    message: article.body,
                    tint: tint(for: section, index: index)
                )
            }
        }
    }

    private func tint(for section: GuideSection, index: Int) -> Color {
        switch section {
        case .prevention:
            let palette: [Color] = [Theme.moss, Theme.amber, Theme.olive, Theme.terracotta]
            return palette[index % palette.count]
        case .symptoms:
            return Theme.amber
        case .urgentCare:
            return Theme.terracotta
        }
    }

    private var regionNote: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: "globe", tint: Theme.moss, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("Region-specific note")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("\(preferences.selectedDiseaseMode.title) risk varies by region. Check your country page for the latest official updates.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                Text("View country")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.bone.opacity(0.8), in: Capsule())
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private var officialGuidance: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemName: "checkmark.shield.fill", tint: Theme.moss, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Official guidance")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("Based on official public health guidance.")
                    .font(.caption)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Circle().fill(Theme.moss).frame(width: 6, height: 6)
                    Text("High confidence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.graphite)
                }
                Text("Updated today")
                    .font(.caption2)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }
}

private struct GuideInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    Text("About this guide")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("Guidance is summarised from official public health authorities. It does not replace medical care or country-specific public-health advice — consult a healthcare professional before making medical decisions.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.graphiteSecondary)
                    AboutDataCard(
                        title: "Where this comes from",
                        message: "Each item is based on official public health guidance from sources such as CDC, ECDC, PAHO, WHO, and Africa CDC."
                    )
                }
                .padding(Theme.Space.l)
            }
            .background(ScreenBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Guide — light") {
    NavigationStack {
        GuideView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
}

#Preview("Guide — dark") {
    NavigationStack {
        GuideView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
    .preferredColorScheme(.dark)
}

#Preview("Guide — XXXL text") {
    NavigationStack {
        GuideView(repository: SurveillanceRepository(), preferences: LocalPreferences())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
