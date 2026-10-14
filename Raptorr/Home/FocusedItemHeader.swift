import SwiftUI

/// Logo, basic metadata and description of the focused card, above the Home rows.
struct FocusedItemHeader: View {
    let item: PlexMetadata
    let logoPath: String?
    var isLoadingLogo = false
    /// Continue Watching cards use the `continueWatchingLine` order (S#E#, year, rating, runtime).
    var isContinueWatching = false

    var body: some View {
        // Every slot has a fixed size (the logo box, one line each for the episode title and
        // metadata, three lines of description), so moving between items never shifts anything.
        VStack(alignment: .leading, spacing: HeaderLayout.spacing) {
            TitleLogo(
                title: item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title,
                logoPath: logoPath,
                maxWidth: HeaderLayout.logoWidth,
                maxHeight: HeaderLayout.logoHeight,
                isLoading: isLoadingLogo
            )

            // Always present, so the logo never moves when focus goes between a movie and an
            // episode; a moving logo slid across the rows instead of crossfading.
            episodeTitle(item.kind == .episode ? item.title : " ")

            // The placeholder keeps the line's height when an item has no metadata.
            Text(" ")
                .hidden()
                .overlay(alignment: .leading) {
                    MetadataLine(leading: leadingMetadata, rating: item.contentRating, trailing: item.durationText.map { [$0] } ?? [])
                        .fixedSize()
                }
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(item.summary ?? "")
                .lineLimit(HeaderLayout.summaryLines, reservesSpace: true)
                .frame(width: HeaderLayout.summaryWidth, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func episodeTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .lineLimit(1)
    }

    /// What comes before the rating: S#E# and the year on Continue Watching (matching
    /// `continueWatchingLine`), otherwise the "S2 · E5" label of `infoLine`.
    private var leadingMetadata: [String] {
        if isContinueWatching {
            [item.shortEpisodeLabel, item.year.map(String.init)].compactMap { $0 }
        } else {
            [item.episodeLabel].compactMap { $0 }
        }
    }
}

#Preview {
    FocusedItemHeader(item: .previewMovie, logoPath: nil)
}
