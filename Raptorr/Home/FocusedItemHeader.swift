import SwiftUI

/// Logo, basic metadata and description of the focused card, above the Home rows.
struct FocusedItemHeader: View {
    let item: PlexMetadata
    let logoPath: String?
    var isLoadingLogo = false
    /// Continue Watching cards drop the metadata line and show S#E# after the episode title.
    var isContinueWatching = false

    var body: some View {
        // Every slot has a fixed size (the logo box, one line each for the episode title and
        // metadata, three lines of description), so moving between items never shifts anything.
        // Continue Watching leaves out the metadata line; the header is bottom aligned, so only
        // the logo moves, and only when switching to or from that row.
        VStack(alignment: .leading, spacing: 16) {
            TitleLogo(
                title: item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title,
                logoPath: logoPath,
                maxWidth: 640,
                maxHeight: 180,
                isLoading: isLoadingLogo
            )

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(item.kind == .episode ? item.title : " ")
                    .font(.title3.bold())
                    .lineLimit(1)
                if isContinueWatching, let label = item.shortEpisodeLabel {
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            if !isContinueWatching {
                Text(item.infoLine.isEmpty ? " " : item.infoLine)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(item.summary ?? "")
                .lineLimit(3, reservesSpace: true)
                .frame(width: 1000, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    FocusedItemHeader(item: .previewMovie, logoPath: nil)
}
