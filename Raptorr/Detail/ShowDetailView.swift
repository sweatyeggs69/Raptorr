import SwiftUI

/// A TV show with its seasons and episodes. Also opened for a season, preselecting it.
struct ShowDetailView: View {
    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel: ShowDetailViewModel
    @FocusState private var isPlayFocused: Bool
    /// Play appears once the episodes load; it takes focus the first time it does.
    @State private var didFocusPlay = false

    init(item: PlexMetadata) {
        _viewModel = State(initialValue: ShowDetailViewModel(item: item))
    }

    var body: some View {
        let show = viewModel.displayItem

        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                TitleLogo(title: show.title, logoPath: show.logoPath)

                if let next = viewModel.nextEpisode {
                    Button {
                        playback.play(next)
                    } label: {
                        Label(playLabel(for: next), systemImage: "play.fill")
                    }
                    .focused($isPlayFocused)
                    .fullWidthFocusSection()
                }

                if let summary = show.summary, !summary.isEmpty {
                    Text(summary)
                        .frame(maxWidth: 1200, alignment: .leading)
                        .lineLimit(4)
                }

                if let details = viewModel.detailsLine {
                    Text(details)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if viewModel.seasons.count > 1 {
                    seasonPicker
                        .fullWidthFocusSection()
                }

                episodeList

                if !viewModel.cast.isEmpty {
                    CastShelf(cast: viewModel.cast)
                }

                if !viewModel.related.isEmpty {
                    MediaShelf(title: "Related", items: viewModel.related)
                }
            }
            .padding(80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            BackdropView(path: show.backdropPath)
        }
        .defaultFocus($isPlayFocused, true)
        .onChange(of: viewModel.nextEpisode != nil, initial: true) { _, hasPlay in
            guard hasPlay, !didFocusPlay else { return }
            didFocusPlay = true
            isPlayFocused = true
        }
        .task {
            await viewModel.load(server: server, client: client)
        }
        // Coming back from the player: refresh progress and Up Next. The player's final
        // timeline report is still in flight then, so wait briefly first.
        .onChange(of: playback.request == nil) { _, closed in
            guard closed else { return }
            Task {
                try? await Task.sleep(for: .seconds(1))
                await viewModel.load(server: server, client: client)
            }
        }
    }

    /// Seasons as a segmented control, like the Apple TV app; moving focus across it switches
    /// season. Long-running shows get a menu instead so the row stays readable.
    @ViewBuilder
    private var seasonPicker: some View {
        let selection = Binding<String?>(
            get: { viewModel.selectedSeason?.ratingKey },
            set: { key in
                guard let season = viewModel.seasons.first(where: { $0.ratingKey == key }) else { return }
                viewModel.select(season: season, server: server, client: client)
            }
        )
        if viewModel.seasons.count <= 8 {
            Picker("Season", selection: selection) {
                ForEach(viewModel.seasons) { season in
                    Text(season.title).tag(Optional(season.ratingKey))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 1400, alignment: .leading)
        } else {
            Picker("Season", selection: selection) {
                ForEach(viewModel.seasons) { season in
                    Text(season.title).tag(Optional(season.ratingKey))
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var episodeList: some View {
        if viewModel.isLoadingEpisodes && viewModel.episodes.isEmpty {
            ProgressView()
        } else if viewModel.episodes.isEmpty, let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(alignment: .leading, spacing: 40) {
                ForEach(viewModel.episodes) { episode in
                    EpisodeRow(episode: episode) {
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
