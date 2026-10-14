import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @State private var isConfirmingSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Server") {
                    if let server = connection.currentServer {
                        LabeledContent("Name", value: server.name)
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
            .navigationTitle("Settings")
            .alert("Sign Out of Plex?", isPresented: $isConfirmingSignOut) {
                Button("Sign Out", role: .destructive) {
                    connection.disconnect()
                    authStore.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to watch anything.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthStore())
        .environment(ServerConnectionManager())
}
