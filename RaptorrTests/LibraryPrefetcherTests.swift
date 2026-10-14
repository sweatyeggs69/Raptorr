import Testing
@testable import Raptorr

struct LibraryPrefetcherTests {
    @Test func unchangedTitleIsCurrent() {
        let cached = PlexMetadata(ratingKey: "1", title: "Alien", updatedAt: 100)
        let fresh = PlexMetadata(ratingKey: "1", title: "Alien", updatedAt: 100)
        #expect(LibraryPrefetcher.isCurrent(cached, comparedWith: fresh))
    }

    @Test func updatedTitleIsStale() {
        let cached = PlexMetadata(ratingKey: "1", title: "Alien", updatedAt: 100)
        let fresh = PlexMetadata(ratingKey: "1", title: "Alien", updatedAt: 200)
        #expect(!LibraryPrefetcher.isCurrent(cached, comparedWith: fresh))
    }

    @Test func showWithNewEpisodesIsStale() {
        let cached = PlexMetadata(ratingKey: "2", type: "show", title: "Severance", leafCount: 9, updatedAt: 100)
        let fresh = PlexMetadata(ratingKey: "2", type: "show", title: "Severance", leafCount: 10, updatedAt: 100)
        #expect(!LibraryPrefetcher.isCurrent(cached, comparedWith: fresh))
    }

    @Test func missingDatesCountAsStale() {
        let cached = PlexMetadata(ratingKey: "1", title: "Alien")
        let fresh = PlexMetadata(ratingKey: "1", title: "Alien", updatedAt: 100)
        #expect(!LibraryPrefetcher.isCurrent(cached, comparedWith: fresh))
    }
}
