import SwiftUI

/// A small spinner shown in the top right corner while background loading runs.
struct BackgroundActivityIndicator: View {
    let isRunning: Bool

    var body: some View {
        ProgressView()
            .accessibilityLabel("Updating Library")
            .opacity(isRunning ? 1 : 0)
            .animation(.easeInOut, value: isRunning)
    }
}

#Preview {
    BackgroundActivityIndicator(isRunning: true)
}
