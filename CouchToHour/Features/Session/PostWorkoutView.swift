import AVFoundation
import OSLog
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UIWorkouts

/// Shown right after a session finishes (timer or manual). Writes the effort
/// rating — and an optional photo — onto the `CompletionRecord` that was already
/// created.
struct PostWorkoutView: View {
    let record: CompletionRecord
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var rating = 6

    @State private var photoItem: PhotosPickerItem?
    /// The pick, held until the runner taps Save.
    @State private var pickedPhoto: UIImage?

    @State private var showSourceDialog = false
    @State private var showLibraryPicker = false
    @State private var showCamera = false
    @State private var showCameraDeniedAlert = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: WKSpace.xl) {
                    WKScreenHeader(eyebrow: Copy.PostWorkout.eyebrow,
                                   title: Copy.PostWorkout.title,
                                   body: Copy.PostWorkout.body)
                    WKScaleSelector(range: 1...10, selection: $rating,
                                    endLabels: (Copy.PostWorkout.easyLabel, Copy.PostWorkout.hardLabel))
                    photoSection
                }
                .padding(WKSpace.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            WKFooterActions {
                WKButton(Copy.PostWorkout.save, action: save)
                WKButton(Copy.PostWorkout.skip, style: .quiet) { onDone() }
            }
        }
        .confirmationDialog("", isPresented: $showSourceDialog, titleVisibility: .hidden) {
            if cameraAvailable {
                Button(Copy.PostWorkout.takePhoto) { requestCamera() }
            }
            Button(Copy.PostWorkout.chooseFromLibrary) { showLibraryPicker = true }
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $photoItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { pickedPhoto = image; photoItem = nil }
            }
            .ignoresSafeArea()
        }
        .alert(Copy.PostWorkout.cameraDeniedTitle, isPresented: $showCameraDeniedAlert) {
            Button(Copy.PostWorkout.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(Copy.PostWorkout.notNow, role: .cancel) {}
        } message: {
            Text(Copy.PostWorkout.cameraDeniedBody)
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    pickedPhoto = UIImage(data: data)
                }
            }
        }
    }

    @ViewBuilder private var photoSection: some View {
        VStack(alignment: .leading, spacing: WKSpace.sm) {
            Button { showSourceDialog = true } label: {
                if let pickedPhoto {
                    Image(uiImage: pickedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Text(Copy.PostWorkout.changePhoto)
                                .wkFont(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, WKSpace.sm)
                                .padding(.vertical, WKSpace.xs)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(WKSpace.sm)
                        }
                } else {
                    HStack(spacing: WKSpace.sm) {
                        Image(systemName: "photo.badge.plus")
                        Text(Copy.PostWorkout.addPhoto)
                    }
                    .wkFont(.body)
                    .foregroundStyle(WKColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(WKColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
                }
            }
            .buttonStyle(.plain)

            if pickedPhoto != nil {
                Button(Copy.PostWorkout.removePhoto) {
                    pickedPhoto = nil
                    photoItem = nil
                }
                .wkFont(.caption)
                .foregroundStyle(WKColor.danger)
            }
        }
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            // `.notDetermined` → the camera controller shows the system prompt itself.
            showCamera = true
        default:
            showCameraDeniedAlert = true
        }
    }

    private func save() {
        if let pickedPhoto {
            do {
                record.photoPath = try PhotoStore.save(pickedPhoto)
            } catch {
                AppLog.data.error("photo save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        record.feltRating = rating
        context.saveChanges("post-workout")
        onDone()
    }
}

#Preview {
    PostWorkoutView(
        record: CompletionRecord(date: .now, workoutDayKey: "W1D1", durationSeconds: 1200),
        onDone: {}
    )
    .modelContainer(for: UserSettings.self, inMemory: true)
}
