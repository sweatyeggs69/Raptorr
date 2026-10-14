import SwiftUI

extension EnvironmentValues {
    @Entry var plexClient = PlexAPIClient()

    /// The connected server, set by `MainTabView` for everything below it.
    @Entry var plexServer: PlexServer = .preview
}
