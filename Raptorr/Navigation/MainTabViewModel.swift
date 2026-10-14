import Foundation
import Observation

@Observable
final class MainTabViewModel {
    private(set) var sections: [LibrarySection] = []
    private(set) var errorMessage: String?

    func load(server: PlexServer, client: PlexAPIClient, connection: ServerConnectionManager) async {
        await connection.refreshConnection()
        let current = connection.currentServer ?? server
        do {
            sections = try await client.librarySections(server: current).filter(\.isSupported)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
