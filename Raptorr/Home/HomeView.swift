import SwiftUI

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
        if viewModel.shelves.isEmpty, viewModel.isLoading {
            ProgressView()
        } else if viewModel.shelves.isEmpty, let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Home", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.load(sections: sections, server: server, client: client) }
                }
            }
        } else if viewModel.shelves.isEmpty {
            ContentUnavailableView(
                "Nothing to Show Yet",
                systemImage: "play.tv",
                description: Text("Movies and shows you add to Plex will appear here.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 60) {
                    ForEach(viewModel.shelves) { hub in
                        MediaShelf(title: hub.title ?? "", items: hub.items)
                    }
                }
                .padding(.vertical, 40)
            }
            .scrollClipDisabled()
        }
    }
}

#Preview {
    HomeView(sections: [])
}
