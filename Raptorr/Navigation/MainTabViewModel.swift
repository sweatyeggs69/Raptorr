import Foundation
import Network
import Observation

@Observable
final class MainTabViewModel {
    private(set) var sections: [LibrarySection] = []
    private(set) var errorMessage: String?

    /// Shows the cached library list right away, then replaces it with the server's.
    func loadSections(server: PlexServer, client: PlexAPIClient) async {
        if sections.isEmpty, let cached = try? await client.librarySections(server: server, from: .cache) {
            sections = cached.filter(\.isSupported)
        }
        do {
            let fresh = try await client.librarySections(server: server).filter(\.isSupported)
            if fresh != sections { sections = fresh }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Picks the best connection now, then again whenever the network changes.
    func keepConnectionFresh(connection: ServerConnectionManager, client: PlexAPIClient, token: String?) async {
        await connection.refreshConnection(token: token, client: client)
        for await _ in NWPathMonitor().dropFirst() {
            await connection.refreshConnection(token: token, client: client)
        }
    }
}
