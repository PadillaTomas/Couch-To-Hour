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
                WKScreenHeader(eyebrow: "Nice work",
                               title: "How did that feel?",
                               body: "1 is easy, 10 is all out. It just helps you look back later.")
                WKScaleSelector(range: 1...10, selection: $rating, endLabels: ("Easy", "All out"))
                Spacer()
            }
            .padding(WKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            WKFooterActions {
                WKButton("Save") {
                    record.feltRating = rating
                    try? context.save()
                    onDone()
                }
                WKButton("Skip", style: .quiet) { onDone() }
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
