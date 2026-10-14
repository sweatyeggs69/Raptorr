import Foundation

extension PlexMetadata {
    static let previewMovie = PlexMetadata(
        ratingKey: "1",
        key: "/library/metadata/1",
        type: "movie",
        title: "Big Buck Bunny",
        summary: "A giant rabbit takes revenge on three bullying rodents.",
        year: 2008,
        duration: 596_000,
        viewOffset: 120_000,
        contentRating: "G",
        audienceRating: 8.1
    )

    static let previewShow = PlexMetadata(
        ratingKey: "2",
        key: "/library/metadata/2/children",
        type: "show",
        title: "Example Show",
        summary: "A show used in previews.",
        year: 2024,
        leafCount: 10,
        viewedLeafCount: 3
    )

    static let previewEpisode = PlexMetadata(
        ratingKey: "3",
        key: "/library/metadata/3",
        type: "episode",
        title: "Pilot",
        summary: "The first episode.",
        index: 1,
        parentIndex: 1,
        duration: 1_800_000,
        grandparentTitle: "Example Show"
    )
}
