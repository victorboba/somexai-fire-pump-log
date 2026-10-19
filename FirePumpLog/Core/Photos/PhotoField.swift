import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

/// One photo on a record: add it, change it, delete it.
///
/// Drop it straight into a Form section and bind it to a `Data?` on the model. Images are
/// downscaled before they are stored, because a logging app shows a photo at a few hundred points
/// and a full-resolution capture is twenty times the bytes for no visible gain.
///
///     @State private var photoData: Data?
///     PhotoField(data: $photoData, label: "Photo of the site")
///
/// **Why one control and not two.** Taking a photo and choosing one are not two features; they
/// are two sources for one action, and iOS presents them that way — Contacts, Health's Medical
/// ID and Game Center all show a single control that opens a short menu. Two side-by-side
/// buttons also break: the second label wraps at narrow widths and the pills end up different
/// heights.
///
/// The wording is Apple's own, taken from the strings those apps ship: **Add Photo** when there
/// is none and **Change Photo** when there is, opening **Take Photo** / **Choose Photo**, with
/// **Delete Photo** to remove one. UIKit itself ships "Take Photo"; Contacts, Medical ID and
/// AddressBookUI ship "Choose Photo" and "Delete Photo"; Game Center and Messages ship
/// "Change Photo".
///
/// The camera needs `NSCameraUsageDescription` in the target's Info.plist or the app crashes the
/// moment it opens. `project.yml` in this template already sets it; say what the photo is for.
struct PhotoField: View {
    @Binding var data: Data?
    var label: String = "Photo"
    /// The longest edge kept. 1200 suits a photo someone may zoom into, such as a meter or a
    /// skin check; 600 is plenty for a thumbnail on a card.
    var maxSide: CGFloat = 1200

    @State private var libraryItem: PhotosPickerItem?
    @State private var choosingPhoto = false
    @State private var takingPhoto = false
    @State private var cameraDenied = false

    /// Devices without a camera never see the option, rather than seeing one that fails.
    private var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(label)
            }

            Menu {
                if hasCamera {
                    Button { startCamera() } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
                Button { choosingPhoto = true } label: {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                }
                if data != nil {
                    Divider()
                    Button(role: .destructive) { data = nil } label: {
                        Label("Delete Photo", systemImage: "trash")
                    }
                }
            } label: {
                Label(data == nil ? "Add Photo" : "Change Photo",
                      systemImage: data == nil ? "camera" : "photo")
            }
            .accessibilityHint(data == nil
                               ? "Take a new photo or choose an existing one"
                               : "Replace or delete \(label.lowercased())")
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $libraryItem, matching: .images)
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraCapture { image in
                data = PhotoField.downscale(image, maxSide: maxSide)
            }
            .ignoresSafeArea()
        }
        .alert("\(AppConfig.appName) does not have access to the camera", isPresented: $cameraDenied) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can enable camera access in Settings.")
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let loaded = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: loaded) {
                    data = PhotoField.downscale(image, maxSide: maxSide)
                }
                libraryItem = nil
            }
        }
    }

    /// Asks once, then opens the camera. A refusal gets a sentence and a way to fix it, rather
    /// than a black screen or nothing happening at all.
    private func startCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            takingPhoto = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { takingPhoto = true } else { cameraDenied = true }
                }
            }
        default:
            cameraDenied = true
        }
    }

    /// Shrinks to `maxSide` on the longest edge and re-encodes as JPEG. Returns the original
    /// encoding when the image is already small enough.
    static func downscale(_ image: UIImage, maxSide: CGFloat = 1200, quality: CGFloat = 0.85) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image.jpegData(compressionQuality: quality) }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: quality)
    }
}

/// The system camera. `UIImagePickerController` rather than an AVFoundation viewfinder: it is
/// fifteen lines instead of two hundred, and a logging app wants the familiar shutter, not a
/// custom one.
struct CameraCapture: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
