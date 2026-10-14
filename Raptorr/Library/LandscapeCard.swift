import SwiftUI

/// A 16:9 card that navigates to the item's detail page, for Continue Watching.
struct LandscapeCard: View {
    let item: PlexMetadata
    var width: CGFloat = 480
    var onFocus: (() -> Void)?

    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkImage(
                    path: item.landscapeImagePath,
                    width: Int(width * 2),
                    height: Int(width * 9 / 8),
                    placeholderSymbol: item.kind == .episode ? "tv" : "film"
                )
                .frame(width: width, height: width * 9 / 16)
                .overlay(alignment: .bottom) {
                    if let progress = item.progress {
                        ProgressView(value: progress)
                            .padding(16)
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .onFocusGained(onFocus)

                Text(item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title)
                    .font(.caption)
                    .lineLimit(1)

                // Always present (the year for movies) so every card in the row is the same height.
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.borderless)
    }

    private var subtitle: String {
        if let label = item.episodeLabel { return "\(label) · \(item.title)" }
        return item.year.map(String.init) ?? " "
    }
}

#Preview {
    NavigationStack {
        LandscapeCard(item: .previewEpisode)
    }
}
