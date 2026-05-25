import SwiftUI

struct SourceTransparencyView: View {
    var diseaseMode: DiseaseMode = .both
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    ScreenHeader(
                        title: "Source Transparency",
                        subtitle: "\(diseaseMode.title): what has been officially reported, where, when, and by whom"
                    )
                    confidenceCard
                    completenessCard
                    modeCard
                    supportCard
                    PaywallCard()
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
        .navigationTitle("About the data")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Confidence labels")
            VStack(spacing: 12) {
                ForEach(ConfidenceLevel.allCases) { level in
                    HStack(alignment: .top, spacing: 14) {
                        IconTile(systemName: level.symbolName, tint: level.tint, size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.graphite)
                            Text(level.explanation)
                                .font(.subheadline)
                                .foregroundStyle(Theme.graphiteSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 16)
    }

    private var completenessCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: "info.circle.fill", tint: Theme.softGrey, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("Global completeness is not implied")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("Map colours represent public source confidence for \(diseaseMode.title), not true prevalence. No recent public data is not the same as zero cases.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private var modeCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(systemName: diseaseMode.accentSymbol, tint: Theme.terracotta, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(diseaseMode.title) mode")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Text("This mode prioritizes \(diseaseMode.sourceFocus), official notices, source dates, case classification limits, and public-health methodology over raw social chatter.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }

    private var supportCard: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemName: "envelope.fill", tint: Theme.olive, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Support and methodology")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                Link("Contact support", destination: URL(string: "https://example.com/hantaatlas-support")!)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.moss)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.graphiteSecondary)
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 14)
    }
}

struct PaywallCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconTile(systemName: "checkmark.seal.fill", tint: Theme.olive, size: 40)
                Text("Source transparency is included")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.graphite)
            }
            Text("HantaAtlas is free and no account is required. Source notes, limitations, and official links stay available to everyone.")
                .font(.subheadline)
                .foregroundStyle(Theme.graphiteSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(Theme.olive)
                Text("No purchase needed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
            }
        }
        .paperCard(cornerRadius: Theme.Radius.card, padding: 16)
    }
}

#Preview {
    NavigationStack {
        SourceTransparencyView()
    }
}
