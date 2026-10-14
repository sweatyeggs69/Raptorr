import SwiftUI

/// One episode in the show page's list: 16:9 still on the left, number, name and description
/// on the right. Selecting it starts playback.
struct EpisodeRow: View {
    let episode: PlexMetadata
    let action: () -> Void

    private let imageWidth: CGFloat = 400
    /// The still's requested pixel size (2x the 16:9 frame), shared with the show page's
    /// prefetch so both ask for the same image.
    static let stillPixelWidth = 800
    static let stillPixelHeight = 450

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 40) {
                ArtworkImage(
                    path: episode.thumb,
                    width: Self.stillPixelWidth,
                    height: Self.stillPixelHeight,
                    placeholderSymbol: "tv"
                )
                .frame(width: imageWidth, height: imageWidth * 9 / 16)
                .overlay(alignment: .bottom) {
                    if let progress = episode.progress {
                        ProgressView(value: progress)
                            .padding(16)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if episode.isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .tint)
                            .font(.title3)
                            .padding(12)
                    }
                }
                .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(episodeNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let summary = episode.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if let duration = episode.durationText {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.borderless)
    }

    private var episodeNumber: String {
        guard let index = episode.index else { return "Episode" }
        return "Episode \(index)"
    }
}

#Preview {
    EpisodeRow(episode: .previewEpisode) {}
        .padding(80)
}
