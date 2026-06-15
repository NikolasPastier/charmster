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

  /// Subtree holding the uploaded coach STILL images (and, later, clips).
  /// Layout: `Coaches/{storageId}/stills/{storageId} neutral cutout.png`.
  private static let coachesRoot = "Coaches"

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

  /// Maps a coach + state to the exact Storage object path (relative to the
  /// bucket). Returns `nil` when no clip exists yet for that pair.
  ///
  /// TODO(clips): no coach clip set is uploaded today. When clips land, return
  /// `"\(Self.root)/\(persona.id)/\(state.rawValue).mp4"` (and uncomment the
  /// production path below). Keep the fallback behaviour intact.
  private func objectPath(for persona: CoachPersona, state: CoachAvatarState) -> String? {
    // Production (enable when clips exist):
    // return "\(Self.root)/\(persona.id)/\(state.rawValue).mp4"
    return nil
  }

  /// A guaranteed looping base state, used so a looping request still resolves
  /// when only some clips exist for a coach.
  private func baseFallbackState(for persona: CoachPersona) -> CoachAvatarState? {
    // No coach clips uploaded yet → no guaranteed base.
    objectPath(for: persona, state: .idle) != nil ? .idle : nil
  }

  // MARK: - Public surface

  func remoteClipURL(for persona: CoachPersona, state: CoachAvatarState) -> URL? {
    guard let path = objectPath(for: persona, state: state) else { return nil }
    let full = "\(Self.bucket)/\(path)"
    guard let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(encoded)")
  }

  /// Local file URL ready for `AVPlayer`, downloading + caching on first use.
  /// Falls back to the coach's guaranteed base clip for looping states. Returns
  /// `nil` only when nothing is available, so the view keeps the fallback still.
  func localClipURL(for persona: CoachPersona, state: CoachAvatarState) async -> URL? {
    if let url = await resolveLocal(persona: persona, state: state) { return url }
    if state.isLooping, let fb = baseFallbackState(for: persona), fb != state {
      return await resolveLocal(persona: persona, state: fb)
    }
    return nil
  }

  private func resolveLocal(persona: CoachPersona, state: CoachAvatarState) async -> URL? {
    guard let remote = remoteClipURL(for: persona, state: state) else { return nil }
    let key = "\(persona.id)_\(state.rawValue)"
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

  /// Warm the on-device cache for idle + talking before a coached moment.
  /// Best-effort; failures are silent.
  func preload(persona: CoachPersona) async {
    let warm: [CoachAvatarState] = [.idle, .talking]
    await withTaskGroup(of: Void.self) { group in
      for s in warm {
        group.addTask { [weak self] in _ = await self?.localClipURL(for: persona, state: s) }
      }
    }
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
