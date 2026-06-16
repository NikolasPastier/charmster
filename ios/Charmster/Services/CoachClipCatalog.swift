import AVFoundation
import Foundation
import UIKit

/// Resolves clip URLs for `(CoachPersona, CoachAvatarState)` and caches
/// downloads on disk. This is the SINGLE SOURCE OF TRUTH for coach visuals;
/// the Lecture-Redesign prompt consumes it as-is.
///
/// Clips live in the public Supabase Storage bucket `Avatars` under
/// `coach-clips/{coachId}/{state}.mp4`. The per-state filename indirection
/// means swapping in real clips later is a DATA-ONLY change: edit `objectPath`
/// (and drop the file in the bucket) — no view/director code changes.
///
/// No coach clip set is uploaded yet, so every lookup currently returns `nil`
/// and `CoachAvatarView` paints the coach's Aura-gradient fallback (never a
/// black frame). When clips land, populate `objectPath` and everything else
/// just works.
@MainActor
final class CoachClipCatalog {

  static let shared = CoachClipCatalog()

  private let session: URLSession
  private let cacheDir: URL
  private var inflight: [URL: Task<URL?, Never>] = [:]

  private init() {
    let cfg = URLSessionConfiguration.default
    cfg.requestCachePolicy = .returnCacheDataElseLoad
    cfg.timeoutIntervalForRequest = 20
    self.session = URLSession(configuration: cfg)

    let base =
      FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    self.cacheDir = base.appendingPathComponent("coach-clips", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
  }

  // MARK: - Storage config

  /// Public Supabase Storage bucket holding the coach clips. Reuses the same
  /// `Avatars` bucket as the partner avatars, in a `coach-clips/` subtree.
  private static let bucket = "Avatars"
  private static let root = "coach-clips"

  /// Subtree holding the uploaded coach STILL images and clips.
  /// Layout: `Coaches/{storageId}/stills/{storageId} neutral scene.jpeg`
  ///         `Coaches/{storageId}/clips/{storageId} idle.mp4`
  ///         `Coaches/{storageId}/clips/{storageId} talking 1.mp4` …
  private static let coachesRoot = "Coaches"

  /// The five shipped coach IDs that have uploaded clip sets in Supabase.
  private static let clippedCoachIds: Set<String> = ["theo", "ray", "cole", "noah", "leo"]

  /// Number of `talking` takes available per coach. The player picks ONE take
  /// when a lecture opens and holds it for the whole lecture.
  private static let talkingTakeCount = 2

  /// Maps a `CoachPersona.id` to its Storage folder name. Identical for most
  /// coaches; `dr_ray` lives under `ray` in the bucket.
  private func storageId(for persona: CoachPersona) -> String {
    switch persona.id {
    case "dr_ray": return "ray"
    default: return persona.id
    }
  }

  /// Object path (relative to the bucket) for the coach's neutral STILL image.
  /// This is the active visual for every state until clips are uploaded. We use
  /// the branded "neutral scene" JPEG (background baked in) for display. The
  /// "neutral cutout.png" is backup only and is NOT used for display.
  ///
  /// DATA-ONLY: to repoint a coach's still, change the filename here — no view
  /// or director edits. To add motion, populate `objectPath(for:state:)`; the
  /// player crossfades over this still automatically.
  private func stillObjectPath(for persona: CoachPersona) -> String {
    let id = storageId(for: persona)
    return "\(Self.coachesRoot)/\(id)/stills/\(id) neutral scene.jpeg"
  }

  /// Public URL for the coach's neutral still image.
  private func remoteStillURL(for persona: CoachPersona) -> URL? {
    let full = "\(Self.bucket)/\(stillObjectPath(for: persona))"
    guard let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(encoded)")
  }

  private var storageBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    return (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  // MARK: - Manifest

  /// SINGLE SOURCE OF TRUTH for coach clip object paths. Builds the path inside
  /// the bucket for `(coachId, state, take)`:
  ///   `Coaches/{id}/clips/{id} idle.mp4`
  ///   `Coaches/{id}/clips/{id} talking 1.mp4`  (talking takes are 1-based)
  /// Only the looping base states (idle/talking) have uploaded clips. One-shot
  /// reactions are not used in the lecture player and resolve to `nil`.
  private func clipObjectPath(coachStorageId id: String, state: CoachAvatarState, take: Int)
    -> String?
  {
    let base = "\(Self.coachesRoot)/\(id)/clips/\(id)"
    switch state {
    case .idle, .thinking:
      return "\(base) idle.mp4"
    case .talking:
      let n = max(1, min(Self.talkingTakeCount, take))
      return "\(base) talking \(n).mp4"
    case .emphasize, .affirm, .laugh:
      // Reactions reuse the talking loop visual in the lecture context.
      let n = max(1, min(Self.talkingTakeCount, take))
      return "\(base) talking \(n).mp4"
    }
  }

  /// SINGLE place where the full public URL (path + percent-encoding) is built.
  /// `take` is the 1-based talking take; ignored for idle.
  /// Returns `nil` when this coach has no uploaded clip set.
  func coachClipURL(id storageId: String, state: CoachAvatarState, index take: Int = 1) -> URL? {
    guard Self.clippedCoachIds.contains(storageId) else { return nil }
    guard let path = clipObjectPath(coachStorageId: storageId, state: state, take: take) else {
      return nil
    }
    let full = "\(Self.bucket)/\(path)"
    // URL-encode every segment (spaces -> %20) via a single allowed-char pass.
    guard let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(encoded)")
  }

  /// Number of talking takes available; callers pick one randomly per lecture.
  var talkingTakeCount: Int { Self.talkingTakeCount }

  // MARK: - Legacy still path

  /// Maps a coach + state to the exact Storage object path (relative to the
  /// bucket). Returns `nil` when no clip exists yet for that pair.
  private func objectPath(for persona: CoachPersona, state: CoachAvatarState) -> String? {
    guard Self.clippedCoachIds.contains(storageId(for: persona)) else { return nil }
    return clipObjectPath(coachStorageId: storageId(for: persona), state: state, take: 1)
  }

  /// A guaranteed looping base state, used so a looping request still resolves
  /// when only some clips exist for a coach.
  private func baseFallbackState(for persona: CoachPersona) -> CoachAvatarState? {
    objectPath(for: persona, state: .idle) != nil ? .idle : nil
  }

  // MARK: - Public surface

  func remoteClipURL(for persona: CoachPersona, state: CoachAvatarState) -> URL? {
    coachClipURL(id: storageId(for: persona), state: state, index: 1)
  }

  /// Remote URL for a specific talking take of this coach.
  func remoteClipURL(for persona: CoachPersona, state: CoachAvatarState, take: Int) -> URL? {
    coachClipURL(id: storageId(for: persona), state: state, index: take)
  }

  /// Local file URL ready for `AVPlayer`, downloading + caching on first use.
  /// Falls back to the coach's guaranteed base clip for looping states. Returns
  /// `nil` only when nothing is available, so the view keeps the fallback still.
  func localClipURL(for persona: CoachPersona, state: CoachAvatarState) async -> URL? {
    await localClipURL(for: persona, state: state, take: 1)
  }

  /// Take-aware variant: resolves a specific talking take (1-based). Idle
  /// ignores `take`. Falls back to the coach's idle clip for looping states.
  func localClipURL(for persona: CoachPersona, state: CoachAvatarState, take: Int) async -> URL? {
    if let url = await resolveLocal(persona: persona, state: state, take: take) { return url }
    if state.isLooping, let fb = baseFallbackState(for: persona), fb != state {
      return await resolveLocal(persona: persona, state: fb, take: 1)
    }
    return nil
  }

  private func resolveLocal(persona: CoachPersona, state: CoachAvatarState, take: Int) async -> URL?
  {
    guard let remote = remoteClipURL(for: persona, state: state, take: take) else { return nil }
    let key = "\(storageId(for: persona))_\(state.rawValue)_\(take)"
    let local = cacheDir.appendingPathComponent(key)
    if FileManager.default.fileExists(atPath: local.path) { return local }

    if let task = inflight[remote] { return await task.value }
    let task = Task<URL?, Never> {
      defer { Task { @MainActor in self.inflight[remote] = nil } }
      do {
        let (tmp, resp) = try await session.download(from: remote)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
          try? FileManager.default.removeItem(at: tmp)
          return nil
        }
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: tmp, to: local)
        return local
      } catch {
        return nil
      }
    }
    inflight[remote] = task
    return await task.value
  }

