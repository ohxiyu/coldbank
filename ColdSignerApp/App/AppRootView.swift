import SwiftUI

struct AppRootView: View {
    @AppStorage("hasAcknowledgedPreAlpha") private var hasAcknowledgedPreAlpha = false

    var body: some View {
        Group {
            if hasAcknowledgedPreAlpha {
                HomeView()
            } else {
                WelcomeView {
                    hasAcknowledgedPreAlpha = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AppRootView()
}
