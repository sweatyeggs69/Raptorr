import SwiftUI

struct MainTabView: View {
    let server: PlexServer

    @Environment(\.plexClient) private var client
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel = MainTabViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        @Bindable var playback = playback

        // Top tab bar like the Apple TV app: Home, one tab per library, Settings, and Search on the right.
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView(sections: viewModel.sections)
            }

            ForEach(viewModel.sections) { section in
                Tab(value: AppTab.library(key: section.key)) {
                    LibraryView(section: section)
                } label: {
                    // Plain monochrome so the icon turns black with its title when selected,
                    // like the other tabs; the "tv" symbol otherwise keeps a lighter layer.
                    Label(section.title, systemImage: section.type.systemImage)
                        .symbolRenderingMode(.monochrome)
                        .symbolVariant(.none)
                }
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }

            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.tabBarOnly)
        .environment(\.showHomeTab, { selectedTab = .home })
        .environment(\.plexServer, activeServer)
        // Reloads when the connection moves between local, remote and relay.
        .task(id: activeServer.uri) {
            await viewModel.loadSections(server: activeServer, client: client)
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
