import SwiftUI

/// A 2:3 poster that navigates to the item's detail page.
struct PosterCard: View {
    let item: PlexMetadata
    var width: CGFloat = 250
    var onFocus: (() -> Void)?

    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkImage(path: item.posterPath, width: Int(width * 2), height: Int(width * 3))
                    .frame(width: width, height: width * 1.5)
                    .overlay(alignment: .bottom) {
                        if let progress = item.progress {
                            ProgressView(value: progress)
                                .padding(12)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .focusBorder(.rect(cornerRadius: 12))
                    .onFocusGained(onFocus)
                    .overlay(alignment: .topTrailing) {
                        if item.isWatched {
                            WatchedBadge()
                        }
                    }

                Text(item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)

                // Always present so every poster in a row is the same height.
                Text(subtitle ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.focusBorder)
    }

    private var subtitle: String? {
        switch item.kind {
        case .episode: item.episodeLabel
        case .season: item.parentTitle
        default: item.year.map(String.init)
        }
    }
}

#Preview {
    NavigationStack {
        PosterCard(item: .previewMovie)
    }
}
