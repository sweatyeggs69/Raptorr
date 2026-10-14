import SwiftUI

/// Every movie or show in one library, as a poster grid.
struct LibraryView: View {
    let section: LibrarySection

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server
    @State private var viewModel = LibraryViewModel()
    @State private var path = NavigationPath()
    @FocusState private var focusedID: String?
    @State private var jumpTask: Task<Void, Never>?
    @State private var isLetterBarFocused = false
    @Environment(TabRouter.self) private var router
    @Environment(BackgroundActivity.self) private var activity

    /// Six posters across; at 230pt they fit beside the letter bar in the 1080p safe area.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40, alignment: .top), count: 6)
    private let posterWidth = Self.posterWidth
    private var posterSize: CGSize { Self.posterSize }

    static let posterWidth: CGFloat = 230
    /// The poster size requested (twice the point size), matching `PosterCard`; the
    /// background prefetch asks for the same size so the grid finds it cached.
    static var posterSize: CGSize { CGSize(width: posterWidth * 2, height: posterWidth * 3) }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .metadataDestinations()
        }
        // Lets Back from the grid move focus up to the tab bar instead of going to Home.
        .onChange(of: focusedID != nil || isLetterBarFocused || !path.isEmpty) { _, isFocused in
            guard router.selection == .library(key: section.key) else { return }
            router.isContentFocused = isFocused
        }
        // Reloads when the connection moves between local, remote and relay.
        // While the library is on screen: the whole library and every poster, so nothing waits
        // on the server while scrolling or jumping to a letter.
        // Also reloads when a background sync finishes, picking up added or changed titles.
        .task(id: "\(server.uri)|\(activity.libraryRevision)") {
            await activity.track {
                await viewModel.load(section: section, server: server, client: client)
                await viewModel.loadEverything(section: section, posterSize: posterSize, server: server, client: client)
            }
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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 60) {
                        ForEach(viewModel.items) { item in
                            PosterCard(item: item, width: posterWidth, focus: $focusedID)
                                .id(item.id)
                                .task {
                                    await viewModel.itemAppeared(item, section: section, posterSize: posterSize, server: server, client: client)
                                }
                        }
                    }
                    .padding(.vertical, 40)
                    // Room for the letter bar, so the last column isn't under it.
                    .padding(.trailing, viewModel.letters.count > 1 ? LetterJumpBar.width + 16 : 0)
                }
                .scrollClipDisabled()
                // An overlay rather than a sibling, so the bar never changes the grid's size.
                .overlay(alignment: .trailing) {
                    if viewModel.letters.count > 1 {
                        LetterJumpBar(letters: viewModel.letters) { letter in
                            jump(to: letter, proxy: proxy, focusTitle: false)
                        } onSelect: { letter in
                            jump(to: letter, proxy: proxy, focusTitle: true)
                        } onFocusChange: { isFocused in
                            isLetterBarFocused = isFocused
                        }
                    }
                }
            }
        }
    }

    /// Scrolls to the letter's first title; on select, also moves focus onto it. A newer
    /// jump replaces one still loading, so sweeping through the letters lands on the last.
    /// The scroll is instant: animating it slid the lazily built rows sideways as they appeared.
    private func jump(to letter: LetterJump, proxy: ScrollViewProxy, focusTitle: Bool) {
        jumpTask?.cancel()
        jumpTask = Task {
            guard let id = await viewModel.jump(to: letter, section: section, server: server, client: client),
                  !Task.isCancelled else { return }
            viewModel.keepPostersWarm(near: letter.offset, posterSize: posterSize, server: server, client: client, force: true)
            proxy.scrollTo(id, anchor: .topLeading)
            guard focusTitle else { return }
            // The lazy grid builds the card after the scroll; focus it once it exists.
            try? await Task.sleep(for: .milliseconds(100))
            focusedID = id
        }
    }
}

#Preview {
    LibraryView(section: LibrarySection(key: "1", type: .movie, title: "Movies"))
        .environment(TabRouter())
        .environment(BackgroundActivity())
}
