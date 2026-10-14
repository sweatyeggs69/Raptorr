import SwiftUI

/// The top left corner's sync control: a spinner while background loading runs, otherwise
/// a button that starts a full library sync right away. It stays focusable while running
/// (pressing it then does nothing), so focus can always reach it.
struct SyncButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !isRunning { action() }
        } label: {
            if isRunning {
                ProgressView()
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        .accessibilityLabel(isRunning ? "Syncing Library" : "Sync Library")
        .animation(.easeInOut, value: isRunning)
    }
}

#Preview {
    HStack(spacing: 40) {
        SyncButton(isRunning: false) {}
        SyncButton(isRunning: true) {}
    }
}
