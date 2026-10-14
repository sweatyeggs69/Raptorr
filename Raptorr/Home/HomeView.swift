import SwiftUI

/// Apple TV style Home: the focused card's backdrop, logo, metadata and description on top,
/// Continue Watching as 16:9 cards, then each library's rows.
struct HomeView: View {
    let sections: [LibrarySection]

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @Environment(TabRouter.self) private var router
    @Environment(BackgroundActivity.self) private var activity
    @State private var viewModel = HomeViewModel()
    @State private var path = NavigationPath()
    @State private var snapTask: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .metadataDestinations()
        }
        // Reloads when the libraries change or the connection moves (local, remote, relay).
        // Also reloads when a background sync finishes, picking up added or changed titles.
        .task(id: server.uri + "|" + sections.map(\.key).joined(separator: ",") + "|\(activity.libraryRevision)") {
            await activity.track {
                await viewModel.load(sections: sections, server: server, client: client)
            }
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
            VStack(alignment: .leading, spacing: 24) {
                // Logo, text and backdrop change together: the old header fades out as the
                // new one fades in.
                ZStack(alignment: .bottomLeading) {
                    if let header = viewModel.header {
                        FocusedItemHeader(
                            item: header.item,
                            logoPath: header.logoPath,
                            isContinueWatching: header.isContinueWatching
                        )
                        .id(header.id)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .animation(.easeInOut(duration: 0.35), value: viewModel.header?.id)

                ScrollViewReader { proxy in
                    ScrollView {
                        // Not lazy: the row above the active one sits off screen, and a lazy
                        // stack could drop it, leaving nothing above for the remote to move to
                        // except the tab bar.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.rows) { row in
                                MediaShelf(
                                    title: row.title,
                                    items: row.items,
                                    style: row.style,
                                    onFocus: { item in
                                        focus(item, inRow: row.id)
                                        snap(to: row.id, proxy: proxy)
                                    },
                                    resetID: router.homeReturns
                                )
                                // Room below the cards for the focus lift, so the focus engine
                                // has no reason to scroll.
                                .padding(.bottom, Self.liftAllowance)
                                // Moving up lands in the row above even when no card sits
                                // directly above the focused one (a short or scrolled row).
                                .fullWidthFocusSection()
                                // Each row fills the area, bottom aligned, so whichever row is
                                // active lands in the same place.
                                .containerRelativeFrame(.vertical, alignment: .bottomLeading)
                                .id(row.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    // Every row is exactly one viewport tall, so any scroll the focus engine
                    // makes on its own still lands with a whole row in place.
                    .scrollTargetBehavior(.viewAligned)
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
                    // Coming back from another tab starts over: back to the top level, the
                    // first row and its first card, like the TV app.
                    .onChange(of: router.homeReturns) {
                        path = NavigationPath()
                        guard let row = viewModel.rows.first, let item = row.items.first else { return }
                        focus(item, inRow: row.id)
                        proxy.scrollTo(row.id, anchor: .bottom)
                    }
                }
            }
            // Keeps the header clear of the tab bar.
            .padding(.top, 60)
            .background {
                BackdropView(path: viewModel.header?.item.backdropPath)
            }
        }
    }

    /// Tall enough for a poster row (title, 2:3 card, two caption lines) plus the lift allowance.
    private static let rowAreaHeight: CGFloat = 480
    private static let liftAllowance: CGFloat = 30

    /// Keeps the active row locked to the bottom. Snaps on every focus change, then once more
    /// after the focus engine's own scroll settles: scrolling a row sideways can make the
    /// engine nudge the outer scroll view after our snap, which pushed the row title up under
    /// the description.
    private func snap(to rowID: String, proxy: ScrollViewProxy) {
        withAnimation(.easeInOut) {
            proxy.scrollTo(rowID, anchor: .bottom)
        }
        snapTask?.cancel()
        snapTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(rowID, anchor: .bottom)
            }
        }
    }

    private func focus(_ item: PlexMetadata, inRow rowID: String) {
        viewModel.focus(item, inRow: rowID, server: server, client: client)
    }
}

#Preview {
    HomeView(sections: [])
        .environment(TabRouter())
        .environment(BackgroundActivity())
}
