import SwiftUI

/// Logo, basic metadata and description of the focused card, above the Home rows.
struct FocusedItemHeader: View {
    let item: PlexMetadata
    let logoPath: String?
    /// Continue Watching cards use the `continueWatchingLine` order (S#E#, year, rating, runtime).
    var isContinueWatching = false

    var body: some View {
        // Fixed slots: the logo box, the episode title line (episodes only), one metadata line
        // and three lines of description.
        VStack(alignment: .leading, spacing: HeaderLayout.spacing) {
            TitleLogo(
                title: item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title,
                logoPath: logoPath,
                maxWidth: HeaderLayout.logoWidth,
                maxHeight: HeaderLayout.logoHeight
            )
            .padding(.bottom, HeaderLayout.logoBottomPadding)

            // Movies have no episode title, so the line is left out. The whole header
            // crossfades between items, so the logo moving with it doesn't show.
            if item.kind == .episode {
                EpisodeTitleLine(episode: item)
                    .font(.title3.bold())
            }

            // The placeholder keeps the line's height when an item has no metadata.
            Text(" ")
                .hidden()
                .overlay(alignment: .leading) {
                    ItemMetadataLine(item: item, includesYear: isContinueWatching)
                        .fixedSize()
                }
                .font(.headline)

            Text(item.summary ?? "")
                .lineLimit(HeaderLayout.summaryLines, reservesSpace: true)
                .frame(width: HeaderLayout.summaryWidth, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

#Preview {
    FocusedItemHeader(item: .previewMovie, logoPath: nil)
}
