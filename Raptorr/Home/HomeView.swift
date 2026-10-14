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
        // Reloads when the libraries change or the connection moves (local, remote, relay).
        .task(id: server.uri + "|" + sections.map(\.key).joined(separator: ",")) {
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
            // The active row stays locked to the bottom of the screen and the header sits
            // directly above it, so a missing logo or a short description never moves the row.
            VStack(alignment: .leading, spacing: 40) {
                if let item = viewModel.focusedItem {
                    FocusedItemHeader(
                        item: item,
                        logoPath: viewModel.focusedLogoPath,
                        isLoadingLogo: viewModel.isLoadingLogo,
                        isContinueWatching: viewModel.activeRowID == HomeViewModel.continueWatchingRowID
                    )
                    // Keeps clear of the tab bar; the logo shrinks rather than crossing it.
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                } else {
                    Spacer()
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.rows) { row in
                                MediaShelf(title: row.title, items: row.items, style: row.style) { item in
                                    focus(item, inRow: row.id)
                                }
                                // Each row fills the area, bottom aligned, so whichever row is
                                // active lands in the same place.
                                .containerRelativeFrame(.vertical, alignment: .bottomLeading)
                                .id(row.id)
                            }
                        }
                    }
                    .scrollClipDisabled()
                    // Hides the rows above the active one without making them transparent: a
                    // transparent row can't take focus, which stopped the remote moving up.
                    // The mask reaches past the sides and bottom so focused cards can still lift.
                    .mask {
                        Rectangle()
                            .padding(.horizontal, -200)
                            .padding(.bottom, -200)
                    }
                    .frame(height: Self.rowAreaHeight)
                    // Focus moves first, then the active row snaps to the bottom slot.
                    .onChange(of: viewModel.activeRowID) { _, rowID in
                        guard let rowID else { return }
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(rowID, anchor: .bottom)
                        }
                    }
                }
            }
            .background {
                BackdropView(path: viewModel.focusedItem?.backdropPath)
                    .animation(.easeInOut, value: viewModel.focusedItem?.ratingKey)
            }
        }
    }

    /// Tall enough for a poster row: title, 2:3 card and its captions.
    private static let rowAreaHeight: CGFloat = 480

    private func focus(_ item: PlexMetadata, inRow rowID: String) {
        viewModel.focus(item, inRow: rowID, server: server, client: client)
    }
}

#Preview {
    HomeView(sections: [])
}
