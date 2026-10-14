import SwiftUI

/// Shown over the video: a small title in the top left, and the timeline alone at the bottom.
struct PlayerOverlay: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading) {
            titleBar
            Spacer()
            timeline
        }
        .padding(60)
        .background {
            // Keeps the title readable over bright video.
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }

    /// Small logo, with the S#E# and episode title in small text below it for episodes.
    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            TitleLogo(
                title: viewModel.item.kind == .episode ? (viewModel.item.grandparentTitle ?? "") : viewModel.item.title,
                logoPath: viewModel.logoPath,
                maxWidth: 240,
                maxHeight: 60,
                font: .headline,
                hugsContent: true
            )

            if viewModel.item.kind == .episode {
                EpisodeTitleLine(episode: viewModel.item)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeline: some View {
        // Elapsed time on the left of the bar, time remaining on the right.
        HStack(spacing: 24) {
            Text(Self.format(ms: viewModel.currentTimeMs))
                .foregroundStyle(.secondary)

            ProgressView(value: viewModel.progress)

            Text("-" + Self.format(ms: max(viewModel.durationMs - viewModel.currentTimeMs, 0)))
                .foregroundStyle(.secondary)
        }
        .font(.caption.monospacedDigit())
        .padding(32)
        .glassEffect(in: .rect(cornerRadius: 32))
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
