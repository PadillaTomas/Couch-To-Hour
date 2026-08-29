import SwiftUI
import UIWorkouts

struct OnboardingModeStep: View {
    @Binding var selection: TrainingMode?

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.xl) {
            WKScreenHeader(eyebrow: Copy.Onboarding.modeEyebrow,
                           title: Copy.Onboarding.modeTitle,
                           body: Copy.Onboarding.modeBody)

            VStack(spacing: WKSpace.md) {
                WKChoiceCard(title: Copy.Onboarding.threeDayTitle,
                             body: Copy.Onboarding.threeDayBody,
                             isSelected: selection == .threeDay) { selection = .threeDay }
                WKChoiceCard(title: Copy.Onboarding.freeTitle,
                             body: Copy.Onboarding.freeBody,
                             isSelected: selection == .free) { selection = .free }
            }
        }
    }
}

struct OnboardingPhilosophyStep: View {
    var body: some View {
        VStack(spacing: WKSpace.lg) {
            Text(Copy.Onboarding.philosophyTitle)
                .wkFont(.titleL)
                .foregroundStyle(WKColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(Copy.Onboarding.philosophyBody1)
                .wkFont(.body)
                .foregroundStyle(WKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(Copy.Onboarding.philosophyBody2)
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
            WKScreenHeader(title: Copy.Onboarding.startingWeekTitle,
                           body: Copy.Onboarding.startingWeekBody)

            VStack(spacing: WKSpace.sm) {
                ForEach(Array(Copy.Onboarding.weekBlurbs.enumerated()), id: \.offset) { index, blurb in
                    WKChoiceCard(title: Copy.Onboarding.weekLabel(index + 1),
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
            WKScreenHeader(title: Copy.Onboarding.startWeekdayTitle,
                           body: Copy.Onboarding.startWeekdayBody)

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
