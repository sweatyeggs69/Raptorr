import SwiftUI

/// An item's metadata line in the Home order: S#E#, year, rating badge, runtime. Home's
/// library rows leave out the year and use the spaced "S2 · E5" label; Continue Watching and
/// detail pages use the full line.
struct ItemMetadataLine: View {
    let item: PlexMetadata
    var includesYear = true

    var body: some View {
        MetadataLine(leading: leading, rating: item.contentRating, trailing: item.durationText.map { [$0] } ?? [])
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private var leading: [String] {
        if includesYear {
            [item.shortEpisodeLabel, item.year.map(String.init)].compactMap { $0 }
        } else {
            [item.episodeLabel].compactMap { $0 }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ItemMetadataLine(item: .previewEpisode)
        ItemMetadataLine(item: .previewMovie)
        ItemMetadataLine(item: .previewMovie, includesYear: false)
    }
}
