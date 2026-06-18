import AVFoundation
import Foundation
import Observation
import UIKit

/// Drives a coach's three voice preview lines, auto-playing them in strict order
/// 1 -> 2 -> 3 the moment a coach is selected, then stopping. This is the audio
/// that introduces a coach in their own voice.
///
/// Owns exactly ONE `AVQueuePlayer` per screen. Builds the queue from the
/// coach's `previewLines` ([line1, line2, line3]), inserts a subtle gap between
/// lines for natural pacing, tears down cleanly on completion / dismiss /
/// background, and never lets two sequences stack (rapid re-taps are debounced
/// and old audio is always cancelled first).
///
/// Unlike `AvatarVoicePreviewPlayer` (ambient, mixes), this is an intentional
/// voice introduction the user just triggered, so it uses `.playback` and plays
/// even with the hardware silent switch on.
@Observable
@MainActor
final class CoachPreviewPlayer {

  enum State: Equatable {
    case idle
    case loading
    /// 1-based index of the line currently playing (1...3).
    case playing(line: Int)
    case finished
  }

  private(set) var state: State = .idle
  /// The coach id whose sequence is active (or nil when idle/finished).
  private(set) var activeCoachId: String?

  /// Subtle gap between lines for natural pacing.
  private static let interLineGap: CMTime = CMTime(seconds: 0.3, preferredTimescale: 600)

  private var player: AVQueuePlayer?
  private var items: [AVPlayerItem] = []
  private var endObserver: NSObjectProtocol?
  private var timeObserver: Any?
  private var statusObservers: [NSKeyValueObservation] = []
  private var interruptionObserver: NSObjectProtocol?
  private var routeObserver: NSObjectProtocol?
  private var backgroundObserver: NSObjectProtocol?
  private var lastTapAt: Date = .distantPast

  var isPlaying: Bool {
    if case .playing = state { return true }
    return false
  }

  func isPlaying(coachId: String) -> Bool {
    isPlaying && activeCoachId == coachId
  }

  // MARK: - Public surface

  /// Begin (or restart) the coach's preview sequence from line 1.
  ///
  /// - Re-tapping the SAME coach while playing restarts from line 1.
  /// - Tapping a DIFFERENT coach cancels the current sequence and starts fresh.
  /// Rapid taps are debounced so players can never stack.
  func play(_ coach: CoachPersona) {
    let now = Date()
    if now.timeIntervalSince(lastTapAt) < 0.2 { return }
    lastTapAt = now

    let lines = coach.previewLines
    guard !lines.isEmpty else { return }

    stop()  // cancel anything already playing (same or different coach)
    activeCoachId = coach.id
    state = .loading

    activateSession()
    observeInterruptions()

    let queueItems = lines.map { url -> AVPlayerItem in
      let item = AVPlayerItem(url: url)
      // Subtle lead-in gap on items after the first for natural pacing.
      return item
    }
    items = queueItems

    // Per-item failure: skip a failed line rather than blocking the sequence.
    for item in queueItems {
      let obs = item.observe(\AVPlayerItem.status, options: [.new]) {
        [weak self] observed, _ in
        guard observed.status == .failed else { return }
        Task { @MainActor in self?.handleFailedItem(observed) }
      }
      statusObservers.append(obs)
    }

    let queue = AVQueuePlayer(items: queueItems)
    queue.actionAtItemEnd = .advance
    queue.automaticallyWaitsToMinimizeStalling = true
    player = queue

    // Track which line is playing -> drive @Observable state for the UI.
    timeObserver = queue.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.15, preferredTimescale: 600), queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.syncPlayingLine() }
    }

    // Sequence finished when the LAST item plays to end.
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: queueItems.last, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.finish() }
    }

    queue.play()
  }

  /// Restart the active coach (convenience for tap-to-replay).
  func replay() {
    guard let id = activeCoachId,
      let coach = CoachPersona.library.first(where: { $0.id == id })
    else { return }
    play(coach)
  }

  /// Stop all playback and tear everything down. Safe to call repeatedly — used
  /// on dismiss / leaving the step / backgrounding.
  func stop() {
    player?.pause()
    teardown()
    if state != .idle { state = .idle }
    activeCoachId = nil
  }

  // MARK: - Internals

  private func syncPlayingLine() {
    guard let player, let current = player.currentItem,
      let idx = items.firstIndex(of: current)
    else { return }
    let line = idx + 1
    if case .playing(let existing) = state, existing == line { return }
    if player.timeControlStatus == .playing || player.rate > 0 {
      state = .playing(line: line)
    }
  }

  private func handleFailedItem(_ failed: AVPlayerItem) {
    guard let player else { return }
    // If the failed item is the one queued next/current, advance past it so the
    // sequence keeps going. If it was the last item, finish.
    if player.currentItem == failed {
      if items.last == failed {
        finish()
      } else {
        player.advanceToNextItem()
      }
    }
  }

  private func finish() {
    teardown()
    state = .finished
    activeCoachId = nil
    deactivateSession()
  }

  private func teardown() {
    if let o = endObserver { NotificationCenter.default.removeObserver(o) }
    endObserver = nil
    if let t = timeObserver { player?.removeTimeObserver(t) }
    timeObserver = nil
    statusObservers.forEach { $0.invalidate() }
    statusObservers.removeAll()
    player?.removeAllItems()
    player = nil
    items.removeAll()
    removeInterruptionObservers()
    deactivateSession()
  }

  // MARK: - Audio session

  private func activateSession() {
    #if os(iOS)
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .spokenAudio, options: [])
      try? session.setActive(true)
    #endif
  }

  private func deactivateSession() {
    #if os(iOS)
      try? AVAudioSession.sharedInstance().setActive(
        false, options: [.notifyOthersOnDeactivation])
    #endif
  }

  private func observeInterruptions() {
    #if os(iOS)
      removeInterruptionObservers()
      let center = NotificationCenter.default

      // Incoming call / Siri: stop cleanly, never auto-resume mid-sequence.
      interruptionObserver = center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(), queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.stop() }
      }

      // Headphones unplugged etc.: pause (stop) the sequence.
      routeObserver = center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: AVAudioSession.sharedInstance(), queue: .main
      ) { [weak self] note in
        guard
          let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
          reason == .oldDeviceUnavailable
        else { return }
        Task { @MainActor in self?.stop() }
      }

      // Backgrounding stops audio immediately.
      backgroundObserver = center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.stop() }
      }
    #endif
  }

  private func removeInterruptionObservers() {
    #if os(iOS)
      let center = NotificationCenter.default
      if let o = interruptionObserver { center.removeObserver(o) }
      if let o = routeObserver { center.removeObserver(o) }
      if let o = backgroundObserver { center.removeObserver(o) }
      interruptionObserver = nil
      routeObserver = nil
      backgroundObserver = nil
    #endif
  }
}
