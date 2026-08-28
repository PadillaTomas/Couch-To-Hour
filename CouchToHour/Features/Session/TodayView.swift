import SwiftUI
import UIWorkouts

/// Placeholder for the Today / Up-Next screen (built in CTH-7).
struct TodayView: View {
    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(eyebrow: "Today",
                               title: "Nothing scheduled yet",
                               body: "Your plan appears here once onboarding is done.")
                Spacer()
            }
            .padding(WKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TodayView()
}
