import SwiftUI

/// Every movie or show in one library, as a poster grid.
struct LibraryView: View {
    let section: LibrarySection

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @State private var viewModel = LibraryViewModel()
    @State private var path = NavigationPath()

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 48, alignment: .top)]

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(section.title)
                .metadataDestinations()
        }
        .task(id: section.key) {
            await viewModel.reload(section: section, server: server, client: client)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.items.isEmpty, viewModel.isLoading {
            ProgressView()
        } else if viewModel.items.isEmpty, let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load \(section.title)", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.reload(section: section, server: server, client: client) }
                }
            }
        } else if viewModel.items.isEmpty {
            ContentUnavailableView("Nothing Here Yet", systemImage: section.type.systemImage)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 60) {
                    ForEach(viewModel.items) { item in
                        PosterCard(item: item)
                            .task {
                                await viewModel.itemAppeared(item, section: section, server: server, client: client)
                            }
                    }
                }
                .padding(.vertical, 40)
            }
            .scrollClipDisabled()
        }
    }
}

#Preview {
    LibraryView(section: LibrarySection(key: "1", type: .movie, title: "Movies"))
}
