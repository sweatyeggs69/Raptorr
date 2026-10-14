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
                    if item.kind == .episode, let show = item.grandparentTitle {
                        Text(show)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.title)
                        .font(.largeTitle.bold())
                    Text(viewModel.metadataLine)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    if let resumeText = viewModel.resumeText {
                        Button(resumeText, systemImage: "play.fill") {
                            playback.play(item, resume: true)
                        }
                        Button("Play from Beginning", systemImage: "arrow.counterclockwise") {
                            playback.play(item, resume: false)
                        }
                    } else {
                        Button("Play", systemImage: "play.fill") {
                            playback.play(item, resume: false)
                        }
                    }

                    Button {
                        Task { await viewModel.toggleWatched(server: server, client: client) }
                    } label: {
                        Label(
                            item.isWatched ? "Mark Unwatched" : "Mark Watched",
                            systemImage: item.isWatched ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                }

                if let tagline = item.tagline {
                    Text(tagline)
                        .font(.title3.italic())
                }

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
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: .previewMovie)
    }
    .environment(PlaybackCoordinator())
}
