import Foundation
import Observation

/// Discovers the user's Plex servers, remembers the chosen one, and keeps its URI reachable.
@Observable
final class ServerConnectionManager {
    // tvOS has no guaranteed-persistent app file storage (Caches can be purged), so the
    // small selected-server record lives in UserDefaults, which tvOS does persist.
    private static let serverKey = "selectedServer"

    private(set) var currentServer: PlexServer?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.serverKey),
           let server = try? JSONDecoder().decode(PlexServer.self, from: data) {
            currentServer = server
        }
    }

    func select(_ server: PlexServer) {
        currentServer = server
        if let data = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(data, forKey: Self.serverKey)
        }
    }

    func disconnect() {
        currentServer = nil
        UserDefaults.standard.removeObject(forKey: Self.serverKey)
    }

    // MARK: - Discovery

    /// Every server on the account that answers on at least one connection.
    func discoverServers(token: String, client: PlexAPIClient) async throws -> [PlexServer] {
        let resources = try await client.resources(token: token).filter(\.isServer)
        return await withTaskGroup(of: PlexServer?.self) { group in
            for resource in resources {
                guard let accessToken = resource.accessToken,
                      let machineIdentifier = resource.clientIdentifier else { continue }
                let connections = resource.connections ?? []
                let name = resource.name ?? "Plex Media Server"
                let owned = resource.owned ?? false
                group.addTask {
                    guard let uri = await self.firstReachableURI(connections: connections, token: accessToken) else {
                        return nil
                    }
                    return PlexServer(
                        name: name,
                        uri: uri,
                        machineIdentifier: machineIdentifier,
                        accessToken: accessToken,
                        owned: owned,
                        connections: connections
                    )
                }
            }
            var servers: [PlexServer] = []
            for await server in group {
                if let server { servers.append(server) }
            }
            return servers.sorted { lhs, rhs in
                if lhs.owned != rhs.owned { return lhs.owned }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    /// Re-checks the saved server's connections, switching to a better one when the
    /// network changed since last launch (e.g. local address now reachable).
    func refreshConnection() async {
        guard let server = currentServer,
              let uri = await firstReachableURI(connections: server.connections, token: server.accessToken),
              uri != server.uri else { return }
        select(server.with(uri: uri))
    }

    // MARK: - Probing

    /// Tries local connections first, then direct remote ones, then Plex relays.
    private func firstReachableURI(connections: [PlexConnection], token: String) async -> String? {
        let local = connections.filter { $0.local == true }
        let remote = connections.filter { $0.local != true && $0.relay != true }
        let relay = connections.filter { $0.relay == true }
        for (tier, timeout) in [(local, 3.0), (remote, 6.0), (relay, 8.0)] {
            let uris = tier.compactMap(\.uri)
            if let uri = await firstResponding(uris: uris, token: token, timeout: timeout) {
                return uri
            }
        }
        return nil
    }

    private func firstResponding(uris: [String], token: String, timeout: TimeInterval) async -> String? {
        guard !uris.isEmpty else { return nil }
        return await withTaskGroup(of: String?.self) { group in
            for uri in uris {
                group.addTask {
                    await self.responds(uri: uri, token: token, timeout: timeout) ? uri : nil
                }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }

    /// `GET /identity` is cheap and answers on any reachable PMS.
    private func responds(uri: String, token: String, timeout: TimeInterval) async -> Bool {
        guard var components = URLComponents(string: uri) else { return false }
        components.path = "/identity"
        guard let url = components.url else { return false }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        for (field, value) in PlexAPIClient.identificationHeaders() {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        guard let result = try? await URLSession.shared.data(for: request),
              let http = result.1 as? HTTPURLResponse else { return false }
        return (200...299).contains(http.statusCode)
    }
}
