import SwiftUI

/// Routes between sign-in, server selection and the main app.
struct RootView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection

    var body: some View {
        Group {
            if !authStore.isSignedIn {
                SignInView()
            } else if let server = connection.currentServer {
                MainTabView(server: server)
                    .id(server.machineIdentifier)
            } else {
                ServerPickerView()
            }
        }
        .animation(.default, value: authStore.isSignedIn)
        .animation(.default, value: connection.currentServer?.machineIdentifier)
    }
}

#Preview {
    RootView()
        .environment(AuthStore())
        .environment(ServerConnectionManager())
        .environment(PlaybackCoordinator())
}
