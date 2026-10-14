import SwiftUI

/// The top right corner's sync control: a spinner while background loading runs, otherwise
/// a button that starts a full library sync right away.
struct SyncButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isRunning {
                ProgressView()
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        .accessibilityLabel(isRunning ? "Syncing Library" : "Sync Library")
        .disabled(isRunning)
        .animation(.easeInOut, value: isRunning)
    }
}

#Preview {
    HStack(spacing: 40) {
        SyncButton(isRunning: false) {}
        SyncButton(isRunning: true) {}
    }
}
