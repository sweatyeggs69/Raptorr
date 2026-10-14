import Foundation
import Testing
@testable import Raptorr

struct ConnectionPriorityTests {
    private let relay = PlexConnection(uri: "https://relay.plex.direct:8443", local: false, relay: true)
    private let remote = PlexConnection(uri: "https://1-2-3-4.abc.plex.direct:32400", local: false, relay: false)
    private let local = PlexConnection(uri: "https://192-168-1-10.abc.plex.direct:32400", local: true, relay: false)

    @Test func tiersAreLocalThenRemoteThenRelay() {
        let tiers = PlexConnection.tiers([relay, remote, local])

        #expect(tiers.map(\.kind) == [.local, .remote, .relay])
        #expect(tiers.first?.uris == [local.uri])
    }

    @Test func emptyTiersAreDropped() {
        #expect(PlexConnection.tiers([relay]).map(\.kind) == [.relay])
    }

    @Test func connectionWithoutFlagsCountsAsRemote() {
        #expect(PlexConnection(uri: "http://example.com:32400", local: nil, relay: nil).kind == .remote)
    }

    @Test func serverReportsKindOfCurrentURI() throws {
        let server = PlexServer(
            name: "Test",
            uri: try #require(remote.uri),
            machineIdentifier: "abc",
            accessToken: "secret",
            owned: true,
            connections: [local, remote, relay]
        )

        #expect(server.connectionKind == .remote)
        #expect(server.with(uri: try #require(local.uri)).connectionKind == .local)
    }

    @Test func identityResponseCarriesMachineIdentifier() throws {
        let json = #"{"MediaContainer":{"size":0,"claimed":true,"machineIdentifier":"abc123","version":"1.40.2"}}"#
        let response = try JSONDecoder().decode(PlexResponse.self, from: Data(json.utf8))

        #expect(response.mediaContainer.machineIdentifier == "abc123")
    }
}
