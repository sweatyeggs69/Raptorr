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
    @AppStorage(InterfaceSettings.showsTabIconsKey) private var showsTabIcons = InterfaceSettings.showsTabIconsDefault

    var body: some View {
        @Bindable var playback = playback

        // Top tab bar like the Apple TV app: Home, one tab per library, Settings, and Search on the right.
        TabView(selection: $router.selection) {
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
                TabLabel(title: "Settings", systemImage: "gearshape", showsIcon: showsTabIcons)
            }

            Tab(value: .search, role: .search) {
                SearchView()
            } label: {
                // Just the magnifying glass, as in the TV app; VoiceOver still reads "Search".
                Image(systemName: "magnifyingglass")
                    .accessibilityLabel("Search")
            }
        }
        .tabViewStyle(.tabBarOnly)
        .environment(router)
        .environment(\.plexServer, activeServer)
        // Reloads when the connection moves between local, remote and relay.
        .task(id: activeServer.uri) {
            await viewModel.loadSections(server: activeServer, client: client)
        }
        // Caches every title's details in the background so detail pages open instantly.
        .task(id: activeServer.machineIdentifier + "|" + viewModel.sections.map(\.key).joined(separator: ","), priority: .background) {
            guard !viewModel.sections.isEmpty else { return }
            await LibraryPrefetcher(client: client).run(sections: viewModel.sections, server: activeServer)
        }
        .task {
            await viewModel.keepConnectionFresh(connection: connection, client: client, token: authStore.token)
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

    private var activeServer: PlexServer {
        connection.currentServer ?? server
    }
}

#Preview {
    MainTabView(server: .preview)
        .environment(AuthStore())
        .environment(ServerConnectionManager())
        .environment(PlaybackCoordinator())
}
