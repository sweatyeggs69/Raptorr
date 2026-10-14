import SwiftUI

/// Apple TV style Home: the focused card's backdrop, logo, metadata and description on top,
/// Continue Watching as 16:9 cards, then each library's rows.
struct HomeView: View {
    let sections: [LibrarySection]

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @State private var viewModel = HomeViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            content
                .metadataDestinations()
        }
        .task(id: sections) {
            await viewModel.load(sections: sections, server: server, client: client)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isEmpty, viewModel.isLoading {
            ProgressView()
        } else if viewModel.isEmpty, let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Home", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.load(sections: sections, server: server, client: client) }
                }
            }
        } else if viewModel.isEmpty {
            ContentUnavailableView(
                "Nothing to Show Yet",
                systemImage: "play.tv",
                description: Text("Movies and shows you add to Plex will appear here.")
            )
        } else {
            VStack(alignment: .leading, spacing: 40) {
                if let item = viewModel.focusedItem {
                    FocusedItemHeader(item: item, logoPath: viewModel.focusedLogoPath)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 60) {
                        if !viewModel.continueWatching.isEmpty {
                            MediaShelf(
                                title: "Continue Watching",
                                items: viewModel.continueWatching,
                                style: .landscape,
                                onFocus: focus
                            )
                        }
                        ForEach(viewModel.shelves) { hub in
                            MediaShelf(title: hub.title ?? "", items: hub.items, onFocus: focus)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .scrollClipDisabled()
            }
            .background {
                BackdropView(path: viewModel.focusedItem?.backdropPath)
                    .animation(.easeInOut, value: viewModel.focusedItem?.ratingKey)
            }
        }
    }

    private func focus(_ item: PlexMetadata) {
        viewModel.focus(item, server: server, client: client)
    }
}

#Preview {
    HomeView(sections: [])
}
