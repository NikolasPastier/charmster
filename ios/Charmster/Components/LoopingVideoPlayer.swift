import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// ONE shared looping video surface for the whole app.
///
/// This is the single, proven playback stack — modeled on the working
/// live-practice (female) avatar: a retained `AVPlayer` with a seek-to-zero
/// loop on `AVPlayerItemDidPlayToEndTime`, an `AVPlayerLayer` sized to the
/// container, and crossfades between clips. Both the female practice avatar
/// (`AvatarView`) and the coach lecture avatar (`CoachAvatarView`) render
/// through this component, so there is exactly one playback path to maintain.
///
/// Key correctness rules baked in (the FX10 fixes):
///   • The player item is built with `AVPlayerItem(url:)` and muted ONLY via
///     `player.isMuted = true`. We do NOT synchronously read `asset.tracks`
///     to build an audio mix — that deprecated synchronous accessor stalled
///     item readiness and left the coach on a frozen still while the female
///     avatar (which never touched it) played fine.
///   • The player is owned for the view's lifetime (held by the Coordinator),
///     never a local that deallocs mid-play.
///   • The `AVPlayerLayer` is given an explicit, non-zero frame and resized in
///     `layoutSubviews`.
///   • A placeholder may sit BEHIND the video; the caller fades it out the
///     instant the first frame is ready via `onFirstFrame`.
struct LoopingVideoPlayer: UIViewRepresentable {
  /// The clip to play. Changing this swaps the clip with a 0.3s crossfade.
  let url: URL?
  /// Force-mute the clip. Avatars are purely visual, so this is almost always
  /// true; the only audio in a lecture is `LectureBeatNarrator`.
  var muted: Bool = true
  /// A stable identity for the current clip request. When this changes we swap
  /// even if `url` is briefly the same object (e.g. idle→talking→idle).
  var clipID: String = ""
  /// Called on the main thread the first time a frame is ready to display, so
  /// the caller can crossfade any placeholder still away. Also passes whether
  /// the item reached `.readyToPlay` (false ⇒ `.failed`, still kept).
  var onFirstFrame: (_ ready: Bool) -> Void = { _ in }

  func makeCoordinator() -> Coordinator { Coordinator(onFirstFrame: onFirstFrame) }

  func makeUIView(context: Context) -> ContainerView {
    let v = ContainerView()
    v.backgroundColor = .clear
    context.coordinator.attach(to: v)
    return v
  }

  func updateUIView(_ uiView: ContainerView, context: Context) {
    context.coordinator.onFirstFrame = onFirstFrame
    context.coordinator.apply(url: url, muted: muted, clipID: clipID)
  }

  static func dismantleUIView(_ uiView: ContainerView, coordinator: Coordinator) {
    coordinator.teardown()
  }

  // MARK: - Coordinator (owns the retained player)

  final class Coordinator: NSObject {
    var onFirstFrame: (_ ready: Bool) -> Void

    private weak var container: ContainerView?
    private var primaryLayer: AVPlayerLayer?
    private var primaryPlayer: AVPlayer?
    private var loopObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    /// Identity of the clip currently mounted, to dedupe redundant swaps.
    private var currentClipID: String = "<none>"

    init(onFirstFrame: @escaping (_ ready: Bool) -> Void) {
      self.onFirstFrame = onFirstFrame
    }

    func attach(to container: ContainerView) {
      self.container = container
    }

    func apply(url: URL?, muted: Bool, clipID: String) {
      let id = clipID.isEmpty ? (url?.absoluteString ?? "<nil>") : clipID
      guard id != currentClipID else {
        primaryPlayer?.isMuted = muted
        return
      }
      // Don't commit currentClipID until we have a real URL to mount.
      // If url is nil (still downloading), the next call with the resolved URL
      // must not be deduped — so we leave currentClipID unchanged here.
      guard let url else { return }
      currentClipID = id
      Task { @MainActor in self.mount(url: url, muted: muted) }
    }

    @MainActor
    private func mount(url: URL, muted: Bool) {
      TenXPreviewSupport.log(
        "[FX10] LoopingVideoPlayer.mount url=\(url.lastPathComponent) muted=\(muted) fileExists=\(FileManager.default.fileExists(atPath: url.path))"
      )

      // EXACTLY the working female-avatar construction: plain item from URL,
      // muted only via the player. No synchronous asset.tracks audio mix.
      let item = AVPlayerItem(url: url)
      let player = AVPlayer(playerItem: item)
      player.isMuted = muted
      player.actionAtItemEnd = .none

      // Loop: seek-to-zero on end (the proven loop).
      if let prev = loopObserver { NotificationCenter.default.removeObserver(prev) }
      loopObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak player] _ in
        player?.seek(to: .zero)
        player?.play()
      }

      // FX10.0 — report readiness and fade the placeholder off on first frame.
      statusObserver?.invalidate()
      statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] obsItem, _ in
        switch obsItem.status {
        case .readyToPlay:
          TenXPreviewSupport.log("[FX10] item status=.readyToPlay \(url.lastPathComponent)")
          self?.onFirstFrame(true)
        case .failed:
          TenXPreviewSupport.log(
            "[FX10] item status=.FAILED \(url.lastPathComponent) error=\(obsItem.error.map { String(describing: $0) } ?? "nil")"
          )
          self?.onFirstFrame(false)
        case .unknown:
          break
        @unknown default:
          break
        }
      }

      let newLayer = AVPlayerLayer(player: player)
      newLayer.videoGravity = .resizeAspectFill
      newLayer.frame = container?.bounds ?? CGRect(x: 0, y: 0, width: 1, height: 1)
      newLayer.opacity = 0
      container?.layer.insertSublayer(newLayer, at: 0)

      CATransaction.begin()
      CATransaction.setAnimationDuration(0.3)
      newLayer.opacity = 1
      primaryLayer?.opacity = 0
      CATransaction.commit()

      player.play()
      TenXPreviewSupport.log(
        "[FX10] play() called layerFrame=\(newLayer.frame.debugDescription) bounds=\((container?.bounds ?? .zero).debugDescription) rate=\(player.rate) retained=true"
      )

      let oldLayer = primaryLayer
      let oldPlayer = primaryPlayer
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        oldPlayer?.pause()
        oldLayer?.removeFromSuperlayer()
      }
      primaryLayer = newLayer
      primaryPlayer = player
    }

    func teardown() {
      if let o = loopObserver { NotificationCenter.default.removeObserver(o) }
      statusObserver?.invalidate()
      statusObserver = nil
      primaryPlayer?.pause()
      primaryLayer?.removeFromSuperlayer()
      primaryPlayer = nil
      primaryLayer = nil
    }
  }

  // MARK: - Container

  final class ContainerView: UIView {
    override func layoutSubviews() {
      super.layoutSubviews()
      for sub in layer.sublayers ?? [] {
        if let pl = sub as? AVPlayerLayer { pl.frame = bounds }
      }
    }
  }
}
