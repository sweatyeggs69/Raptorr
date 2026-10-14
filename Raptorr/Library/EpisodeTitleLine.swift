import SwiftUI

/// An episode's name with its S#E# in front in the secondary color, e.g. "S2E3  Pilot".
/// Used on Home, episode pages and in the player.
struct EpisodeTitleLine: View {
    let episode: PlexMetadata

    var body: some View {
        HStack(spacing: 10) {
            if let label = episode.shortEpisodeLabel {
                Text(label)
                    .foregroundStyle(.secondary)
            }
            Text(episode.title)
        }
        .lineLimit(1)
    }
}

#Preview {
    EpisodeTitleLine(episode: .previewEpisode)
        .font(.title3.bold())
}
