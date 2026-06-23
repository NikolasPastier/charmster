import AVFoundation
import Foundation
import UIKit

/// Resolves clip URLs for `(AvatarPersona, AvatarState)` and caches downloads
/// on disk.
///
/// Clips live in the public Supabase Storage bucket `Avatars`. Each persona has
/// a folder of `.mp4` clips, and a per-state filename manifest maps an
/// `AvatarState` to the actual object name. This indirection means swapping in
/// new/extra clips later is a DATA-ONLY change: update `ClipManifest` (and drop
/// the file in the bucket) — no view/director code changes.
///
/// States with no clip yet (e.g. Mia has no dedicated `idle`/`thinking`/`cool`/
/// `reassure` clip) resolve via `baseFallback` to a clip that does exist, so the
/// avatar never shows a black frame. If nothing resolves, the lookup returns
/// `nil` and `AvatarView` paints the bundled fallback still.
@MainActor
final class AvatarClipCatalog {

  static let shared = AvatarClipCatalog()

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
    self.cacheDir = base.appendingPathComponent("avatar-clips", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
  }

  // MARK: - Storage config

  /// Public Supabase Storage bucket holding the photoreal avatar clips.
  /// CONFIGURABLE: change `bucket` / per-persona folder + filenames in the
  /// `ClipManifest` to point at different assets — no other code edits needed.
  private static let bucket = "Avatars"

  /// Storage base, e.g. `https://<ref>.supabase.co`. Falls back to the linked
  /// project ref when SUPABASE_URL isn't injected.
  private var storageBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    return (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  // MARK: - Manifest

  /// Maps a persona + state to the exact Storage object path (relative to the
  /// bucket). Returns `nil` when no clip exists for that state (caller may then
  /// try `baseFallback`).
  ///
  /// New naming convention (all 5 avatars — Mia, Ava, Sofia, Mei, Nia):
  ///   {DisplayName}/clips/{id} {state name}.mp4
  /// e.g. "Mia/clips/mia talking loop.mp4", "Ava/clips/ava smile reaction.mp4"
  /// `.thinking` has no dedicated loop clip — falls back to `.idle` via
  /// `baseFallbackState`. One-shot reactions map to "{id} {name} reaction.mp4".
  private func objectPath(for persona: AvatarPersona, state: AvatarState) -> String? {
    let folder = persona.displayName  // e.g. "Mia", "Ava", "Sofia", "Mei", "Nia"
    let id = persona.id               // e.g. "mia", "ava", "sofia", "mei", "nia"

    let stateName: String?
    switch state {
    case .idle:      stateName = "idle loop"
    case .talking:   stateName = "talking loop"
    case .listening: stateName = "listening loop"
    case .thinking:  stateName = nil  // no loop clip — baseFallbackState returns .idle
    case .smile:     stateName = "smile reaction"
    case .laugh:     stateName = "laugh reaction"
    case .flirty:    stateName = "flirty reaction"
    case .surprised: stateName = "surprised reaction"
    case .cool:      stateName = "cool reaction"
    case .reassure:  stateName = "reassure reaction"
    }

    guard let sn = stateName else { return nil }
    return "\(folder)/clips/\(id) \(sn).mp4"
  }

  /// A base looping state that is guaranteed to exist for all personas.
  /// Used as a last-resort fallback so a looping request never resolves to nothing.
  private func baseFallbackState(for persona: AvatarPersona) -> AvatarState? {
    .idle
  }

  // MARK: - Public surface

  /// Remote URL for the clip, or `nil` if no clip is mapped for this state.
  func remoteClipURL(for persona: AvatarPersona, state: AvatarState) -> URL? {
    guard let path = objectPath(for: persona, state: state) else { return nil }
    let full = "\(Self.bucket)/\(path)"
    guard let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(encoded)")
  }

  /// Returns a local file URL ready for `AVPlayer`. Downloads + caches the clip
  /// on first use. For looping base states with no dedicated clip, falls back
  /// to the persona's guaranteed base clip. Returns `nil` only when nothing is
  /// available (offline / no clip) so `AvatarView` keeps the still.
  func localClipURL(for persona: AvatarPersona, state: AvatarState) async -> URL? {
    if let url = await resolveLocal(persona: persona, state: state) { return url }
    // Fallback: for a looping state, try the persona's guaranteed base clip.
    if state.isLooping, let fb = baseFallbackState(for: persona), fb != state {
      return await resolveLocal(persona: persona, state: fb)
    }
    return nil
  }

  private func resolveLocal(persona: AvatarPersona, state: AvatarState) async -> URL? {
    guard let remote = remoteClipURL(for: persona, state: state) else { return nil }
    // Cache key uses the object path so two states sharing one clip dedupe.
    let key = (objectPath(for: persona, state: state) ?? "\(persona.id)_\(state.rawValue)")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: " ", with: "_")
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

  /// Warm the on-device cache for the looping base states + the most common
  /// reactions BEFORE a live session starts. Best-effort; failures are silent.
  func preload(persona: AvatarPersona) async {
    let warm: [AvatarState] = [.idle, .listening, .talking, .smile, .laugh]
    await withTaskGroup(of: Void.self) { group in
      for s in warm {
        group.addTask { [weak self] in
          _ = await self?.localClipURL(for: persona, state: s)
        }
      }
    }
  }

  /// First-frame still extracted from the base looping clip if available,
  /// otherwise `nil` so `AvatarView` paints the bundled fallback still.
  func idleStill(for persona: AvatarPersona) async -> UIImage? {
    let state = baseFallbackState(for: persona) ?? .idle
    guard let url = await localClipURL(for: persona, state: state) else { return nil }
    let asset = AVURLAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    return await withCheckedContinuation { cont in
      gen.generateCGImageAsynchronously(for: .zero) { cg, _, _ in
        if let cg {
          cont.resume(returning: UIImage(cgImage: cg))
        } else {
          cont.resume(returning: nil)
        }
      }
    }
  }

  /// Wipe the on-disk clip cache (used by Settings -> reset).
  func clearCache() {
    try? FileManager.default.removeItem(at: cacheDir)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
  }
}
