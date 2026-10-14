import SwiftUI

@main
struct RaptorrApp: App {
    @State private var authStore = AuthStore()
    @State private var connection = ServerConnectionManager()
    @State private var playback = PlaybackCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(connection)
                .environment(playback)
        }
    }
}
