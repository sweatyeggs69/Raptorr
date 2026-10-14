import Foundation
import Testing
@testable import Raptorr

struct TopShelfTests {
    @Test func linkRoundTrips() throws {
        let link = TopShelfLink(action: .play, machineIdentifier: "abc123", ratingKey: "42")
        let url = try #require(link.url)

        #expect(url.absoluteString == "raptorr://play?server=abc123&item=42")
        #expect(TopShelfLink(url: url) == link)
    }

    @Test func linkRejectsOtherURLs() throws {
        #expect(TopShelfLink(url: try #require(URL(string: "https://play?server=a&item=1"))) == nil)
        #expect(TopShelfLink(url: try #require(URL(string: "raptorr://rewind?server=a&item=1"))) == nil)
        #expect(TopShelfLink(url: try #require(URL(string: "raptorr://show?server=a"))) == nil)
    }

    @Test func episodeTitleNamesShowAndEpisode() {
        let episode = PlexMetadata(ratingKey: "1", type: "episode", title: "Pilot", index: 3, parentIndex: 2, grandparentTitle: "Severance")
        let movie = PlexMetadata(ratingKey: "2", type: "movie", title: "Heat")

        #expect(TopShelfPublisher.title(for: episode) == "Severance · S2E3")
        #expect(TopShelfPublisher.title(for: movie) == "Heat")
    }

    @Test func snapshotRoundTrips() throws {
        let item = TopShelfItem(
            identifier: "42",
            title: "Heat",
            imageFileName: "42-abc.jpg",
            progress: 0.5,
            displayURL: try #require(URL(string: "raptorr://show?server=a&item=42")),
            playURL: try #require(URL(string: "raptorr://play?server=a&item=42"))
        )
        let snapshot = TopShelfSnapshot(items: [item])
        let decoded = try JSONDecoder().decode(TopShelfSnapshot.self, from: JSONEncoder().encode(snapshot))

        #expect(decoded == snapshot)
    }
}
