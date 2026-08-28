import SwiftUI
import UIWorkouts

/// Placeholder home screen. Real screens (Timer, Today, Calendar, onboarding)
/// are built from `UIWorkouts` molecules on `develop`. This only proves the
/// design-system package links and its tokens resolve.
struct RootView: View {
    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            Text("HELLO")
                .wkFont(.titleL)
                .foregroundStyle(WKColor.textPrimary)
        }
    }
}

#Preview {
    RootView()
}
