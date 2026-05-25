import SwiftUI

/// Tinder-style swipe deck for catching up on outbreak signals.
///
/// Presented as a full-screen cover from the Feed tab's "Catch up" FAB.
/// One card per signal. Swipe gestures map to lightweight curation:
///
///   • Swipe RIGHT → Save for later (terracotta panel)
///   • Swipe LEFT  → Mark seen (olive panel)
///   • Swipe UP    → Open source in Safari (clay panel)
///   • Swipe DOWN  → Mute country for 24h (soft-grey panel)
///   • Tap centre  → Push the full SignalArtifactView
///
/// State is fully on-device: `LocalPreferences.seenSignalIDs` and
/// `mutedCountriesUntil` (24h TTL). No backend involvement.
///
/// When the queue is exhausted, an "All caught up" completion mark animates in
/// using hand-built vector linework in the warm palette.
struct SwipeFeedView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences
    /// Called when the deck is fully caught up. The host (OutbreakFeedView via
    /// ContentView) uses this to dismiss the full-screen cover and switch the
    /// parent TabView back to the Today tab — closing the loop instead of
    /// stranding the user on a dead-end empty state.
    var onCaughtUp: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var deck: [Signal] = []
    @State private var currentIndex: Int = 0
    @State private var hasBuiltInitialQueue: Bool = false
    @State private var topCardOffset: CGSize = .zero
    @State private var pushedArtifact: Signal? = nil
    @State private var allCaughtUp: Bool = false
    @State private var completedBySwiping: Bool = false
    @State private var showFilters: Bool = false
    @State private var reviewedThisSession: Int = 0
    /// Guards `returnHome` so the auto-return task and the Continue button
    /// each trigger the return-to-Today exactly once.
    @State private var didReturnHome = false
    @State private var hasTriggeredHaptic: Bool = false
    /// Drives the completion mark + cascaded text fades on the caught-up
    /// scene. Flipped on first appear of that scene.
    @State private var caughtUpAppeared: Bool = false
    /// Bumped each time the real completion scene appears. Keeps the
    /// auto-return task one-shot and tied to the current completion state.
    @State private var caughtUpRunID = UUID()
    @State private var isResolvingTopCard = false

    private let dragDismissThreshold: CGFloat = 110
    private let deckFetchLimit = 250

    /// 0..1 — how far the user has dragged toward the dismiss threshold,
    /// used to drive both the edge-action panel opacity and the peek/lift
    /// animation on the cards behind the top one.
    private var dragFraction: CGFloat {
        let m = max(abs(topCardOffset.width), abs(topCardOffset.height))
        return min(1, m / dragDismissThreshold)
    }

    private var remainingCount: Int {
        max(0, deck.count - currentIndex)
    }

    private var currentSignal: Signal? {
        guard currentIndex >= 0, currentIndex < deck.count else { return nil }
        return deck[currentIndex]
    }

    private var upcomingSignals: [Signal] {
        guard currentIndex + 1 < deck.count else { return [] }
        return Array(deck.dropFirst(currentIndex + 1).prefix(2))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                if !hasBuiltInitialQueue {
                    preparingScene
                } else if allCaughtUp || remainingCount == 0 {
                    caughtUpScene
                } else {
                    cardScene
                }

                topChrome
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $pushedArtifact) { signal in
                SignalArtifactView(signal: signal)
            }
            .sheet(isPresented: $showFilters) {
                SwipeFiltersSheet(preferences: preferences) {
                    Task { @MainActor in
                        await rebuildQueue()
                        showFilters = false
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if !hasBuiltInitialQueue {
                    Task { @MainActor in await rebuildQueue() }
                }
            }
            .onChange(of: repository.signals.count) { _, _ in
                guard hasBuiltInitialQueue, remainingCount == 0, !completedBySwiping else { return }
                Task { @MainActor in await rebuildQueue() }
            }
            .onChange(of: preferences.selectedDiseaseMode) { _, _ in
                Task { @MainActor in
                    await repository.refresh(preferences: preferences)
                    await rebuildQueue()
                }
            }
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.graphite)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close catch-up")

                Spacer()

                VStack(spacing: 2) {
                    Text("Catch up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("\(preferences.selectedDiseaseMode.title) · \(remainingCount) left · \(reviewedThisSession) reviewed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                        .monospacedDigit()
                }

                Spacer()

                Button { showFilters = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.graphite)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Filters")
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            DiseaseModeSwitcher(preferences: preferences, compact: true)
                .frame(maxWidth: 320)
                .padding(.top, 8)
                .padding(.horizontal, 18)

            Spacer()
        }
    }

    // MARK: - Card stack

    private var cardScene: some View {
        ZStack {
            // Edge action panels — fade in as the user drags toward each.
            actionPanel(.save, alignment: .leading, progress: rightProgress)
            actionPanel(.seen, alignment: .trailing, progress: leftProgress)
            actionPanel(.openSource, alignment: .top, progress: upProgress)
            actionPanel(.mute, alignment: .bottom, progress: downProgress)

            // Cards rendered back-to-front. CRITICAL split: the top card has
            // NO implicit `.animation` modifier — putting one on it installs a
            // transaction that pulls the live `.offset(topCardOffset)` reads
            // through the spring, which is exactly the lag the user
            // complained about. Reference: Fatbobman, "Mastering Transaction"
            // — fatbobman.com/en/posts/mastering-transaction/. The top card
            // tracks the finger 1:1; behind cards keep the spring on their
            // dragFraction-derived peek/lift.
            behindCards
            topCard

            // Reduce-Motion alternative: button row overlaid at the bottom
            if reduceMotion, let top = currentSignal {
                VStack {
                    Spacer()
                    reduceMotionButtonRow(for: top)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    @ViewBuilder
    private var behindCards: some View {
        ForEach(Array(upcomingSignals.enumerated()), id: \.element.id) { offset, signal in
            // depth 1 is directly behind the top card, depth 2 sits further
            // back. We index from 1 so depth 0 is reserved for the top card.
            let depth = offset + 1
            cardView(signal: signal, depth: depth)
                .zIndex(Double(3 - depth))
                .padding(.horizontal, 22)
                .padding(.top, 132)
                .padding(.bottom, 110)
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: dragFraction)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var topCard: some View {
        if let signal = currentSignal {
            cardView(signal: signal, depth: 0)
                .offset(topCardOffset)
                .rotationEffect(
                    .degrees(max(-9, min(9, Double(topCardOffset.width) / 22))),
                    anchor: .bottom
                )
                .zIndex(3)
                .padding(.horizontal, 22)
                .padding(.top, 132)
                .padding(.bottom, 110)
                .gesture(dragGesture(for: signal))
                // Tap + drag must coexist on the same view. Apple's "Composing
                // SwiftUI Gestures" doc spells out that DragGesture suppresses
                // bare .onTapGesture below its threshold; .simultaneousGesture
                // resolves both: tap is recognised when the touch ends without
                // crossing the drag's minimumDistance.
                .simultaneousGesture(
                    TapGesture().onEnded { pushedArtifact = signal }
                )
                // Stable identity per signal. Without this the next card reuses
                // the resolved card's view while `topCardOffset` is still at the
                // swipe-exit position, so it animates IN from the swipe-out edge
                // — which read as "the previous post slides back". A fresh
                // identity mounts the next card centred (offset already reset to
                // .zero in the resolve completion).
                .id(signal.id)
        }
    }

    private func cardView(signal: Signal, depth: Int) -> some View {
        // Behind-card peek/lift: as the top card drags away (dragFraction
        // goes 0 → 1), behind cards scale up toward 1.0 and slide forward.
        // This is the "stack feels alive" cue — without it the queue looks
        // static and the swipe feels cheap.
        let restScale: CGFloat = 1.0 - (CGFloat(depth) * 0.04)
        let restY: CGFloat = CGFloat(depth) * 8
        let peekScale = restScale + (1.0 - restScale) * dragFraction
        let peekY = restY * (1 - dragFraction)
        let scale = depth == 0 ? 1.0 : peekScale
        let yShift = depth == 0 ? 0 : peekY
        let isTopCard = depth == 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(flagEmoji(for: signal.countryISO ?? "🌍"))
                    .font(.system(size: 24))
                if let iso = signal.countryISO {
                    Text(iso)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.bone, in: Capsule())
                        .foregroundStyle(Theme.graphite)
                }
                Spacer()
                postTypeBadge(signal: signal)
            }

            if isTopCard, let media = signal.primaryMedia {
                SignalMediaPreview(media: media)
            }

            if isTopCard {
                TranslatedSignalText(
                    signal.title,
                    sourceLanguage: signal.detectedLanguage,
                    font: .system(size: signal.primaryMedia == nil ? 26 : 24, weight: .heavy, design: .rounded),
                    lineLimit: signal.primaryMedia == nil ? nil : 4
                )
                .foregroundStyle(Theme.graphite)

                if let summary = signal.summary, !summary.isEmpty {
                    TranslatedSignalText(
                        summary,
                        sourceLanguage: signal.detectedLanguage,
                        font: .body,
                        lineLimit: signal.primaryMedia == nil ? 4 : 3
                    )
                    .foregroundStyle(Theme.graphiteSecondary)
                    .lineSpacing(2)
                }
            } else {
                Text(signal.title)
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(3)
            }

            Spacer()

            HStack {
                Text(signal.sourceBucket)
                    .font(.caption2.weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(Theme.graphiteSecondary)
                Text("·").foregroundStyle(Theme.softGrey)
                Text(timeAgo(signal.publishedAt))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Theme.graphiteSecondary.opacity(0.5))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.66)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .scaleEffect(scale)
        .offset(y: yShift)
    }

    private func postTypeBadge(signal: Signal) -> some View {
        let type = signal.mapPostType
        return HStack(spacing: 4) {
            Circle().fill(type.mapColor).frame(width: 7, height: 7)
            Text(type.title.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(type.mapColor)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(type.mapColor.opacity(0.10), in: Capsule())
    }

    private struct SignalMediaPreview: View {
        let media: SignalMedia

        private var displayURL: URL {
            media.thumbnailUrl ?? media.url
        }

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: displayURL, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        fallback
                            .overlay {
                                ProgressView()
                                    .tint(Theme.terracotta)
                            }
                    @unknown default:
                        fallback
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .clipped()
                .background(Theme.bone.opacity(0.72))

                HStack(spacing: 7) {
                    if media.type != .image {
                        Image(systemName: "play.fill")
                            .font(.caption2.weight(.heavy))
                    }
                    Text(media.provider ?? "source media")
                        .font(.caption2.weight(.heavy))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.48), in: Capsule())
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.66)
            )
            .accessibilityLabel(media.type == .image ? "Source image preview" : "Source media preview")
        }

        private var fallback: some View {
            ZStack {
                LinearGradient(
                    colors: [Theme.bone.opacity(0.95), Theme.oat.opacity(0.66)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: media.type == .image ? "photo" : "play.rectangle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.graphiteSecondary.opacity(0.52))
            }
        }
    }

    // MARK: - Edge action panels (fade in during drag)

    private enum CardAction { case save, seen, openSource, mute }

    private func actionPanel(_ action: CardAction, alignment: Alignment, progress: CGFloat) -> some View {
        let (label, symbol, tint) = panelMeta(action)
        return VStack {
            if alignment == .top {
                Spacer().frame(height: 100)
                panel(label: label, symbol: symbol, tint: tint, progress: progress)
                Spacer()
            } else if alignment == .bottom {
                Spacer()
                panel(label: label, symbol: symbol, tint: tint, progress: progress)
                Spacer().frame(height: 110)
            } else {
                HStack {
                    if alignment == .leading {
                        panel(label: label, symbol: symbol, tint: tint, progress: progress)
                        Spacer()
                    } else {
                        Spacer()
                        panel(label: label, symbol: symbol, tint: tint, progress: progress)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panel(label: String, symbol: String, tint: Color, progress: CGFloat) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .heavy))
            Text(label.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1.0)
        }
        .foregroundStyle(tint)
        .padding(20)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(Double(min(1, max(0, progress))))
        .padding(.horizontal, 12)
    }

    private func panelMeta(_ action: CardAction) -> (String, String, Color) {
        switch action {
        case .save:        return ("Save", "bookmark.fill", Theme.terracotta)
        case .seen:        return ("Seen", "checkmark.circle.fill", Theme.olive)
        case .openSource:  return ("Open source", "arrow.up.right.square.fill", Theme.clay)
        case .mute:        return ("Mute country", "bell.slash.fill", Theme.softGrey)
        }
    }

    private var rightProgress: CGFloat { topCardOffset.width / dragDismissThreshold }
    private var leftProgress: CGFloat { -topCardOffset.width / dragDismissThreshold }
    private var upProgress: CGFloat { -topCardOffset.height / dragDismissThreshold }
    private var downProgress: CGFloat { topCardOffset.height / dragDismissThreshold }

    // MARK: - Reduce-Motion button row

    private func reduceMotionButtonRow(for signal: Signal) -> some View {
        HStack(spacing: 10) {
            actionButton(symbol: "checkmark", tint: Theme.olive, label: "Seen") {
                resolveTopCard(.seen, signal: signal)
            }
            actionButton(symbol: "bookmark.fill", tint: Theme.terracotta, label: "Save") {
                resolveTopCard(.save, signal: signal)
            }
            actionButton(symbol: "arrow.up.right.square.fill", tint: Theme.clay, label: "Source") {
                resolveTopCard(.openSource, signal: signal)
            }
            actionButton(symbol: "bell.slash.fill", tint: Theme.softGrey, label: "Mute") {
                resolveTopCard(.mute, signal: signal)
            }
        }
    }

    private func actionButton(symbol: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.body.weight(.bold))
                Text(label).font(.caption2.weight(.heavy))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Drag gesture

    private func dragGesture(for signal: Signal) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                // No animation here — track the finger 1:1. Implicit
                // .interactiveSpring on the card smooths it.
                topCardOffset = value.translation

                // Haptic at threshold cross — fires once on entry, resets on exit.
                let frac = dragFraction
                if !hasTriggeredHaptic && frac > 0.95 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    hasTriggeredHaptic = true
                } else if hasTriggeredHaptic && frac < 0.85 {
                    hasTriggeredHaptic = false
                }
            }
            .onEnded { value in
                hasTriggeredHaptic = false
                // Use predictedEndLocation for velocity-aware decisions:
                // a fast flick past the threshold should commit even if the
                // raw translation hasn't crossed it yet.
                let predicted = value.predictedEndTranslation
                let pdx = predicted.width
                let pdy = predicted.height
                let pAbs = max(abs(pdx), abs(pdy))
                let dx = value.translation.width
                let dy = value.translation.height
                let absX = abs(dx)
                let absY = abs(dy)

                // Commit either (a) past threshold, or (b) fast flick that
                // would land past threshold given current velocity.
                let shouldCommit = max(absX, absY) > dragDismissThreshold || pAbs > dragDismissThreshold * 1.6
                guard shouldCommit else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        topCardOffset = .zero
                    }
                    return
                }

                // Direction by predicted motion (velocity-aware) so a fast
                // diagonal flick still commits to the dominant axis cleanly.
                let action: CardAction
                if abs(pdx) > abs(pdy) {
                    action = pdx > 0 ? .save : .seen
                } else {
                    action = pdy < 0 ? .openSource : .mute
                }
                resolveTopCard(action, signal: signal)
            }
    }

    // MARK: - Resolution

    private func resolveTopCard(_ action: CardAction, signal: Signal) {
        guard !isResolvingTopCard else { return }
        isResolvingTopCard = true

        // Apply the side effect first so state is consistent during the
        // off-screen animation.
        switch action {
        case .save:
            preferences.markSeen(signal.id)
            if let iso = signal.countryISO, !preferences.isFollowing(iso) {
                // Saving a country is a profile action — gate behind sign-in.
                // markSeen above stays local/ungated so the swipe still resolves.
                AuthGate.shared.require { preferences.toggleSaved(iso) }  // normalises casing
            }
        case .seen:
            preferences.markSeen(signal.id)
        case .openSource:
            openURL(signal.url)
            preferences.markSeen(signal.id)
        case .mute:
            if let iso = signal.countryISO {
                preferences.muteCountry(iso, hours: 24)
            }
            preferences.markSeen(signal.id)
        }
        reviewedThisSession += 1

        // Off-screen direction. ~600pt past edge so cards never re-enter
        // even on iPad-sized screens.
        let offset: CGSize = {
            switch action {
            case .save:       return CGSize(width: 700, height: 0)
            case .seen:       return CGSize(width: -700, height: 0)
            case .openSource: return CGSize(width: 0, height: -900)
            case .mute:       return CGSize(width: 0, height: 900)
            }
        }()

        // iOS 17+ logicallyComplete completion driver — replaces the
        // brittle DispatchQueue.asyncAfter timing. The completion fires
        // when the spring settles (logically — visually it's already
        // off-screen well before it fully settles).
        withAnimation(
            reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 0.78),
            completionCriteria: .logicallyComplete
        ) {
            topCardOffset = offset
        } completion: {
            // Reset the offset and advance the index together, with animation
            // disabled, so the next card (fresh `.id`) mounts centred instead of
            // sliding in from the resolved card's exit edge.
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                topCardOffset = .zero
                if currentSignal?.id == signal.id {
                    currentIndex += 1
                } else if let resolvedIndex = deck.firstIndex(where: { $0.id == signal.id }) {
                    currentIndex = max(currentIndex, resolvedIndex + 1)
                }
            }
            isResolvingTopCard = false
            if remainingCount == 0 {
                completedBySwiping = reviewedThisSession > 0
                caughtUpAppeared = false
                caughtUpRunID = UUID()
                withAnimation(.easeOut(duration: 0.30)) {
                    allCaughtUp = true
                }
            }
        }
    }

    // MARK: - Completion scenes

    private var preparingScene: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.terracotta)
            Text("Preparing your queue")
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.graphite)
            Text("Finding unread official signals")
                .font(.subheadline)
                .foregroundStyle(Theme.graphiteSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var caughtUpScene: some View {
        VStack(spacing: 16) {
            Spacer()

            CatchUpCompletionMark(isActive: caughtUpAppeared)
                .frame(width: 132, height: 132)
                .opacity(caughtUpAppeared ? 1 : 0)
                .scaleEffect(caughtUpAppeared ? 1 : 0.96)
                .animation(reduceMotion ? .none : .smooth(duration: 0.42), value: caughtUpAppeared)
                .accessibilityHidden(true)

            Text(completedBySwiping ? "All caught up" : "Nothing to catch up")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.graphite)
                .opacity(caughtUpAppeared ? 1 : 0)
                .offset(y: caughtUpAppeared ? 0 : 6)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.40).delay(0.20), value: caughtUpAppeared)

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("\(reviewedThisSession)")
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.snappy, value: reviewedThisSession)
                    Text("signal\(reviewedThisSession == 1 ? "" : "s") reviewed")
                }
                .font(.title3)

                Text(completionSubtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.graphiteSecondary)
            .opacity(caughtUpAppeared ? 1 : 0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.40).delay(0.32), value: caughtUpAppeared)

            Spacer()

            VStack(spacing: 10) {
                Button { returnHome() } label: {
                    Text(completedBySwiping ? "Continue" : "Back to Today")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.terracotta, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(completedBySwiping ? "Continue to Today" : "Back to Today")

                if !completedBySwiping {
                    Button {
                        showFilters = true
                    } label: {
                        Text("Adjust filters")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.graphite)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Theme.bone, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Adjust catch-up filters")
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .opacity(caughtUpAppeared ? 1 : 0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.40).delay(0.45), value: caughtUpAppeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: caughtUpRunID) {
            guard hasBuiltInitialQueue else { return }
            // Trigger the staggered reveal on first appear of this scene.
            caughtUpAppeared = true
            guard completedBySwiping else { return }
            // Auto-return to Today only after a real completed swipe session.
            // This prevents the initial "queue is still being built" frame
            // from starting a stale dismiss task that later closes a story.
            try? await Task.sleep(for: .seconds(reduceMotion ? 1.4 : 2.4))
            guard !Task.isCancelled, allCaughtUp, completedBySwiping else { return }
            returnHome()
        }
    }

    /// Shows a watchable interstitial after the catch-up animation, then hands
    /// control back to the parent (which returns the user to Today).
    private func returnHome() {
        guard !didReturnHome else { return }
        didReturnHome = true
        onCaughtUp()
    }

    private var completionSubtitle: String {
        if completedBySwiping {
            "Returning to Today with your feed cleared."
        } else {
            "No unread signals match the current country, severity, and time filters."
        }
    }

    // MARK: - Queue building

    @MainActor
    private func rebuildQueue() async {
        hasBuiltInitialQueue = false
        let cal = Calendar.current
        let muted = preferences.currentlyMutedCountries()
        let cutoff = cal.date(byAdding: .day, value: -preferences.swipeHorizonDays, to: Date()) ?? Date()
        let scopeFollowing = preferences.swipeScopeFollowingOnly
            && (preferences.trackAllCountries || !preferences.savedCountryCodes.isEmpty)
        let minSev = preferences.swipeMinSeverity

        // Dedup by URL host + first 60 chars of title — same article across
        // multiple buckets shouldn't appear twice in the deck.
        var seenFingerprints: Set<String> = []
        var pool: [Signal] = []
        let sourceSignals = await repository.deckSignals(
            days: preferences.swipeHorizonDays,
            limit: deckFetchLimit,
            minSeverity: preferences.swipeMinSeverity
        )

        for s in sourceSignals {
            guard !preferences.seenSignalIDs.contains(s.id) else { continue }
            guard s.publishedAt >= cutoff else { continue }
            // `isFollowing` is case-insensitive — direct `following.contains(iso)`
            // was silently filtering out signals whose ISO casing differed.
            if scopeFollowing, !preferences.isFollowing(s.countryISO) { continue }
            if let iso = s.countryISO, muted.contains(iso.uppercased()) { continue }
            // Severity threshold.
            if severityRank(s.severity) < severityRank(minSev) { continue }
            let fp = (s.url.host ?? "") + "::" + String(s.title.prefix(60).lowercased())
            if seenFingerprints.contains(fp) { continue }
            seenFingerprints.insert(fp)
            pool.append(s)
        }

        // Newest first.
        deck = pool.sorted { $0.publishedAt > $1.publishedAt }
        currentIndex = 0
        topCardOffset = .zero
        isResolvingTopCard = false
        caughtUpAppeared = false
        completedBySwiping = false
        if deck.isEmpty {
            allCaughtUp = true
            caughtUpRunID = UUID()
        } else {
            allCaughtUp = false
        }
        hasBuiltInitialQueue = true
    }

    private func severityRank(_ s: AlertSeverity) -> Int {
        switch s { case .low: return 0; case .medium: return 1; case .high: return 2 }
    }

    // MARK: - Helpers

    private func flagEmoji(for iso: String) -> String {
        let normalized = iso.uppercased()
        guard normalized.count == 2 else { return "🌍" }
        let base: UInt32 = 127397
        var s = ""
        for v in normalized.unicodeScalars {
            guard v.value >= 65 && v.value <= 90,
                  let scalar = UnicodeScalar(base + v.value) else {
                return "🌍"
            }
            s.append(String(scalar))
        }
        return s
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = max(0, Int(Date().timeIntervalSince(date) / 60))
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        if mins < 60 * 24 { return "\(mins / 60)h ago" }
        return "\(mins / 1440)d ago"
    }
}

