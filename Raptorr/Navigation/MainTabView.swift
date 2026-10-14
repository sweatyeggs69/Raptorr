import SwiftUI

struct MainTabView: View {
    let server: PlexServer

    @Environment(\.plexClient) private var client
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var viewModel = MainTabViewModel()

    var body: some View {
        @Bindable var playback = playback

        TabView {
            Tab("Home", systemImage: "house") {
                HomeView(sections: viewModel.sections)
            }

            ForEach(viewModel.sections) { section in
                Tab(section.title, systemImage: section.type.systemImage) {
                    LibraryView(section: section)
                }
            }

            Tab(role: .search) {
                SearchView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
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
