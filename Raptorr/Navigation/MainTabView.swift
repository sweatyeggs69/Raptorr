import SwiftUI

struct MainTabView: View {
    let server: PlexServer

    @Environment(\.plexClient) private var client
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel = MainTabViewModel()
    @State private var router = TabRouter()
    @State private var activity = BackgroundActivity()
    @State private var isShowingFirstSyncNotice = false
    /// Bumped by the sync button; each bump runs a full sync whether or not one is due.
    @State private var syncRequests = 0
    @AppStorage(InterfaceSettings.showsTabIconsKey) private var showsTabIcons = InterfaceSettings.showsTabIconsDefault

    var body: some View {
        @Bindable var playback = playback

        tabs
            .environment(router)
            .environment(activity)
            .environment(\.plexServer, activeServer)
            // Reloads when the connection moves between local, remote and relay.
            .task(id: activeServer.uri) {
                await viewModel.loadSections(server: activeServer, client: client)
            }
            // Caches every title's details in the background so detail pages open instantly.
            // The sync button re-runs it on demand, ignoring the schedule.
            .task(id: syncTaskID, priority: .background) {
                await sync()
            }
            // Every library's posters, fetched while the user is still on Home so the Movies and
            // TV Shows grids open with their artwork ready.
            .task(id: sectionsTaskID, priority: .background) {
                await cachePosters()
            }
            .alert("Setting Up Your Library", isPresented: $isShowingFirstSyncNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(firstSyncMessage)
            }
            .task {
                await viewModel.keepConnectionFresh(connection: connection, client: client, token: authStore.token)
            }
            // Top Shelf cards: selecting one opens its page, Play resumes it.
            .onOpenURL { url in
                guard let link = TopShelfLink(url: url) else { return }
                Task { await open(link) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await connection.refreshConnection(token: authStore.token, client: client) }
            }
            .fullScreenCover(item: $playback.request) { request in
                PlayerView(request: request, server: activeServer, client: client)
                    // The cover sits outside the `.environment` above, so it needs the server
                    // again; without it the title logo asked the preview server and never loaded.
                    .environment(\.plexServer, activeServer)
            }
    }

    private var tabs: some View {
        // Top tab bar like the Apple TV app: Search on the left, Home, one tab per library,
        // and an icon-only Settings on the right. Sync sits outside it, on the left.
        TabView(selection: $router.selection) {
            Tab(value: .search, role: .search) {
                SearchView()
            } label: {
                // Just the magnifying glass, as in the TV app; VoiceOver still reads "Search".
                Image(systemName: "magnifyingglass")
                    .accessibilityLabel("Search")
            }

            Tab(value: .home) {
                HomeView(sections: viewModel.sections)
            } label: {
                TabLabel(title: "Home", systemImage: "house", showsIcon: showsTabIcons)
            }

            ForEach(viewModel.sections) { section in
                Tab(value: AppTab.library(key: section.key)) {
                    LibraryView(section: section)
                } label: {
                    TabLabel(title: section.title, systemImage: section.type.systemImage, showsIcon: showsTabIcons)
                }
            }

            Tab(value: .settings) {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
        }
        .tabViewStyle(.tabBarOnly)
        .onExitCommand(perform: exitAction)
        .overlay {
            TopBarAccessories(isSyncing: activity.isRunning) {
                syncRequests += 1
            }
        }
    }

    private var activeServer: PlexServer {
        connection.currentServer ?? server
    }

    /// Only set with focus on the tab bar of a tab other than Home; otherwise the system's
    /// Back applies (content to tab bar, Home's tab bar leaves the app).
    private var exitAction: (() -> Void)? {
        if router.isContentFocused || router.selection == .home { return nil }
        return { router.selection = .home }
    }

    private var sectionsTaskID: String {
        let keys = viewModel.sections.map(\.key).joined(separator: ",")
        return "\(activeServer.machineIdentifier)|\(keys)"
    }

    private var syncTaskID: String {
        "\(sectionsTaskID)|\(syncRequests)"
    }

    private var firstSyncMessage: String {
        "Raptorr is downloading your library from \(activeServer.name) so it opens quickly from now on. This first sync can take a while. You can keep browsing; the sync button in the top left shows it's still working."
    }

    private func sync() async {
        let force = syncRequests > 0
        guard !viewModel.sections.isEmpty, force || LibraryPrefetcher.isDue(for: activeServer) else { return }
        if !LibraryPrefetcher.hasRun(for: activeServer) {
            isShowingFirstSyncNotice = true
        }
        let sections = viewModel.sections
        let server = activeServer
        let finished = await activity.track {
            await LibraryPrefetcher(client: client).run(sections: sections, server: server, force: force)
        }
        if finished { activity.libraryDidChange() }
    }

    private func open(_ link: TopShelfLink) async {
        let server = activeServer
        guard link.machineIdentifier == server.machineIdentifier else { return }
        switch link.action {
        case .play:
            // The server's resume point first, since it may be newer than the cached one.
            guard let item = await metadata(link.ratingKey, server: server, sources: [.network, .cache]) else { return }
            playback.play(item)
        case .show:
            guard let item = await metadata(link.ratingKey, server: server, sources: [.cache, .network]) else { return }
            playback.request = nil
            router.show(item)
        }
    }

    private func metadata(_ ratingKey: String, server: PlexServer, sources: [DataSource]) async -> PlexMetadata? {
        for source in sources {
            if let item = try? await client.metadata(server: server, ratingKey: ratingKey, from: source) {
                return item
            }
        }
        return nil
    }

    private func cachePosters() async {
        guard !viewModel.sections.isEmpty else { return }
        let sections = viewModel.sections
        let server = activeServer
        await activity.track {
            await LibraryPrefetcher(client: client).cachePosters(sections: sections, server: server, size: LibraryView.posterSize)
        }
    }
}

#Preview {
    MainTabView(server: .preview)
        .environment(AuthStore())
        .environment(ServerConnectionManager())
        .environment(PlaybackCoordinator())
}
