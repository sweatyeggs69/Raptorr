import Foundation
import Observation

/// Discovers the user's Plex servers, remembers the chosen one, and keeps it on the best
/// connection: local first, then remote (WAN), then Plex relay.
@Observable
final class ServerConnectionManager {
    // tvOS has no guaranteed-persistent app file storage (Caches can be purged), so the
    // small selected-server record lives in UserDefaults, which tvOS does persist.
    private static let serverKey = "selectedServer"

    private(set) var currentServer: PlexServer?
    /// False after a refresh found no connection that answers.
    private(set) var isReachable = true

    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.serverKey),
           let server = try? JSONDecoder().decode(PlexServer.self, from: data) {
            currentServer = server
        }
    }

    func select(_ server: PlexServer) {
        currentServer = server
        isReachable = true
        if let data = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(data, forKey: Self.serverKey)
        }
    }

    func disconnect() {
        refreshTask?.cancel()
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
                    guard let uri = await Self.bestURI(
                        connections: connections,
                        machineIdentifier: machineIdentifier,
                        client: client
                    ) else { return nil }
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

    // MARK: - Keeping the best connection

    /// Re-picks the saved server's connection. Runs at launch, when the app returns to the
    /// foreground and when the network changes, so a server reached over the relay or WAN
    /// moves back to the local address as soon as it answers again (and the other way round).
    ///
    /// The address list is refreshed from plex.tv first, since a server's addresses can change
    /// between launches; without internet the saved list is used, so local playback still works.
    /// A newer refresh replaces one still running, since it may have probed the old network.
    func refreshConnection(token: String?, client: PlexAPIClient) async {
        refreshTask?.cancel()
        let task = Task { await performRefresh(token: token, client: client) }
        refreshTask = task
        await task.value
    }

    private func performRefresh(token: String?, client: PlexAPIClient) async {
        guard let server = currentServer else { return }
        var connections = server.connections
        if let token,
           let resources = try? await client.resources(token: token),
           let resource = resources.first(where: { $0.clientIdentifier == server.machineIdentifier }),
           let fresh = resource.connections, !fresh.isEmpty {
            connections = fresh
        }
        guard !Task.isCancelled, currentServer?.machineIdentifier == server.machineIdentifier else { return }

        guard let uri = await Self.bestURI(
            connections: connections,
            machineIdentifier: server.machineIdentifier,
            client: client
        ) else {
            if !Task.isCancelled { isReachable = false }
            return
        }
        guard !Task.isCancelled, currentServer?.machineIdentifier == server.machineIdentifier else { return }
        isReachable = true
        if uri != server.uri || connections != server.connections {
            select(server.with(uri: uri, connections: connections))
        }
    }

    // MARK: - Probing

    /// Tries every local connection, then every remote (WAN) one, then the relays. Within a
    /// group all URIs are probed together and the first to answer as this server wins; a later
    /// group is only tried once the earlier one has failed or timed out.
    private nonisolated static func bestURI(
        connections: [PlexConnection],
        machineIdentifier: String,
        client: PlexAPIClient
    ) async -> String? {
        for tier in PlexConnection.tiers(connections) {
            if let uri = await firstResponding(
                uris: tier.uris,
                machineIdentifier: machineIdentifier,
                timeout: tier.kind.probeTimeout,
                client: client
            ) {
                return uri
            }
        }
        return nil
    }

    private nonisolated static func firstResponding(
        uris: [String],
        machineIdentifier: String,
        timeout: TimeInterval,
        client: PlexAPIClient
    ) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            for uri in uris {
                group.addTask {
                    await client.machineIdentifier(atURI: uri, timeout: timeout) == machineIdentifier ? uri : nil
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
}
