import SwiftUI
import UIKit

/// Stores and serves the HUMAN's own profile photo.
///
/// Display source of truth is a local cached JPEG in Application Support, so the
/// avatar shows instantly, offline, and before real auth lands. On save we also
/// best-effort upload to the public `user-avatars` Supabase bucket and return
/// the object path, which is persisted on `profile.profilePhotoPath` for future
/// cross-device sync once auth is wired.
enum UserAvatarStore {

  // MARK: - Local cache

  private static var cacheURL: URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("charmster-user-avatar.jpg")
  }

  /// The locally cached profile image, if one was saved.
  static func cachedImage() -> UIImage? {
    guard let data = try? Data(contentsOf: cacheURL) else { return nil }
    return UIImage(data: data)
  }

  static func clearLocal() {
    try? FileManager.default.removeItem(at: cacheURL)
  }

  // MARK: - Save (local + best-effort remote)

  /// Persists `image` locally and uploads it to the `user-avatars` bucket.
  /// Returns the remote object path on success (empty string if the upload
  /// failed — the local cache still holds the image so the UI stays correct).
  @discardableResult
  static func save(_ image: UIImage, userId: String) async -> String {
    let normalized = image.squareCropped(maxDimension: 1024)
    guard let data = normalized.jpegData(compressionQuality: 0.85) else { return "" }
    try? data.write(to: cacheURL, options: .atomic)
    return await upload(data: data, userId: userId)
  }

  // MARK: - Remote upload

  private static var supabaseBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
    return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  private static var anonKey: String? {
    let env = ProcessInfo.processInfo.environment
    for key in ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"] {
      if let v = env[key], !v.isEmpty { return v }
    }
    return nil
  }

  private static func upload(data: Data, userId: String) async -> String {
    guard let key = anonKey else { return "" }
    let safeUser = userId.isEmpty ? "preview-user" : userId
    let objectPath = "\(safeUser)/avatar.jpg"
    guard
      let encoded = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
      let url = URL(string: "\(supabaseBase)/storage/v1/object/user-avatars/\(encoded)")
    else { return "" }

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    // `upsert` lets the same user overwrite their previous avatar.
    req.setValue("true", forHTTPHeaderField: "x-upsert")
    req.httpBody = data

    do {
      let (_, response) = try await URLSession.shared.upload(for: req, from: data)
      if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
        return objectPath
      }
    } catch {
      TenXPreviewSupport.log("[UserAvatar] upload failed: \(error.localizedDescription)")
    }
    return ""
  }

  /// Public read URL for a stored object path (used when only the remote path
  /// is known and no local cache exists, e.g. a fresh install after sync).
  static func publicURL(for path: String) -> URL? {
    guard !path.isEmpty,
      let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    else { return nil }
    return URL(string: "\(supabaseBase)/storage/v1/object/public/user-avatars/\(encoded)")
  }
}

extension UIImage {
  /// Center-crops to a square and downscales so avatars are light + consistent.
  fileprivate func squareCropped(maxDimension: CGFloat) -> UIImage {
    let side = min(size.width, size.height)
    let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
    let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
    let scale = self.scale
    guard let cg = cgImage?.cropping(to: cropRect.applying(.init(scaleX: scale, y: scale)))
    else { return self }
    let cropped = UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)

    let target = min(maxDimension, side)
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target))
    return renderer.image { _ in
      cropped.draw(in: CGRect(x: 0, y: 0, width: target, height: target))
    }
  }
}
