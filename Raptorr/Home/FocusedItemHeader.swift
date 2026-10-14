import SwiftUI

/// Logo, basic metadata and description of the focused card, above the Home rows.
struct FocusedItemHeader: View {
    let item: PlexMetadata
    let logoPath: String?
    var isLoadingLogo = false
    /// Continue Watching cards use `continueWatchingLine` (S#E#, year, rating, runtime).
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

            Text(item.kind == .episode ? item.title : " ")
                .font(.title3.bold())
                .lineLimit(1)

            Text(metadataLine.isEmpty ? " " : metadataLine)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.summary ?? "")
                .lineLimit(HeaderLayout.summaryLines, reservesSpace: true)
                .frame(width: HeaderLayout.summaryWidth, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataLine: String {
        isContinueWatching ? item.continueWatchingLine : item.infoLine
    }
}

#Preview {
    FocusedItemHeader(item: .previewMovie, logoPath: nil)
}
