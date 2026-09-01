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
    /// Run intervals in the completed day (all held, since we only get here on a
    /// finished / marked-done session).
    let runIntervals: Int
    /// Sessions done so far this plan-week, including this one.
    let weekSessionsDone: Int
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var rating = 6

    private var coord: (week: Int, day: Int) { record.workoutCoordinate ?? (0, 0) }
    private var minutes: Int { record.durationSeconds / 60 }

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
                    WKScreenHeader(
                        eyebrow: Copy.PostWorkout.eyebrow(week: coord.week, day: coord.day),
                        title: Copy.PostWorkout.title(intervals: runIntervals),
                        body: Copy.PostWorkout.summary(minutes: minutes, intervals: runIntervals))

                    VStack(alignment: .leading, spacing: WKSpace.md) {
                        Text(Copy.PostWorkout.feelPrompt)
                            .wkFont(.headline)
                            .foregroundStyle(WKColor.textPrimary)
                        WKScaleSelector(
                            range: 1...10, selection: $rating,
                            endLabels: (Copy.PostWorkout.easyLabel, Copy.PostWorkout.hardLabel),
                            maxPerRow: 5)
                    }

                    WKCard {
                        VStack(spacing: WKSpace.md) {
                            WKMetricRow(title: Copy.PostWorkout.intervalsHeld,
                                        value: Copy.Format.ofCount(runIntervals, runIntervals),
                                        fraction: 1)
                            WKMetricRow(title: Copy.PostWorkout.weekSessions(coord.week),
                                        value: Copy.Format.ofCount(weekSessionsDone, 3),
                                        fraction: min(1, Double(weekSessionsDone) / 3),
                                        tint: WKPhase.walk.color)
                        }
                    }

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
        .alert(Copy.PostWorkout.addPhoto, isPresented: $showSourceDialog) {
            if cameraAvailable {
                Button(Copy.PostWorkout.takePhoto) { requestCamera() }
            }
            Button(Copy.PostWorkout.chooseFromLibrary) { showLibraryPicker = true }
            Button(Copy.PostWorkout.notNow, role: .cancel) {}
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
        record: CompletionRecord(date: .now, workoutDayKey: "W2D1", durationSeconds: 1320),
        runIntervals: 5,
        weekSessionsDone: 1,
        onDone: {}
    )
    .modelContainer(for: UserSettings.self, inMemory: true)
}
