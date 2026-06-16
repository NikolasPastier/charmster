import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Photoreal coach avatar surface. Plays the coach's looping base clip
/// (idle/talking/thinking) full-bleed and crossfades to one-shot reactions
/// (emphasize/affirm/laugh) before returning to the base. When no clip
/// resolves (none uploaded yet, offline, or load failure) it paints a calm
/// Aura-gradient fallback with the coach's role symbol — never a black frame.
/// Respects Reduce Motion.
struct CoachAvatarView: View {
  let coach: CoachPersona
  var baseState: CoachAvatarState = .idle
  var reaction: CoachAvatarState? = nil
  /// 1-based talking take, chosen once per lecture and held for its duration.
  var talkingTake: Int = 1
  var onReactionFinished: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      CoachFallbackStill(coach: coach)
        .transition(.opacity)
      if !reduceMotion {
        CoachPlayerLayer(
          coach: coach,
          baseState: baseState,
          reaction: reaction,
          talkingTake: talkingTake,
          onReactionFinished: onReactionFinished
        )
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
      }
    }
    .clipped()
    .accessibilityLabel(Text("\(coach.humanName), your coach"))
    .accessibilityAddTraits(.isImage)
  }
}

// MARK: - Fallback still

private struct CoachFallbackStill: View {
  let coach: CoachPersona
  @State private var loadedStill: UIImage?

  var body: some View {
    ZStack {
      if let img = loadedStill {
        Image(uiImage: img).resizable().scaledToFill()
      } else {
        ZStack {
          Theme.surfaceRaised
          Theme.auraGradient
            .opacity(0.5)
            .blur(radius: 60)
          Image(systemName: coach.fallbackSymbol)
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(Color.white.opacity(0.85))
        }
      }
    }
    .task(id: coach.id) {
      loadedStill = await CoachClipCatalog.shared.idleStill(for: coach)
    }
  }
}

// MARK: - Player layer

