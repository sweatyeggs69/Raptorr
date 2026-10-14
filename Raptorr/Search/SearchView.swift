import SwiftUI

struct SearchView: View {
    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @State private var viewModel = SearchViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack(path: $path) {
            content
                .metadataDestinations()
        }
        .searchable(text: $viewModel.query, prompt: "Movies and Shows")
        .task(id: viewModel.query) {
            await viewModel.search(server: server, client: client)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.results.isEmpty {
            if viewModel.isSearching {
                ProgressView()
            } else if viewModel.query.isEmpty {
                ContentUnavailableView("Search Your Libraries", systemImage: "magnifyingglass")
            } else {
                ContentUnavailableView.search(text: viewModel.query)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 60) {
                    ForEach(viewModel.results) { hub in
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
    SearchView()
}
