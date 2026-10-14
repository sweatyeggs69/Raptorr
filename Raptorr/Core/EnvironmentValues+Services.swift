import SwiftUI

extension EnvironmentValues {
    @Entry var plexClient = PlexAPIClient()

    /// The connected server, set by `MainTabView` for everything below it.
    @Entry var plexServer: PlexServer = .preview

    /// Switches to the Home tab, set by `MainTabView`. Back on another tab's top level calls
    /// it, like the Apple TV app, instead of leaving the app.
    @Entry var showHomeTab: () -> Void = {}
}
