import SwiftData
import SwiftUI
import UIWorkouts

/// Shown right after a session finishes (timer or manual). Writes the effort
/// rating onto the `CompletionRecord` that was already created.
struct PostWorkoutView: View {
    let record: CompletionRecord
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var rating = 6

    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(eyebrow: Copy.PostWorkout.eyebrow,
                               title: Copy.PostWorkout.title,
                               body: Copy.PostWorkout.body)
                WKScaleSelector(range: 1...10, selection: $rating,
                                endLabels: (Copy.PostWorkout.easyLabel, Copy.PostWorkout.hardLabel))
                Spacer()
            }
            .padding(WKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            WKFooterActions {
                WKButton(Copy.PostWorkout.save) {
                    record.feltRating = rating
                    context.saveChanges("rating")
                    onDone()
                }
                WKButton(Copy.PostWorkout.skip, style: .quiet) { onDone() }
            }
        }
    }
}

#Preview {
    PostWorkoutView(
        record: CompletionRecord(date: .now, workoutDayKey: "W1D1", durationSeconds: 1200),
        onDone: {}
    )
    .modelContainer(for: UserSettings.self, inMemory: true)
}