private struct CoachPlayerLayer: UIViewRepresentable {
  let coach: CoachPersona
  let baseState: CoachAvatarState
  let reaction: CoachAvatarState?
  let talkingTake: Int
  let onReactionFinished: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onReactionFinished: onReactionFinished) }

  func makeUIView(context: Context) -> ContainerView {
    let v = ContainerView()
    v.backgroundColor = .clear
    context.coordinator.attach(to: v, coach: coach)
    return v
  }

  func updateUIView(_ uiView: ContainerView, context: Context) {
    context.coordinator.coach = coach
    context.coordinator.talkingTake = talkingTake
    context.coordinator.apply(baseState: baseState, reaction: reaction)
  }

  static func dismantleUIView(_ uiView: ContainerView, coordinator: Coordinator) {
    coordinator.teardown()
  }

  final class Coordinator: NSObject {
    var coach: CoachPersona = .default
    var talkingTake: Int = 1
    private weak var container: ContainerView?
    private var primaryLayer: AVPlayerLayer?
    private var primaryPlayer: AVPlayer?
    private var crossfadeLayer: AVPlayerLayer?
    private var crossfadePlayer: AVPlayer?
    private var currentBase: CoachAvatarState = .idle
    private var currentReaction: CoachAvatarState?
    private var reactionObserver: NSObjectProtocol?
    private var loopObserver: NSObjectProtocol?
    private let onReactionFinished: () -> Void

    init(onReactionFinished: @escaping () -> Void) {
      self.onReactionFinished = onReactionFinished
    }

    /// Builds an AVPlayer that can NEVER produce sound. Belt-and-suspenders:
    /// `isMuted = true` AND an `AVMutableAudioMix` that zeroes the volume of
    /// every audio track on the item. Some coach clips (e.g. Leo talking) carry
    /// an audio track; the avatar is purely visual, so all clip audio is killed
    /// regardless of device mute switch or speaker route. The ONLY audio in the
    /// lecture is the per-beat narration played by `LectureBeatNarrator`.
    static func makeMutedPlayer(url: URL) -> (AVPlayerItem, AVPlayer) {
      let asset = AVURLAsset(url: url)
      let item = AVPlayerItem(asset: asset)

      let mix = AVMutableAudioMix()
      var params: [AVMutableAudioMixInputParameters] = []
      for track in asset.tracks(withMediaType: .audio) {
        let p = AVMutableAudioMixInputParameters(track: track)
        p.setVolume(0, at: .zero)
        params.append(p)
      }
      mix.inputParameters = params
      item.audioMix = mix

      let player = AVPlayer(playerItem: item)
      player.isMuted = true
      player.volume = 0
      return (item, player)
    }

    func attach(to container: ContainerView, coach: CoachPersona) {
      self.container = container
      self.coach = coach
    }

    func apply(baseState: CoachAvatarState, reaction: CoachAvatarState?) {
      if reaction == nil, baseState != currentBase {
        currentBase = baseState
        Task { @MainActor in await self.swapPrimary(to: baseState) }
      } else if primaryPlayer == nil {
        currentBase = baseState
        Task { @MainActor in await self.swapPrimary(to: baseState) }
      }
      if let r = reaction, r != currentReaction {
        currentReaction = r
        Task { @MainActor in await self.playReaction(r) }
      } else if reaction == nil {
        currentReaction = nil
      }
    }

    @MainActor
    private func swapPrimary(to state: CoachAvatarState) async {
      let take = (state == .talking) ? talkingTake : 1
      guard
        let url = await CoachClipCatalog.shared.localClipURL(for: coach, state: state, take: take)
      else {
        return  // Keep current frame; fallback still is behind.
      }
      let (item, player) = Self.makeMutedPlayer(url: url)
      player.actionAtItemEnd = .none

      if let prev = loopObserver { NotificationCenter.default.removeObserver(prev) }
      loopObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak player] _ in
        player?.seek(to: .zero)
        player?.play()
      }

      let newLayer = AVPlayerLayer(player: player)
      newLayer.videoGravity = .resizeAspectFill
      newLayer.frame = container?.bounds ?? .zero
      newLayer.opacity = 0
      container?.layer.insertSublayer(newLayer, at: 0)

      CATransaction.begin()
      CATransaction.setAnimationDuration(0.3)
      newLayer.opacity = 1
      primaryLayer?.opacity = 0
      CATransaction.commit()
      player.play()

      let oldLayer = primaryLayer
      let oldPlayer = primaryPlayer
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        oldPlayer?.pause()
        oldLayer?.removeFromSuperlayer()
      }
      primaryLayer = newLayer
      primaryPlayer = player
    }

    @MainActor
    private func playReaction(_ state: CoachAvatarState) async {
      let take = talkingTake
      guard
        let url = await CoachClipCatalog.shared.localClipURL(for: coach, state: state, take: take)
      else {
        onReactionFinished()
        return
      }
      let (item, player) = Self.makeMutedPlayer(url: url)
      player.actionAtItemEnd = .pause

      let layer = AVPlayerLayer(player: player)
      layer.videoGravity = .resizeAspectFill
      layer.frame = container?.bounds ?? .zero
      layer.opacity = 0
      container?.layer.addSublayer(layer)

      CATransaction.begin()
      CATransaction.setAnimationDuration(0.3)
      layer.opacity = 1
      CATransaction.commit()

      if let prev = reactionObserver { NotificationCenter.default.removeObserver(prev) }
      reactionObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak self] _ in
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        layer.opacity = 0
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          player.pause()
          layer.removeFromSuperlayer()
          self?.onReactionFinished()
        }
      }
      crossfadeLayer = layer
      crossfadePlayer = player
      player.play()
    }

    func teardown() {
      if let o = reactionObserver { NotificationCenter.default.removeObserver(o) }
      if let o = loopObserver { NotificationCenter.default.removeObserver(o) }
      primaryPlayer?.pause()
      crossfadePlayer?.pause()
      primaryLayer?.removeFromSuperlayer()
      crossfadeLayer?.removeFromSuperlayer()
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

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    CoachAvatarView(coach: .default)
      .frame(width: 120, height: 120)
      .clipShape(Circle())
  }
}