// MARK: - Filters sheet

private struct SwipeFiltersSheet: View {
    let preferences: LocalPreferences
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Scope") {
                    Toggle(preferences.trackAllCountries ? "All countries tracked" : "Following only (\(preferences.savedCountryCodes.count))", isOn: Binding(
                        get: { preferences.swipeScopeFollowingOnly },
                        set: { preferences.swipeScopeFollowingOnly = $0 }
                    ))
                }
                Section("Severity") {
                    Picker("Minimum severity", selection: Binding(
                        get: { preferences.swipeMinSeverity },
                        set: { preferences.swipeMinSeverity = $0 }
                    )) {
                        Text("All").tag(AlertSeverity.low)
                        Text("Medium+").tag(AlertSeverity.medium)
                        Text("High only").tag(AlertSeverity.high)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Time horizon") {
                    Picker("Show signals from the last", selection: Binding(
                        get: { preferences.swipeHorizonDays },
                        set: { preferences.swipeHorizonDays = $0 }
                    )) {
                        Text("24h").tag(1)
                        Text("7d").tag(7)
                        Text("30d").tag(30)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button("Reset seen queue", role: .destructive) {
                        preferences.resetSeenQueue()
                        onDone()
                    }
                }
            }
            .navigationTitle("Catch-up filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { onDone() }
                }
            }
        }
    }
}

