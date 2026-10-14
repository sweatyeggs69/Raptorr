import SwiftUI

struct MainTabView: View {
    let server: PlexServer

    @Environment(\.plexClient) private var client
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel = MainTabViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        @Bindable var playback = playback

        // Top tab bar like the Apple TV app: Search, Home, one tab per library, then Settings.
        // Opens on Home even though Search sits first.
        TabView(selection: $selectedTab) {
            Tab(value: .search, role: .search) {
                SearchView()
            }

            Tab("Home", systemImage: "house", value: .home) {
                HomeView(sections: viewModel.sections)
            }

            ForEach(viewModel.sections) { section in
                Tab(section.title, systemImage: section.type.systemImage, value: AppTab.library(key: section.key)) {
                    LibraryView(section: section)
                }
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.tabBarOnly)
        .environment(\.plexServer, connection.currentServer ?? server)
        .task {
            await viewModel.load(server: server, client: client, connection: connection)
        }
        .fullScreenCover(item: $playback.request) { request in
            PlayerView(request: request, server: connection.currentServer ?? server, client: client)
        }
    }
}

#Preview {
    MainTabView(server: .preview)
        .environment(ServerConnectionManager())
        .environment(PlaybackCoordinator())
}
