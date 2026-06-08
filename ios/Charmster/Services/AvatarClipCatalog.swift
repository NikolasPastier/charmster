import Foundation
import AVFoundation
import UIKit

/// Resolves clip URLs for `(AvatarPersona, AvatarState)` and caches downloads
/// on disk. Until the Supabase `avatar-clips` bucket is populated, every lookup
/// returns `nil` and `AvatarView` falls back to a bundled still + Aura glow.
///
/// Swapping in real clips later is a DATA-ONLY change: drop the `.mp4` files in
/// the bucket under `<persona.bucketFolder>/<state>.mp4` and the catalog picks
/// them up automatically on next session.
@MainActor
final class AvatarClipCatalog {

    static let shared = AvatarClipCatalog()

    private let session: URLSession
    private let cacheDir: URL
    private var inflight: [URL: Task<URL?, Never>] = [:]

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.timeoutIntervalForRequest = 12
        self.session = URLSession(configuration: cfg)

        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheDir = base.appendingPathComponent("avatar-clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public surface

    /// Public Supabase Storage base URL for the `avatar-clips` bucket.
    /// Returns `nil` until SUPABASE_URL is configured (so callers can fall back).
    var bucketBaseURL: URL? {
        let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/storage/v1/object/public/avatar-clips")
    }

    /// Returns the remote URL where the clip *would* live in the bucket.
    /// Existence is not guaranteed — `localClipURL(for:state:)` handles 404s
    /// silently and returns `nil` so `AvatarView` falls back to the still.
    func remoteClipURL(for persona: AvatarPersona, state: AvatarState) -> URL? {
        guard let base = bucketBaseURL else { return nil }
        return base
            .appendingPathComponent(persona.bucketFolder, isDirectory: true)
            .appendingPathComponent("\(state.rawValue).mp4")
    }

    /// Returns a local file URL ready for `AVPlayer`. Downloads the clip on
    /// first use and caches it. Returns `nil` if the clip is missing/offline.
    func localClipURL(for persona: AvatarPersona, state: AvatarState) async -> URL? {
        guard let remote = remoteClipURL(for: persona, state: state) else { return nil }
        let local = cacheDir.appendingPathComponent("\(persona.id)_\(state.rawValue).mp4")
        if FileManager.default.fileExists(atPath: local.path) { return local }

        if let task = inflight[remote] {
            return await task.value
        }
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

    /// Warm the on-device cache for the looping base states + a still preview
    /// frame BEFORE a live session starts. Best-effort; failures are silent.
    func preload(persona: AvatarPersona) async {
        let warm: [AvatarState] = [.idle, .listening, .talking, .thinking]
        await withTaskGroup(of: Void.self) { group in
            for s in warm {
                group.addTask { [weak self] in
                    _ = await self?.localClipURL(for: persona, state: s)
                }
            }
        }
    }

    /// First-frame still extracted from the `idle` clip if available, otherwise
    /// `nil` so `AvatarView` paints the bundled fallback still.
    func idleStill(for persona: AvatarPersona) async -> UIImage? {
        guard let url = await localClipURL(for: persona, state: .idle) else { return nil }
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        return await withCheckedContinuation { cont in
            gen.generateCGImageAsynchronously(for: .zero) { cg, _, _ in
                if let cg { cont.resume(returning: UIImage(cgImage: cg)) }
                else { cont.resume(returning: nil) }
            }
        }
    }

    /// Wipe the on-disk clip cache (used by Settings -> reset).
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
