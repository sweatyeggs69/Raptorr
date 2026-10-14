import SwiftUI

/// Every movie or show in one library, as a poster grid.
struct LibraryView: View {
    let section: LibrarySection

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @State private var viewModel = LibraryViewModel()
    @State private var path = NavigationPath()
    @FocusState private var focusedID: String?
    @Environment(TabRouter.self) private var router

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 48, alignment: .top)]

    var body: some View {
        NavigationStack(path: $path) {
            content
                // Back at the top level goes to Home rather than closing the app.
                .onExitCommand { router.selection = .home }
                .metadataDestinations()
        }
        // Reloads when the connection moves between local, remote and relay.
        .task(id: server.uri) {
            await viewModel.load(section: section, server: server, client: client)
        }
        .task(id: server.uri) {
            await viewModel.loadLetters(section: section, server: server, client: client)
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
                    Task { await viewModel.load(section: section, server: server, client: client) }
                }
            }
        } else if viewModel.items.isEmpty {
            ContentUnavailableView("Nothing Here Yet", systemImage: section.type.systemImage)
        } else {
            ScrollViewReader { proxy in
                HStack(spacing: 40) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 60) {
                            ForEach(viewModel.items) { item in
                                PosterCard(item: item, focus: $focusedID)
                                    .id(item.id)
                                    .task {
                                        await viewModel.itemAppeared(item, section: section, server: server, client: client)
                                    }
                            }
                        }
                        .padding(.vertical, 40)
                    }
                    .scrollClipDisabled()

                    if viewModel.letters.count > 1 {
                        LetterJumpBar(letters: viewModel.letters) { letter in
                            Task { await jump(to: letter, proxy: proxy) }
                        }
                    }
                }
            }
        }
    }

    /// Scrolls to the letter's first title and moves focus onto it.
    private func jump(to letter: LetterJump, proxy: ScrollViewProxy) async {
        guard let id = await viewModel.jump(to: letter, section: section, server: server, client: client) else { return }
        proxy.scrollTo(id, anchor: .top)
        // The lazy grid builds the card after the scroll; focus it once it exists.
        try? await Task.sleep(for: .milliseconds(100))
        focusedID = id
    }
}

#Preview {
    LibraryView(section: LibrarySection(key: "1", type: .movie, title: "Movies"))
        .environment(TabRouter())
}
