import SwiftUI

/// Detail page for something playable: a movie or an episode.
struct ItemDetailView: View {
    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel: ItemDetailViewModel

    init(item: PlexMetadata) {
        _viewModel = State(initialValue: ItemDetailViewModel(item: item))
    }

    var body: some View {
        let item = viewModel.item

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    if item.kind == .episode {
                        TitleLogo(
                            title: item.grandparentTitle ?? "",
                            logoPath: viewModel.showLogoPath,
                            maxHeight: 160,
                            font: .title2.bold()
                        )
                        Text(item.title)
                            .font(.title.bold())
                    } else {
                        TitleLogo(title: item.title, logoPath: item.logoPath)
                    }
                }

                HStack(spacing: 24) {
                    if let resumeText = viewModel.resumeText {
                        Button(resumeText, systemImage: "play.fill") {
                            playback.play(item, resume: true)
                        }
                        Button {
                            playback.play(item, resume: false)
                        } label: {
                            Label("Play from Beginning", systemImage: "arrow.counterclockwise")
                                .labelStyle(.iconOnly)
                        }
                    } else {
                        Button("Play", systemImage: "play.fill") {
                            playback.play(item, resume: false)
                        }
                    }

                    Button {
                        Task { await viewModel.toggleWatched(server: server, client: client) }
                    } label: {
                        // Filled check when watched; the symbol transforms when it changes.
                        Label(
                            item.isWatched ? "Mark Unwatched" : "Mark Watched",
                            systemImage: item.isWatched ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                        .labelStyle(.iconOnly)
                        .contentTransition(.symbolEffect(.replace))
                    }

                    if let duration = item.durationText {
                        Text(duration)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .fullWidthFocusSection()

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.body)
                        .frame(maxWidth: 1200, alignment: .leading)
                }

                if let credits = viewModel.creditsLine {
                    Text(credits)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

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
            BackdropView(path: item.backdropPath)
        }
        .task {
            await viewModel.load(server: server, client: client)
        }
        // Coming back from the player: pick up the new resume point and watched state.
        .onChange(of: playback.request == nil) { _, closed in
            guard closed else { return }
            Task { await viewModel.refreshAfterPlayback(server: server, client: client) }
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: .previewMovie)
    }
    .environment(PlaybackCoordinator())
}
