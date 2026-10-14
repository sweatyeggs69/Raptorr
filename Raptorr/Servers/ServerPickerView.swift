import SwiftUI

struct ServerPickerView: View {
    @Environment(\.plexClient) private var client
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @State private var viewModel = ServerPickerViewModel()

    var body: some View {
        content
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
            // Same two halves as the system setup screens: what this step is on the left,
            // the choices on the right.
            HStack(spacing: 80) {
                VStack(spacing: 32) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 200, weight: .light))
                        .foregroundStyle(.secondary)

                    Text("Choose a Server")
                        .font(.title2.bold())

                    Text("Pick the Plex Media Server to watch from. You can change it later in Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                List {
                    Section {
                        ForEach(viewModel.servers) { server in
                            Button {
                                connection.select(server)
                            } label: {
                                LabeledContent {
                                    Text(server.owned ? "Owned" : "Shared")
                                } label: {
                                    Label(server.name, systemImage: "server.rack")
                                }
                            }
                        }
                    }

                    Section {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                        .disabled(viewModel.isLoading)

                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            authStore.signOut()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 80)
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
