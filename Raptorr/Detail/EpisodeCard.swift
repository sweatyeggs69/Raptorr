import SwiftUI

/// A 16:9 episode thumbnail that starts playback when selected.
struct EpisodeCard: View {
    let episode: PlexMetadata
    let action: () -> Void

    private let width: CGFloat = 400

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkImage(path: episode.thumb, width: Int(width * 2), height: Int(width * 9 / 8), placeholderSymbol: "tv")
                    .frame(width: width, height: width * 9 / 16)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        if episode.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .tint)
                                .font(.title3)
                                .padding(8)
                        }
                    }

                if let progress = episode.progress {
                    ProgressView(value: progress)
                        .frame(width: width)
                }

                Text(title)
                    .font(.caption)
                    .lineLimit(1)

                if let duration = episode.durationText {
                    Text(duration)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.borderless)
    }

    private var title: String {
        if let index = episode.index {
            return "\(index). \(episode.title)"
        }
        return episode.title
    }
}

#Preview {
    EpisodeCard(episode: .previewEpisode) {}
}
