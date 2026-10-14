import SwiftUI

/// A 2:3 poster that navigates to the item's detail page.
struct PosterCard: View {
    let item: PlexMetadata
    var width: CGFloat = 250

    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkImage(path: item.posterPath, width: Int(width * 2), height: Int(width * 3))
                    .frame(width: width, height: width * 1.5)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        if item.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .tint)
                                .font(.title3)
                                .padding(8)
                        }
                    }

                if let progress = item.progress {
                    ProgressView(value: progress)
                        .frame(width: width)
                }

                Text(item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: width, alignment: .leading)
                }
            }
        }
        .buttonStyle(.borderless)
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
