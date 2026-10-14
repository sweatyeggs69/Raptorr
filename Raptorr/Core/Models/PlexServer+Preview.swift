import Foundation

extension PlexServer {
    /// Placeholder used by previews and as the environment default.
    nonisolated static let preview = PlexServer(
        name: "Preview Server",
        uri: "http://127.0.0.1:32400",
        machineIdentifier: "preview",
        accessToken: "",
        owned: true,
        connections: []
    )
}
