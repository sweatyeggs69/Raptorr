import Testing
@testable import Raptorr

struct PlexMetadataTests {
    @Test func episodeLabelAndPosterFallback() {
        let episode = PlexMetadata(
            ratingKey: "1",
            type: "episode",
            title: "Pilot",
            index: 3,
            parentIndex: 2,
            thumb: "/episode-thumb",
            grandparentThumb: "/show-poster"
        )

        #expect(episode.episodeLabel == "S2 · E3")
        #expect(episode.shortEpisodeLabel == "S2E3")
        #expect(episode.infoLine == "S2 · E3")
        #expect(episode.detailsLine.isEmpty)
        #expect(episode.posterPath == "/show-poster")
    }

    @Test func showIsWatchedOnlyWhenEveryEpisodeIs() {
        let partial = PlexMetadata(ratingKey: "1", type: "show", title: "Show", leafCount: 10, viewedLeafCount: 9)
        let complete = PlexMetadata(ratingKey: "2", type: "show", title: "Show", leafCount: 10, viewedLeafCount: 10)

        #expect(!partial.isWatched)
        #expect(complete.isWatched)
    }

    @Test func movieInProgressIsNotWatched() {
        let movie = PlexMetadata(ratingKey: "1", type: "movie", title: "Movie", duration: 1000, viewOffset: 500, viewCount: 1)

        #expect(!movie.isWatched)
        #expect(movie.progress == 0.5)
    }

    @Test(arguments: [(5_400_000, "1h 30m"), (2_700_000, "45m")])
    func durationText(duration: Int, expected: String) {
        let movie = PlexMetadata(ratingKey: "1", type: "movie", title: "Movie", duration: duration)

        #expect(movie.durationText == expected)
    }
}
