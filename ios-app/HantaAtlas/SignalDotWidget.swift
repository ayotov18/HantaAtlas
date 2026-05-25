import SwiftUI

/// Two distinct Views — compact and expanded — that share a `glassEffectID`
/// inside a `GlassEffectContainer` to get the iOS 26 native morph between
/// them. The morph itself is driven by SwiftUI's matched-geometry transition,
/// not opacity.
///
/// Why not one View with internal `isExpanded` state? Because `glassEffectID`
/// needs two distinct view identities to morph between — a single view that
/// changes size only animates its frame, not the glass shape. Apple's
/// canonical morph pattern (Music mini-player → expanded player) uses the
/// same two-View structure.
///
/// Perf notes:
///  - The Compact view shows the ORIGINAL signal title (no Translation framework
///    spin-up). Translation only kicks in when the user expands. This avoids
///    the FPS-zero hitch on first widget open.
///  - `.glassEffect()` is applied AFTER `.frame()` and `.padding()` so the glass
///    shape uses the final laid-out bounds.

// MARK: - Compact

struct SignalDotWidgetCompact: View {
    let signal: Signal
    let postType: MapPostType
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Self.header(signal: signal, postType: postType, onClose: onClose)
            Divider().background(Color.white.opacity(0.10))
                .padding(.horizontal, 14)
            VStack(alignment: .leading, spacing: 6) {
                metaRow
                // Plain Text — fast first paint. Translation deferred to the
                // expanded state to avoid blocking the morph.
                Text(signal.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                tapHint
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: 280)
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(signal.sourceBucket)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.4)
            Text("·").foregroundStyle(.white.opacity(0.30))
            Text(timeAgo(signal.publishedAt))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            if signal.isInForeignLanguage, let lang = signal.detectedLanguage {
                Text("·").foregroundStyle(.white.opacity(0.30))
                Text("\(lang.uppercased()) → EN")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
    }

    private var tapHint: some View {
        HStack(spacing: 4) {
            Text("Tap to expand")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.50))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.50))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Expanded

struct SignalDotWidgetExpanded: View {
    let signal: Signal
    let postType: MapPostType
    let onClose: () -> Void
    let onReadFull: () -> Void
    let onOpenSource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SignalDotWidgetCompact.header(signal: signal, postType: postType, onClose: onClose)
            Divider().background(Color.white.opacity(0.10))
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 8) {
                metaRow
                // Translation only fires when expanded — this is where it
                // matters and where the user is willing to wait.
                TranslatedSignalText(
                    signal.title,
                    sourceLanguage: signal.detectedLanguage,
                    font: .callout.weight(.semibold),
                    lineLimit: nil
                )
                .foregroundStyle(.white)

                if let summary = signal.summary, !summary.isEmpty {
                    TranslatedSignalText(
                        summary,
                        sourceLanguage: signal.detectedLanguage,
                        font: .footnote,
                        lineLimit: nil
                    )
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 2)
                }

                actionsRow
                    .padding(.top, 6)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: 320)
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(signal.sourceBucket)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.4)
            Text("·").foregroundStyle(.white.opacity(0.30))
            Text(timeAgo(signal.publishedAt))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button(action: onOpenSource) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                    Text("Source")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onReadFull) {
                HStack(spacing: 6) {
                    Text("Read full")
                        .font(.caption.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Color.white.opacity(0.92), in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Spatial source stack

struct SpatialSourceItem: Identifiable, Equatable {
    let id: String
    let signal: Signal
    let postType: MapPostType
    let isPrimary: Bool
}

struct SpatialSourceStackView: View {
    let items: [SpatialSourceItem]
    let onClose: () -> Void
    let onSelect: (SpatialSourceItem) -> Void

    @State private var hasResolved = false

    var body: some View {
        ZStack(alignment: .bottom) {
            stemAndAnchor

            if let item = items.first {
                sourcePlaque(item: item)
                    .frame(width: 302, alignment: .leading)
                    .offset(y: hasResolved ? -48 : -18)
                    .opacity(hasResolved ? 1 : 0)
            }
        }
        .frame(width: 318, height: 224)
        .onAppear { resolve() }
        .onChange(of: items) { _, _ in resolve() }
        .accessibilityElement(children: .contain)
    }

    private var stemAndAnchor: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.terracotta.opacity(0.0),
                            Theme.terracotta.opacity(0.45),
                            Theme.terracotta.opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: hasResolved ? 64 : 12)
                .shadow(color: Theme.terracotta.opacity(0.45), radius: 12)

            ZStack {
                Circle()
                    .fill(Theme.terracotta.opacity(0.16))
                    .frame(width: hasResolved ? 54 : 26, height: hasResolved ? 54 : 26)
                Circle()
                    .strokeBorder(Theme.terracotta.opacity(0.70), lineWidth: 2)
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(Theme.terracotta)
                    .frame(width: 12, height: 12)
            }
            .shadow(color: Theme.terracotta.opacity(0.35), radius: 18)
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.82), value: hasResolved)
    }

    private func sourcePlaque(item: SpatialSourceItem) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(item.postType.mapColor.opacity(0.28))
                    Image(systemName: symbolName(for: item.postType))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(item.postType.mapColor)
                }
                .frame(width: 34, height: 42)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(item.postType.title.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(item.postType.mapColor)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(.white.opacity(0.28))
                        Text(item.signal.severity.title.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.86))
                        if let iso = item.signal.countryISO {
                            Text("·")
                                .foregroundStyle(.white.opacity(0.28))
                            Text(iso)
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.6)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }

                    Text(item.signal.sourceBucket + " · " + timeAgo(item.signal.publishedAt))
                        .font(.caption2.weight(.bold))
                        .tracking(0.3)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)

                    Text(item.signal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .padding(.trailing, 24)
            .frame(width: 302, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(Color.black.opacity(0.58))
                    .shadow(color: item.postType.mapColor.opacity(0.24), radius: 26, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .rotation3DEffect(
                .degrees(-2),
                axis: (x: 1.0, y: -0.45, z: 0.0),
                perspective: 0.62
            )
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .onTapGesture { onSelect(item) }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("\(item.postType.title), \(item.signal.sourceBucket), \(item.signal.title)"))

            closeButton
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.48), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(hasResolved ? 1 : 0)
        .accessibilityLabel(Text("Close source stack"))
    }

    private func resolve() {
        hasResolved = false
        Task { @MainActor in
            await Task.yield()
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                hasResolved = true
            }
        }
    }

    private func symbolName(for postType: MapPostType) -> String {
        switch postType {
        case .death:
            "cross.case.fill"
        case .caseConfirmed:
            "checkmark.seal.fill"
        case .caseSuspected:
            "questionmark.circle.fill"
        case .caseImported:
            "airplane.arrival"
        case .officialResponse:
            "checkmark.shield.fill"
        case .expertVoice:
            "waveform.path.ecg"
        case .publicDiscourse:
            "newspaper.fill"
        }
    }
}

