import SwiftUI
import UIWorkouts

/// One-line summary of each plan week, shown in the starting-week picker.
/// Kept short enough to sit on a single line so every card is the same height
/// (a compact `WKChoiceCard` with a one-line body is a fixed size).
enum OnboardingCopy {
    static let weekBlurbs = [
        "One-minute run / walk intervals.",
        "Runs up to five minutes.",
        "Ten-minute run blocks.",
        "Fifteen-minute run blocks.",
        "A 20–30 min run, plus warm-up.",
        "Up to a 50-minute continuous run.",
    ]
}

struct OnboardingModeStep: View {
    @Binding var selection: TrainingMode?

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.xl) {
            WKScreenHeader(eyebrow: "Welcome",
                           title: "How do you want to run this?",
                           body: "You can change this later in Settings.")

            VStack(spacing: WKSpace.md) {
                WKChoiceCard(title: "3-Day Plan",
                             body: "Three sessions a week on set days, a rest day between each. We fill in your calendar.",
                             isSelected: selection == .threeDay) { selection = .threeDay }
                WKChoiceCard(title: "Free Run",
                             body: "Work through the weeks at your own pace. No schedule, no calendar.",
                             isSelected: selection == .free) { selection = .free }
            }
        }
    }
}

struct OnboardingPhilosophyStep: View {
    var body: some View {
        VStack(spacing: WKSpace.lg) {
            Text("This isn't a race.")
                .wkFont(.titleL)
                .foregroundStyle(WKColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Run at a pace where you could still hold a conversation. If you can't, slow down — that's the whole method, not a failure.")
                .wkFont(.body)
                .foregroundStyle(WKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The plan measures time spent running, never distance or speed. Miss a day and nothing breaks; the app just asks what you want to do next.")
                .wkFont(.body)
                .foregroundStyle(WKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnboardingStartingWeekStep: View {
    @Binding var selectionIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.xl) {
            WKScreenHeader(title: "Where do you want to start?",
                           body: "Week 1 assumes you're starting from scratch. Skip ahead if you already run.")

            VStack(spacing: WKSpace.sm) {
                ForEach(Array(OnboardingCopy.weekBlurbs.enumerated()), id: \.offset) { index, blurb in
                    WKChoiceCard(title: "Week \(index + 1)",
                                 body: blurb,
                                 isSelected: index == selectionIndex,
                                 compact: true) { selectionIndex = index }
                }
            }
        }
    }
}

struct OnboardingStartWeekdayStep: View {
    @Binding var selectionIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.xl) {
            WKScreenHeader(title: "Which day does your week start?",
                           body: "Sessions land on this day and every second day after, resetting each week.")

            WKWeekdayPicker(symbols: OnboardingCompletion.weekdaySymbols,
                            selection: $selectionIndex)
        }
    }
}

#Preview("Mode") {
    ScrollView { OnboardingModeStep(selection: .constant(.threeDay)).padding(WKSpace.lg) }
        .background(WKColor.bg)
}

#Preview("Starting week") {
    ScrollView { OnboardingStartingWeekStep(selectionIndex: .constant(2)).padding(WKSpace.lg) }
        .background(WKColor.bg)
}
