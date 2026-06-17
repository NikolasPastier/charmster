import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Photoreal video-clip practice avatar. Plays the persona's looping base clip
/// (idle/listening/talking/thinking) full-bleed through the SHARED
/// `LoopingVideoPlayer` — the exact same playback stack the coach lecture
/// avatar uses — and crossfades to one-shot reaction clips
/// (smile/laugh/flirty/surprised/cool/reassure) on a thin overlay before
/// returning to the base. Falls back to a still on offline/load failure and
/// respects Reduce Motion.
struct AvatarView: View {
  let persona: AvatarPersona
  /// Looping base state — driven by who is speaking.
  let baseState: AvatarState
  /// One-shot reaction — set to a non-nil value to play once, then clear.
  let reaction: AvatarState?
  let onReactionFinished: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Resolved local URL for the current base loop.
  @State private var baseURL: URL?
  @State private var baseReady = false

  var body: some View {
    ZStack {
      // Fallback still behind the video; fades out on the first base frame.
      FallbackStill(persona: persona)
        .opacity(baseReady ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: baseReady)

      if !reduceMotion {
        // Shared base-loop player.
        LoopingVideoPlayer(
          url: baseURL,
          muted: true,
          clipID: "\(persona.id)|\(baseState.rawValue)",
          onFirstFrame: { ready in baseReady = ready }
        )

        // One-shot reaction overlay (female-specific behavior preserved).
        ReactionOverlay(
          persona: persona,
          reaction: reaction,
          onReactionFinished: onReactionFinished
        )
        .allowsHitTesting(false)
      }
    }
    .clipped()
    .task(id: "\(persona.id)|\(baseState.rawValue)") {
      baseReady = false
      baseURL = await AvatarClipCatalog.shared.localClipURL(for: persona, state: baseState)
    }
    .accessibilityLabel(Text("\(persona.displayName) avatar"))
    .accessibilityAddTraits(.isImage)
  }
}

// MARK: - Reaction overlay (one-shot, returns to base)

/// Plays a single reaction clip on top of the base loop, then crossfades out
/// and signals completion. This is the only behavior that is unique to the
/// practice avatar; the base loop is shared with the coach via
/// `LoopingVideoPlayer`.
private struct ReactionOverlay: UIViewRepresentable {
  let persona: AvatarPersona
  let reaction: AvatarState?
  let onReactionFinished: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onReactionFinished: onReactionFinished) }

  func makeUIView(context: Context) -> ContainerView {
    let v = ContainerView()
    v.backgroundColor = .clear
    context.coordinator.attach(to: v)
    return v
  }

  func updateUIView(_ uiView: ContainerView, context: Context) {
    context.coordinator.persona = persona
    context.coordinator.apply(reaction: reaction)
  }

  static func dismantleUIView(_ uiView: ContainerView, coordinator: Coordinator) {
    coordinator.teardown()
  }

  final class Coordinator: NSObject {
    var persona: AvatarPersona = .default
    private weak var container: ContainerView?
    private var player: AVPlayer?
    private var layer: AVPlayerLayer?
    private var endObserver: NSObjectProtocol?
    private var currentReaction: AvatarState?
    private let onReactionFinished: () -> Void

    init(onReactionFinished: @escaping () -> Void) {
      self.onReactionFinished = onReactionFinished
    }

    func attach(to container: ContainerView) { self.container = container }

    func apply(reaction: AvatarState?) {
      if let r = reaction, r != currentReaction {
        currentReaction = r
        Task { @MainActor in await self.play(r) }
      } else if reaction == nil {
        currentReaction = nil
      }
    }

    @MainActor
    private func play(_ state: AvatarState) async {
      guard let url = await AvatarClipCatalog.shared.localClipURL(for: persona, state: state) else {
        onReactionFinished()
        return
      }
      let item = AVPlayerItem(url: url)
      let p = AVPlayer(playerItem: item)
      p.isMuted = true
      p.actionAtItemEnd = .pause

      let l = AVPlayerLayer(player: p)
      l.videoGravity = .resizeAspectFill
      l.frame = container?.bounds ?? .zero
      l.opacity = 0
      container?.layer.addSublayer(l)

      CATransaction.begin()
      CATransaction.setAnimationDuration(0.3)
      l.opacity = 1
      CATransaction.commit()

      if let prev = endObserver { NotificationCenter.default.removeObserver(prev) }
      endObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak self] _ in
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        l.opacity = 0
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          p.pause()
          l.removeFromSuperlayer()
          self?.onReactionFinished()
        }
      }

      layer = l
      player = p
      p.play()
    }

    func teardown() {
      if let o = endObserver { NotificationCenter.default.removeObserver(o) }
      player?.pause()
      layer?.removeFromSuperlayer()
    }
  }

  final class ContainerView: UIView {
    override func layoutSubviews() {
      super.layoutSubviews()
      for sub in layer.sublayers ?? [] {
        if let pl = sub as? AVPlayerLayer { pl.frame = bounds }
      }
    }
  }
}

// MARK: - Fallback still

private struct FallbackStill: View {
  let persona: AvatarPersona
  @State private var loadedStill: UIImage?

  var body: some View {
    ZStack {
      if let img = loadedStill {
        Image(uiImage: img)
          .resizable()
          .scaledToFill()
      } else {
        // Aura-gradient cutout still — never a black frame.
        ZStack {
          Theme.bg
          Theme.auraGradient
            .opacity(0.55)
            .blur(radius: 60)
          Image(
            systemName: persona.gender == .masculine
              ? "person.fill" : "person.crop.circle.fill"
          )
          .font(.system(size: 120, weight: .light))
          .foregroundStyle(Color.white.opacity(0.18))
        }
      }
    }
    .task(id: persona.id) {
      loadedStill = await AvatarClipCatalog.shared.idleStill(for: persona)
    }
  }
}
