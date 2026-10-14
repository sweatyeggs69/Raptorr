import Foundation
import Observation

@Observable
final class ServerPickerViewModel {
    private(set) var servers: [PlexServer] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load(token: String, client: PlexAPIClient, connection: ServerConnectionManager) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            servers = try await connection.discoverServers(token: token, client: client)
            if servers.count == 1, let only = servers.first {
                connection.select(only)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
