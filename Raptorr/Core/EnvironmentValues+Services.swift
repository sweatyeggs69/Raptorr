import SwiftUI

extension EnvironmentValues {
    /// The app's Plex client. A hand-written key rather than `@Entry`: the macro warns about
    /// any class-typed default, even a shared instance, and the key's `static let` is
    /// created once.
    var plexClient: PlexAPIClient {
        get { self[PlexClientKey.self] }
        set { self[PlexClientKey.self] = newValue }
    }

    /// The connected server, set by `MainTabView` for everything below it.
    @Entry var plexServer: PlexServer = .preview
}

private nonisolated struct PlexClientKey: EnvironmentKey {
    static let defaultValue = PlexAPIClient.shared
}
