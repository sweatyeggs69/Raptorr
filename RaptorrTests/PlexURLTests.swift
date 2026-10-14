import Foundation
import Testing
@testable import Raptorr

struct PlexURLTests {
    private let server = PlexServer(
        name: "Test",
        uri: "https://1-2-3-4.abc.plex.direct:32400",
        machineIdentifier: "abc",
        accessToken: "secret",
        owned: true,
        connections: []
    )

    @Test func partURLKeepsDocumentedPathAndAddsToken() throws {
        let url = try #require(PlexAPIClient().partURL(server: server, partKey: "/library/parts/9/1700000000/file.mkv"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/library/parts/9/1700000000/file.mkv")
        #expect(components.queryItems?.first { $0.name == "X-Plex-Token" }?.value == "secret")
    }

    @Test func artworkURLUsesPhotoTranscoder() throws {
        let url = try #require(PlexAPIClient().artworkURL(server: server, path: "/library/metadata/1/thumb/1", width: 300, height: 450))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/photo/:/transcode")
        #expect(components.queryItems?.first { $0.name == "url" }?.value == "/library/metadata/1/thumb/1")
    }

    @Test func artworkURLIsNilWithoutPath() {
        #expect(PlexAPIClient().artworkURL(server: server, path: nil, width: 300, height: 450) == nil)
    }

    @Test func signInLinkUsesShortPinLinkPage() {
        #expect(SignInViewModel.linkURL(for: "ABCD")?.absoluteString == "https://plex.tv/link/?pin=ABCD")
    }

    @Test func playerTimeFormatting() {
        #expect(PlayerOverlay.format(ms: 65_000) == "1:05")
        #expect(PlayerOverlay.format(ms: 3_725_000) == "1:02:05")
    }
}
