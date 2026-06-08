import SwiftUI
import AVFoundation
import AVKit
import UIKit

/// Photoreal video-clip avatar. Plays the persona's looping base clip
/// (idle/listening/talking/thinking) full-bleed, and crossfades to one-shot
/// reaction clips (smile/laugh/flirty/surprised/cool/reassure) before returning
/// to the base. Falls back to a bundled still on offline/load failure and
/// respects Reduce Motion.
struct AvatarView: View {
    let persona: AvatarPersona
    /// Looping base state — driven by who is speaking.
    let baseState: AvatarState
    /// One-shot reaction — set to a non-nil value to play once, then clear.
    let reaction: AvatarState?
    let onReactionFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            FallbackStill(persona: persona)
                .transition(.opacity)
            if !reduceMotion {
                AvatarPlayerLayer(
                    persona: persona,
                    baseState: baseState,
                    reaction: reaction,
                    onReactionFinished: onReactionFinished
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .clipped()
        .accessibilityLabel(Text("\(persona.displayName) avatar"))
        .accessibilityAddTraits(.isImage)
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
                    Image(systemName: persona.gender == .masculine
                          ? "person.fill" : "person.crop.circle.fill")
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

// MARK: - Player layer

private struct AvatarPlayerLayer: UIViewRepresentable {
    let persona: AvatarPersona
    let baseState: AvatarState
    let reaction: AvatarState?
    let onReactionFinished: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onReactionFinished: onReactionFinished) }

    func makeUIView(context: Context) -> ContainerView {
        let v = ContainerView()
        v.backgroundColor = .clear
        context.coordinator.attach(to: v, persona: persona)
        return v
    }

    func updateUIView(_ uiView: ContainerView, context: Context) {
        context.coordinator.persona = persona
        context.coordinator.apply(baseState: baseState, reaction: reaction)
    }

    static func dismantleUIView(_ uiView: ContainerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator: NSObject {
        var persona: AvatarPersona = .default
        private weak var container: ContainerView?
        private var primaryLayer: AVPlayerLayer?
        private var crossfadeLayer: AVPlayerLayer?
        private var primaryPlayer: AVPlayer?
        private var crossfadePlayer: AVPlayer?
        private var currentBase: AvatarState = .idle
        private var currentReaction: AvatarState?
        private var reactionObserver: NSObjectProtocol?
        private var loopObserver: NSObjectProtocol?
        private let onReactionFinished: () -> Void

        init(onReactionFinished: @escaping () -> Void) {
            self.onReactionFinished = onReactionFinished
        }

        func attach(to container: ContainerView, persona: AvatarPersona) {
            self.container = container
            self.persona = persona
        }

        func apply(baseState: AvatarState, reaction: AvatarState?) {
            if reaction == nil, baseState != currentBase {
                currentBase = baseState
                Task { @MainActor in await self.swapPrimary(to: baseState, loop: true) }
            } else if primaryPlayer == nil {
                currentBase = baseState
                Task { @MainActor in await self.swapPrimary(to: baseState, loop: true) }
            }
            if let r = reaction, r != currentReaction {
                currentReaction = r
                Task { @MainActor in await self.playReaction(r) }
            } else if reaction == nil {
                currentReaction = nil
            }
        }

        @MainActor
        private func swapPrimary(to state: AvatarState, loop: Bool) async {
            guard let url = await AvatarClipCatalog.shared.localClipURL(for: persona, state: state) else {
                return // Keep current frame; fallback still is behind.
            }
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = loop ? .none : .pause

            if loop {
                if let prev = loopObserver { NotificationCenter.default.removeObserver(prev) }
                loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item, queue: .main
                ) { [weak player] _ in
                    player?.seek(to: .zero)
                    player?.play()
                }
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
        private func playReaction(_ state: AvatarState) async {
            guard let url = await AvatarClipCatalog.shared.localClipURL(for: persona, state: state) else {
                onReactionFinished()
                return
            }
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
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
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item, queue: .main
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
