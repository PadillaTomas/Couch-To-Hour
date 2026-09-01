import SwiftUI
import UIWorkouts

struct OnboardingModeStep: View {
    @Binding var selection: TrainingMode?

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.sm) {
            WKScreenHeader(eyebrow: Copy.Onboarding.modeEyebrow,
                           title: Copy.Onboarding.modeTitle,
                           body: Copy.Onboarding.modeBody)

            SeeAllWorkoutsLink()

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
        VStack(alignment: .leading, spacing: WKSpace.sm) {
            WKScreenHeader(title: Copy.Onboarding.startingWeekTitle,
                           body: Copy.Onboarding.startingWeekBody)

            SeeAllWorkoutsLink()

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

/// Re-run setup: start from the beginning, or pick a specific workout from the
/// plan browser.
struct StartingPointStep: View {
    @Binding var pickSpecific: Bool
    @Binding var weekIndex: Int
    @Binding var dayIndex: Int

    @State private var showBrowser = false

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.sm) {
            WKScreenHeader(title: Copy.Onboarding.startingWeekTitle)

            SeeAllWorkoutsLink()

            WKChoiceCard(title: Copy.PlanSetup.fromBeginningTitle,
                         body: Copy.PlanSetup.fromBeginningBody,
                         isSelected: !pickSpecific) { pickSpecific = false }

            WKChoiceCard(title: Copy.PlanSetup.fromSpecificTitle,
                         body: pickSpecific
                             ? Copy.PlanSetup.coord(week: weekIndex + 1, day: dayIndex + 1)
                             : Copy.PlanSetup.fromSpecificBody,
                         isSelected: pickSpecific) { showBrowser = true }
        }
        .sheet(isPresented: $showBrowser) {
            PlanOverviewView(showsProgress: true) { week, day in
                weekIndex = week - 1
                dayIndex = day - 1
                pickSpecific = true
                showBrowser = false
            }
        }
    }
}

/// The start-date step. 3-Day: pick the day your plan starts (defaults today) —
/// the schedule is built from it. Free: an optional first-run date for the
/// calendar; `isSet` off by default.
struct StartDateStep: View {
    let mode: TrainingMode
    @Binding var date: Date
    @Binding var isSet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WKSpace.lg) {
            switch mode {
            case .threeDay:
                WKScreenHeader(title: Copy.PlanSetup.startDateTitle,
                               body: Copy.PlanSetup.startDateBody)
                datePicker
            case .free:
                WKScreenHeader(title: Copy.PlanSetup.freeDateTitle,
                               body: Copy.PlanSetup.freeDateBody)
                WKInsetGroup {
                    WKToggleRow(Copy.PlanSetup.freeDateToggle, isOn: $isSet)
                }
                if isSet { datePicker }
            }
        }
    }

    private var datePicker: some View {
        DatePicker(selection: $date, in: Date.now..., displayedComponents: .date) { EmptyView() }
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(WKColor.accent)
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
