import SwiftUI

struct ServerPickerView: View {
    @Environment(\.plexClient) private var client
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @State private var viewModel = ServerPickerViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Choose a Server")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.servers.isEmpty {
            ProgressView("Looking for servers…")
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Servers", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
                Button("Sign Out", role: .destructive) { authStore.signOut() }
            }
        } else if viewModel.servers.isEmpty {
            ContentUnavailableView {
                Label("No Servers Found", systemImage: "server.rack")
            } description: {
                Text("Make sure your Plex Media Server is running and signed in to the same account.")
            } actions: {
                Button("Try Again") { Task { await load() } }
                Button("Sign Out", role: .destructive) { authStore.signOut() }
            }
        } else {
            List(viewModel.servers) { server in
                Button {
                    connection.select(server)
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(server.name)
                            Text(server.owned ? "Owned" : "Shared with you")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "server.rack")
                    }
                }
            }
            .frame(maxWidth: 1000)
        }
    }

    private func load() async {
        guard let token = authStore.token else { return }
        await viewModel.load(token: token, client: client, connection: connection)
    }
}

#Preview {
    ServerPickerView()
        .environment(AuthStore())
        .environment(ServerConnectionManager())
}