  /// Warm the on-device cache for idle + a SPECIFIC talking take + the still
  /// fallback BEFORE the lecture starts. Best-effort; failures are silent.
  func preload(persona: CoachPersona, talkingTake: Int = 1) async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { [weak self] in _ = await self?.localClipURL(for: persona, state: .idle) }
      group.addTask { [weak self] in
        _ = await self?.localClipURL(for: persona, state: .talking, take: talkingTake)
      }
      group.addTask { [weak self] in _ = await self?.idleStill(for: persona) }
    }
  }

  /// Pick a stable talking take for a lecture session (1-based).
  func randomTalkingTake() -> Int {
    Int.random(in: 1...Self.talkingTakeCount)
  }

  /// Neutral STILL image for the coach. Until clips are uploaded this is the
  /// active visual for EVERY state (idle/talking/thinking/reactions), so coaches
  /// show their real photo instead of a gradient. Downloads + caches on first
  /// use. Returns `nil` only on offline/load failure, in which case the view
  /// paints the Aura-gradient fallback.
  func idleStill(for persona: CoachPersona) async -> UIImage? {
    // Prefer a real clip first frame if clips ever land.
    if let state = baseFallbackState(for: persona),
      let url = await localClipURL(for: persona, state: state)
    {
      let asset = AVURLAsset(url: url)
      let gen = AVAssetImageGenerator(asset: asset)
      gen.appliesPreferredTrackTransform = true
      let frame: UIImage? = await withCheckedContinuation { cont in
        gen.generateCGImageAsynchronously(for: .zero) { cg, _, _ in
          cont.resume(returning: cg.map(UIImage.init(cgImage:)))
        }
      }
      if let frame { return frame }
    }
    // No clip → use the uploaded neutral still.
    return await loadStillImage(for: persona)
  }

  private func loadStillImage(for persona: CoachPersona) async -> UIImage? {
    guard let remote = remoteStillURL(for: persona) else { return nil }
    let key = "still_\(storageId(for: persona)).jpeg"
    let local = cacheDir.appendingPathComponent(key)
    if let data = try? Data(contentsOf: local), let img = UIImage(data: data) {
      return img
    }
    do {
      let (data, resp) = try await session.data(from: remote)
      if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        return nil
      }
      try? data.write(to: local)
      return UIImage(data: data)
    } catch {
      return nil
    }
  }

  func clearCache() {
    try? FileManager.default.removeItem(at: cacheDir)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
  }
}
