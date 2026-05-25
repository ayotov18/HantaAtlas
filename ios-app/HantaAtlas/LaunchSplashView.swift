import SwiftUI
import AVFoundation
import UIKit

/// Scroll-driven "cosmic zoom" launch reveal. Replaces the earlier bullseye
/// calibration splash. As the user scrolls, a continuous descent-from-space
/// video (a single uninterrupted *cosmic zoom* — space → Earth) is *scrubbed*
/// frame-by-frame, then the app starts.
///
/// **Technique**: this is the Apple-product-page "image-sequence / video
/// scrubbing on scroll" pattern (scrollytelling). Rather than holding dozens
/// of decoded frames in memory (which would blow the cold-start memory
/// budget), we tie scroll progress to `AVPlayer` playback time and seek a
/// bundled, all-keyframe mp4 — frame-accurate and memory-cheap.
///
/// **Cold-start invariants preserved**:
///  - `Theme.paper` paints under everything first (no flash of black); the
///    space video *fades in* over the paper, so there is no hard cut to dark.
///  - The `AVPlayer` is created in `onAppear`, never in a `@State` initialiser,
///    so no heavy work runs during first-frame body evaluation.
///
/// **Never a trap** (App Review): Reduce Motion hands off immediately; a tap
/// skips after a beat; and if the user doesn't scroll within a couple of
/// seconds the zoom auto-plays to the end and the app proceeds on its own.
struct LaunchSplashView: View {

    /// Fired when the reveal completes (scrolled to the end, skipped, or
    /// auto-advanced). The host crossfades into the real first view.
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scrubber: CosmicScrubber? = nil
    @State private var appeared = false
    @State private var canSkip = false
    @State private var didFinish = false
    @State private var didInteract = false
    @State private var hintVisible = true
    @State private var hintFloat = false

    var body: some View {
        ZStack {
            // Base paint — the reveal fades up from paper so the dark first
            // frame never reads as a flash of black.
            Theme.paper.ignoresSafeArea()

            if let scrubber {
                CosmicPlayerLayerView(player: scrubber.player)
                    .ignoresSafeArea()
                    .opacity(appeared ? 1 : 0)
                    .accessibilityHidden(true)

                scrollCapture

                overlay
                    .allowsHitTesting(false)   // let scroll pass through
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if canSkip { finish() } }
        .accessibilityElement()
        .accessibilityLabel("HantaAtlas. Scroll to enter.")
        .accessibilityAddTraits(.isImage)
        .onAppear { start() }
        .onDisappear { scrubber?.player.pause() }
    }

    // MARK: - Scroll capture (drives the scrub)

    private var scrollCapture: some View {
        GeometryReader { geo in
            let viewport = geo.size.height
            let scrollable = max(1, viewport * 1.4)   // content (2.4x) minus viewport
            ScrollView(.vertical, showsIndicators: false) {
                Color.clear.frame(height: viewport * 2.4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                handleScroll(progress: Double(max(0, min(1, y / scrollable))))
            }
        }
    }

    // MARK: - Overlay (wordmark + glass scroll hint)

    private var overlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 6) {
                Text("HantaAtlas")
                    .font(Theme.Fonts.heroWordmark)
                    .foregroundStyle(.white)
                Text("Where, when, and by whom.")
                    .font(.system(size: 11, weight: .semibold).smallCaps())
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .shadow(color: .black.opacity(0.4), radius: 12, y: 2)
            .opacity(appeared ? 1 : 0)

            Spacer()

            if hintVisible {
                scrollHint
                    .padding(.bottom, 46)
                    .opacity(appeared ? 1 : 0)
                    .transition(.opacity)
            }
        }
    }

    /// "Scroll to enter" cue, built from the official iOS 26 Liquid Glass
    /// material (`glassEffect(.regular.interactive(), in: .capsule)`). Two
    /// reinforcing motion signals make the gesture read instantly: an upward
    /// directional `chevron.up` bounce (SF Symbols 7 `.bounce.up`) and a gentle
    /// continuous float of the whole glass pill (`hintFloat`).
    private var scrollHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.up")
                .font(.system(size: 17, weight: .bold))
                .symbolEffect(.bounce.up, options: .repeating)
            Text("Scroll to enter")
                .font(.subheadline.weight(.semibold))
                .tracking(0.3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: .capsule)
        .offset(y: hintFloat ? -8 : 0)
        .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: hintFloat)
    }

    // MARK: - Lifecycle

    private func start() {
        if scrubber == nil { scrubber = CosmicScrubber() }
        guard let scrubber else { finish(); return }   // asset missing → don't trap
        scrubber.onEnded = { finish() }

        if reduceMotion { finish(); return }

        scrubber.seek(progress: 0)
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        hintFloat = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { canSkip = true }

        // Idle auto-advance: hold the "Scroll to enter" cue on screen long
        // enough to actually be read and acted on (was 1.5s — too brief to
        // register, which is why the cue felt absent). Only after ~6s of no
        // interaction do we play the zoom through at 2× so non-scrollers still
        // see it and reach the app, and the splash never gets stuck on the
        // space frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            guard !didInteract, !didFinish else { return }
            withAnimation { hintVisible = false }
            scrubber.player.rate = 2.0
        }
    }

    private func handleScroll(progress: Double) {
        guard !didFinish, scrubber != nil else { return }
        // `onScrollGeometryChange` fires once on the scroll view's initial
        // layout/settle (progress ≈ 0) before any gesture. Treat only a real
        // scroll past a small threshold as interaction — otherwise that first
        // spurious callback marked `didInteract` and hid the cue ~1s in (and
        // cancelled the idle auto-advance) without the user ever scrolling.
        if progress > 0.02, !didInteract {
            didInteract = true
            withAnimation { hintVisible = false }
        }
        scrubber?.seek(progress: progress)
        if progress >= 0.97 { finish() }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        scrubber?.player.pause()
        onComplete()
    }
}

// MARK: - Scrubber (AVPlayer seek by scroll progress)

/// Wraps an `AVPlayer` over the bundled cosmic-zoom mp4 and seeks it by
/// progress (0…1). The asset is encoded all-keyframe, so zero-tolerance seeks
/// are frame-accurate and instant. `nil` from the init means the asset is
/// missing — the view then hands off immediately rather than trapping.
@MainActor
@Observable
final class CosmicScrubber {
    let player: AVQueuePlayer
    private let durationSeconds: Double = 5.0
    @ObservationIgnored var onEnded: (() -> Void)?
    @ObservationIgnored private var lastProgress: Double = -1

    init?() {
        guard let url = Bundle.main.url(forResource: "cosmic_scrub", withExtension: "mp4") else { return nil }
        let item = AVPlayerItem(url: url)
        player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onEnded?() }
        }
    }

    func seek(progress: Double) {
        let p = max(0, min(1, progress))
        // Skip negligible deltas to avoid seek storms during fast scrolls.
        guard abs(p - lastProgress) > 0.004 else { return }
        lastProgress = p
        player.seek(to: CMTime(seconds: p * durationSeconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

// MARK: - Player layer host

private struct CosmicPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerLayerHostView {
        let v = PlayerLayerHostView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PlayerLayerHostView, context: Context) {}
}

private final class PlayerLayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

#Preview("Launch — cosmic zoom") {
    LaunchSplashView(onComplete: {})
}
