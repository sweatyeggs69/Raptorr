import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(\.plexClient) private var client
    @State private var isConfirmingSignOut = false
    @Environment(TabRouter.self) private var router

    var body: some View {
        NavigationStack {
            List {
                Section("Server") {
                    if let server = connection.currentServer {
                        LabeledContent("Name", value: server.name)
                        LabeledContent("Connection", value: connectionDescription(for: server))
                        LabeledContent("Address", value: server.uri)
                    }
                    Button("Switch Server", systemImage: "server.rack") {
                        connection.disconnect()
                    }
                }

                Section("Account") {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        isConfirmingSignOut = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: PlexClientIdentity.version)
                    LabeledContent("Playback", value: "VLCKit")
                }
            }
            .frame(maxWidth: 1200)
            // Back goes to Home rather than closing the app.
            .onExitCommand { router.selection = .home }
            .alert("Sign Out of Plex?", isPresented: $isConfirmingSignOut) {
                Button("Sign Out", role: .destructive) {
                    connection.disconnect()
                    authStore.signOut()
                    Task { await client.clearCache() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to watch anything.")
            }
        }
    }

    private func connectionDescription(for server: PlexServer) -> String {
        guard connection.isReachable else { return "Unavailable" }
        return server.connectionKind?.title ?? "Unknown"
    }
}

#Preview {
    SettingsView()
        .environment(AuthStore())
        .environment(ServerConnectionManager())
        .environment(TabRouter())
}
