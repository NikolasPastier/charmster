import PhotosUI
import SwiftUI

/// Tappable user avatar that opens the photo library, saves the picked image
/// (local cache + best-effort `user-avatars` upload), and writes the returned
/// object path onto `profile.profilePhotoPath`. Shows `UserAvatarView` with an
/// edit badge, plus an inline "Remove" affordance once a photo exists.
struct UserAvatarPicker: View {
  @Environment(AppState.self) private var app
  var size: CGFloat = 88
  var showsRemove: Bool = true

  @State private var selection: PhotosPickerItem?
  @State private var reloadToken = 0
  @State private var isWorking = false

  var body: some View {
    VStack(spacing: 10) {
      PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
        ZStack(alignment: .bottomTrailing) {
          UserAvatarView(
            name: app.profile.name,
            photoPath: app.profile.profilePhotoPath,
            size: size,
            reloadToken: reloadToken
          )
          .auraGlow(color: Theme.pink, radius: 16, intensity: 0.3)

          Circle()
            .fill(Theme.accent)
            .frame(width: size * 0.3, height: size * 0.3)
            .overlay(
              Image(systemName: isWorking ? "arrow.triangle.2.circlepath" : "camera.fill")
                .font(.system(size: size * 0.14, weight: .bold))
                .foregroundStyle(.white)
            )
            .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
        }
      }
      .buttonStyle(.plain)
      .disabled(isWorking)

      if showsRemove && hasPhoto {
        Button("Remove photo") { removePhoto() }
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Theme.textMuted)
      }
    }
    .onChange(of: selection) { _, item in
      guard let item else { return }
      Task { await load(item) }
    }
  }

  private var hasPhoto: Bool {
    UserAvatarStore.cachedImage() != nil || !app.profile.profilePhotoPath.isEmpty
  }

  private func load(_ item: PhotosPickerItem) async {
    isWorking = true
    defer { isWorking = false }
    guard let data = try? await item.loadTransferable(type: Data.self),
      let image = UIImage(data: data)
    else { return }
    let path = await UserAvatarStore.save(image, userId: app.userId)
    app.profile.profilePhotoPath = path
    app.persistSettings()
    reloadToken += 1
    selection = nil
    #if canImport(UIKit)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    #endif
  }

  private func removePhoto() {
    UserAvatarStore.clearLocal()
    app.profile.profilePhotoPath = ""
    app.persistSettings()
    reloadToken += 1
  }
}
