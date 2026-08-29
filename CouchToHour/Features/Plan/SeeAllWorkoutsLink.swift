import SwiftUI
import UIWorkouts

/// A centered "See all workouts" link that opens the read-only ``PlanOverviewView``
/// as a sheet. Used in onboarding (before the choices) and in Settings (under
/// the Plan header) so the whole plan is browsable from anywhere.
///
/// `showsProgress` forwards to the sheet: off for onboarding (no history yet),
/// on from Settings (marks done / next).
struct SeeAllWorkoutsLink: View {
    var showsProgress = false

    @State private var isPresented = false

    var body: some View {
        WKButton(Copy.PlanOverview.onboardingLink, style: .quiet) {
            isPresented = true
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .sheet(isPresented: $isPresented) {
            PlanOverviewView(showsProgress: showsProgress)
        }
    }
}
