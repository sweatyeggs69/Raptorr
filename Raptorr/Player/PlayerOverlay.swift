import SwiftUI

/// Title, play state and progress shown over the video.
struct PlayerOverlay: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        if let show = viewModel.item.grandparentTitle {
                            Text(show)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        Text(title)
                            .font(.title2.bold())
                    }
                }

                ProgressView(value: viewModel.progress)

                HStack {
                    Text(Self.format(ms: viewModel.currentTimeMs))
                    Spacer()
                    Text("-" + Self.format(ms: max(viewModel.durationMs - viewModel.currentTimeMs, 0)))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                Text("Swipe down for audio and subtitles")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(40)
            .glassEffect(in: .rect(cornerRadius: 32))
            .padding(60)
        }
    }

    private var title: String {
        if let label = viewModel.item.episodeLabel {
            return "\(label)  \(viewModel.item.title)"
        }
        return viewModel.item.title
    }

    static func format(ms: Int) -> String {
        let totalSeconds = max(ms, 0) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayerOverlay(
        viewModel: PlayerViewModel(
            request: PlaybackRequest(item: .previewEpisode, startOffsetMs: nil),
            server: .preview,
            client: PlexAPIClient()
        )
    )
}
