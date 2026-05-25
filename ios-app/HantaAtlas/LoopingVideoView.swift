import SwiftUI
import UIKit
import AVFoundation

/// Full-bleed, seamlessly-looping, **muted** video background. Used behind the
/// auth screen (`WelcomeView`), where it is blurred. Built lazily on appear via
/// `UIViewRepresentable`, so it never touches the cold-start path. The video
/// asset itself ships with no audio track; we also force-mute as a belt-and-
/// braces guard so it can never interrupt the user's music.
struct LoopingVideoView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        view.start(resourceName: resourceName, ext: resourceExtension)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {}
}

/// Backing `UIView` whose layer is an `AVPlayerLayer`. Owns the queue player +
/// looper for their lifetime; tears down on `deinit` (i.e. when the SwiftUI
/// representable is removed — e.g. the auth sheet is dismissed).
final class LoopingPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func start(resourceName: String, ext: String) {
        guard player == nil,
              let url = Bundle.main.url(forResource: resourceName, withExtension: ext) else { return }

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        // AVPlayerLooper handles the gapless restart by re-enqueuing the item.
        looper = AVPlayerLooper(player: queue, templateItem: item)

        playerLayer.player = queue
        playerLayer.videoGravity = .resizeAspectFill
        player = queue
        queue.play()
    }

    deinit {
        player?.pause()
        player = nil
        looper = nil
    }
}