// MARK: - Completion mark

private struct CatchUpCompletionMark: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Theme.bone.opacity(0.80))
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 0.8))

                GlobeLinework()
                    .trim(from: 0, to: isActive ? 1 : 0.08)
                    .stroke(
                        Theme.moss.opacity(0.68),
                        style: StrokeStyle(lineWidth: max(1.4, side * 0.015), lineCap: .round, lineJoin: .round)
                    )
                    .padding(side * 0.22)
                    .animation(reduceMotion ? .none : .smooth(duration: 0.74), value: isActive)

                Circle()
                    .trim(from: 0.12, to: isActive ? 0.94 : 0.18)
                    .stroke(
                        Theme.clay.opacity(0.34),
                        style: StrokeStyle(lineWidth: max(1.2, side * 0.012), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-28))
                    .padding(side * 0.10)
                    .animation(reduceMotion ? .none : .smooth(duration: 0.80).delay(0.08), value: isActive)

                ZStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: side * 0.18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.terracotta)
                        .rotationEffect(.degrees(34))
                        .offset(y: -side * 0.43)
                }
                .rotationEffect(.degrees(reduceMotion ? 35 : (isActive ? 385 : 35)))
                .opacity(isActive ? 1 : 0)
                .animation(reduceMotion ? .none : .smooth(duration: 0.88).delay(0.12), value: isActive)

                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.25, weight: .heavy))
                    .foregroundStyle(Theme.olive)
                    .opacity(isActive ? 1 : 0)
                    .scaleEffect(isActive ? 1 : 0.82)
                    .animation(reduceMotion ? .none : .snappy(duration: 0.34).delay(0.48), value: isActive)
            }
        }
        .accessibilityLabel("Catch-up complete")
    }
}

private struct GlobeLinework: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)

        let verticalInset = rect.width * 0.24
        path.addEllipse(in: rect.insetBy(dx: verticalInset, dy: 0))

        let horizontalInset = rect.height * 0.24
        path.addEllipse(in: rect.insetBy(dx: 0, dy: horizontalInset))

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))

        return path
    }
}
