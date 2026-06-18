import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Photoreal coach avatar surface. Plays the coach's looping base clip
/// (idle/talking/thinking) full-bleed through the SHARED `LoopingVideoPlayer`
/// (the same proven stack the female practice avatar uses). When no clip
/// resolves (none uploaded yet, offline, or load failure) it paints a calm
/// Aura-gradient / neutral-still fallback BEHIND the video — never a black
/// frame — and the still is faded away the instant the first video frame is
/// ready. Respects Reduce Motion.
///
/// FX10: the previous bespoke `CoachPlayerLayer` built its item via
/// `AVPlayerItem(asset:)` + a synchronous `asset.tracks` audio mix, which
/// stalled item readiness and left a frozen still. That entire stack is gone;
/// muting is now just `player.isMuted` inside `LoopingVideoPlayer`.
struct CoachAvatarView: View {
  let coach: CoachPersona
  var baseState: CoachAvatarState = .idle
  /// 1-based talking take, chosen once per lecture and held for its duration.
  var talkingTake: Int = 1
  /// Retained for source-compat with older callers; reactions reuse the
  /// talking/idle loops in the lecture context, so this is no longer a
  /// separate playback path.
  var reaction: CoachAvatarState? = nil
  var onReactionFinished: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Resolved local clip URL for the current (coach, state, take).
  @State private var clipURL: URL?
  /// Whether the first video frame is ready — drives the still crossfade.
  @State private var videoReady = false

  /// The looping base to actually play. A non-nil reaction collapses to the
  /// talking loop (visual emphasis) so we keep a single playback path.
  private var effectiveState: CoachAvatarState {
    if let reaction, !reaction.isLooping { return .talking }
    return baseState
  }

  /// Stable identity for the current clip request (coach + state + take).
  private var clipID: String {
    "\(coach.id)|\(effectiveState.rawValue)|\(effectiveState == .talking ? talkingTake : 1)"
  }

  var body: some View {
    ZStack {
      // Placeholder still lives BEHIND the video and fades out on first frame.
      CoachFallbackStill(coach: coach)
        .opacity(videoReady ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: videoReady)

      if !reduceMotion {
        LoopingVideoPlayer(
          url: clipURL,
          muted: true,
          clipID: clipID,
          onFirstFrame: { ready in
            videoReady = ready
            // Reactions reuse the talking loop; signal completion once the
            // frame is up so callers that await it don't stall.
            if reaction != nil { onReactionFinished() }
          }
        )
        .transition(.opacity)
      }
    }
    .clipped()
    .task(id: clipID) {
      // Resolve (and cache-download) the clip for the current state/take.
      videoReady = false
      let state = effectiveState
      let take = (state == .talking) ? talkingTake : 1
      let url = await CoachClipCatalog.shared.localClipURL(for: coach, state: state, take: take)
      TenXPreviewSupport.log(
        "[FX10] CoachAvatarView resolve coach=\(coach.id) state=\(state.rawValue) take=\(take) reduceMotion=\(reduceMotion) → \(url?.lastPathComponent ?? "nil (still kept)")"
      )
      clipURL = url
      if url == nil { onReactionFinished() }
    }
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

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    CoachAvatarView(coach: .default)
      .frame(width: 120, height: 120)
      .clipShape(Circle())
  }
}