// MARK: - Shared header

extension SignalDotWidgetCompact {
    static func header(signal: Signal, postType: MapPostType, onClose: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(postType.mapColor)
                .frame(width: 4, height: 22)
                .padding(.leading, 2)
            Text(postType.title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(postType.mapColor)
            Text("·").foregroundStyle(.white.opacity(0.30))
            Text(signal.severity.title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.85))
            if let iso = signal.countryISO {
                Text("·").foregroundStyle(.white.opacity(0.30))
                Text(iso)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 6)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
    }
}

// MARK: - Time helper

private func timeAgo(_ date: Date) -> String {
    let mins = max(0, Int(Date().timeIntervalSince(date) / 60))
    if mins < 1 { return "just now" }
    if mins < 60 { return "\(mins)m ago" }
    if mins < 60 * 24 { return "\(mins / 60)h ago" }
    return "\(mins / 1440)d ago"
}

// MARK: - Smart positioning helper

struct WidgetPosition {
    let point: CGPoint
    let pointerSide: PointerSide
    enum PointerSide { case top, bottom }

    static func smart(
        dotScreenPoint dot: CGPoint,
        screenSize: CGSize,
        widgetSize: CGSize,
        topSafeArea: CGFloat = 80,
        bottomSafeArea: CGFloat = 200,
        horizontalMargin: CGFloat = 14
    ) -> WidgetPosition {
        let spaceAbove = dot.y - topSafeArea
        let needAbove = widgetSize.height + 22
        let placeAbove = spaceAbove >= needAbove

        let centerY: CGFloat
        let pointerSide: PointerSide
        if placeAbove {
            centerY = dot.y - widgetSize.height / 2 - 18
            pointerSide = .bottom
        } else {
            centerY = dot.y + widgetSize.height / 2 + 18
            pointerSide = .top
        }

        var centerX = dot.x
        let half = widgetSize.width / 2
        let minX = half + horizontalMargin
        let maxX = screenSize.width - half - horizontalMargin
        if maxX > minX {
            centerX = max(minX, min(maxX, centerX))
        }
        return WidgetPosition(
            point: CGPoint(x: centerX, y: centerY),
            pointerSide: pointerSide
        )
    }
}
