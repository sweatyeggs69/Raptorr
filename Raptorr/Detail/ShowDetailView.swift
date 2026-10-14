import SwiftUI

/// A TV show with its seasons and episodes. Also opened for a season, preselecting it.
struct ShowDetailView: View {
    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel: ShowDetailViewModel

    init(item: PlexMetadata) {
        _viewModel = State(initialValue: ShowDetailViewModel(item: item))
    }

    var body: some View {
        let show = viewModel.displayItem

        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                VStack(alignment: .leading, spacing: 12) {
                    TitleLogo(title: show.title, logoPath: show.logoPath)
                    Text(viewModel.metadataLine)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if let next = viewModel.nextEpisode {
                    Button {
                        playback.play(next)
                    } label: {
                        Label(playLabel(for: next), systemImage: "play.fill")
                    }
                }

                if let summary = show.summary, !summary.isEmpty {
                    Text(summary)
                        .frame(maxWidth: 1200, alignment: .leading)
                        .lineLimit(4)
                }

                if viewModel.seasons.count > 1 {
                    seasonPicker
                }

                episodeShelf
            }
            .padding(80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            BackdropView(path: show.backdropPath)
        }
        .task {
            await viewModel.load(server: server, client: client)
        }
    }

    private var seasonPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 24) {
                ForEach(viewModel.seasons) { season in
                    let isSelected = season.ratingKey == viewModel.selectedSeason?.ratingKey
                    Button {
                        Task { await viewModel.select(season: season, server: server, client: client) }
                    } label: {
                        Label(season.title, systemImage: "checkmark")
                            .labelStyle(SeasonLabelStyle(isSelected: isSelected))
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var episodeShelf: some View {
        if viewModel.isLoadingEpisodes && viewModel.episodes.isEmpty {
            ProgressView()
        } else if viewModel.episodes.isEmpty, let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(viewModel.episodes) { episode in
                        EpisodeCard(episode: episode) {
                            playback.play(episode)
                        }
                        .contextMenu {
                            Button(
                                episode.isWatched ? "Mark Unwatched" : "Mark Watched",
                                systemImage: episode.isWatched ? "circle" : "checkmark.circle"
                            ) {
                                Task { await viewModel.toggleWatched(episode, server: server, client: client) }
                            }
                            Button("Play from Beginning", systemImage: "arrow.counterclockwise") {
                                playback.play(episode, resume: false)
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func playLabel(for episode: PlexMetadata) -> String {
        let prefix = episode.progress != nil ? "Resume" : "Play"
        if let label = episode.episodeLabel {
            return "\(prefix) \(label)"
        }
        return prefix
    }
}

#Preview {
    NavigationStack {
        ShowDetailView(item: .previewShow)
    }
    .environment(PlaybackCoordinator())
}
