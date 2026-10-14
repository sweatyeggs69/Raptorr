import SwiftUI

/// An item's metadata line in the Home order: year, rating badge, runtime. Home's library
/// rows leave out the year. An episode's S#E# sits on its title line (`EpisodeTitleLine`).
struct ItemMetadataLine: View {
    let item: PlexMetadata
    var includesYear = true

    var body: some View {
        MetadataLine(leading: leading, rating: item.contentRating, trailing: item.durationText.map { [$0] } ?? [])
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private var leading: [String] {
        includesYear ? [item.year.map(String.init)].compactMap { $0 } : []
    }
}

#Preview {
    VStack(alignment: .leading) {
        ItemMetadataLine(item: .previewEpisode)
        ItemMetadataLine(item: .previewMovie)
        ItemMetadataLine(item: .previewMovie, includesYear: false)
    }
}
