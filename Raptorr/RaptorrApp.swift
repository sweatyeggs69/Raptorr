import SwiftUI

@main
struct RaptorrApp: App {
    @State private var authStore = AuthStore()
    @State private var connection = ServerConnectionManager()
    @State private var playback = PlaybackCoordinator()

    init() {
        // Artwork loads through AsyncImage on the shared session; give it room to keep
        // posters and backdrops between launches (Caches, so tvOS may purge it).
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(connection)
                .environment(playback)
        }
    }
}
