import AVFoundation
import Foundation
import Observation

/// Streams voice PREVIEW clips from the public `Avatars/Voices` bucket via a
/// single shared `AVPlayer`. Guarantees only ONE preview plays at a time, stops
/// cleanly on dismiss, and fails gracefully (a clip that can't load just stops —
/// it never crashes and is reported so the UI can disable its play button).
///
/// This is the partner's VOICE preview only. It deliberately uses `.ambient`
/// audio and never touches the live session's `.playAndRecord` configuration,
/// so previewing in onboarding/Settings can't disturb mic capture.
@Observable
@MainActor
final class AvatarVoicePreviewPlayer {

  /// The voice id currently playing, or nil when stopped.
  private(set) var playingId: String?
  /// Voice ids that failed to load — the UI disables their play button.
  private(set) var failedIds: Set<String> = []

  private let player = AVPlayer()
  private var endObserver: NSObjectProtocol?
  private var statusObservation: NSKeyValueObservation?

  /// Toggle preview for a voice: tapping the playing one stops it, tapping a
  /// different one stops the first and starts the new one.
  func toggle(_ voice: AvatarVoice) {
    if playingId == voice.id {
      stop()
    } else {
      play(voice)
    }
  }

  func play(_ voice: AvatarVoice) {
    guard let url = voice.previewURL else {
      markFailed(voice.id)
      return
    }
    stop()

    // Ambient so a preview can't fight the live mic session; previews mix in
    // and respect the silent switch.
    #if os(iOS)
      try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
      try? AVAudioSession.sharedInstance().setActive(true)
    #endif

    let item = AVPlayerItem(url: url)
    player.replaceCurrentItem(with: item)

    // Watch for a load failure -> mark failed + clear state (never crash).
    statusObservation = item.observe(\AVPlayerItem.status, options: [.new]) {
      (observedItem: AVPlayerItem, _: NSKeyValueObservedChange<AVPlayerItem.Status>) in
      guard observedItem.status == .failed else { return }
      Task { @MainActor in
        guard let self else { return }
        self.markFailed(voice.id)
        if self.playingId == voice.id { self.clear() }
      }
    }

    // Auto-stop when the clip finishes.
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.clear() }
    }

    playingId = voice.id
    player.seek(to: .zero)
    player.play()
  }

  /// Stop any playback (e.g. on view dismiss). Safe to call repeatedly.
  func stop() {
    player.pause()
    clear()
  }

  private func clear() {
    player.replaceCurrentItem(with: nil)
    if let o = endObserver { NotificationCenter.default.removeObserver(o) }
    endObserver = nil
    statusObservation?.invalidate()
    statusObservation = nil
    playingId = nil
  }

  private func markFailed(_ id: String) {
    failedIds.insert(id)
  }
}
