import SwiftUI
import UIWorkouts

/// Placeholder for the month calendar (built in CTH-7).
struct CalendarView: View {
    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(eyebrow: "Calendar",
                               title: "No history yet",
                               body: "Completed sessions will show here.")
                Spacer()
            }
            .padding(WKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    CalendarView()
}
