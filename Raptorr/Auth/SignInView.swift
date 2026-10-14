import SwiftUI

struct SignInView: View {
    @Environment(\.plexClient) private var client
    @Environment(AuthStore.self) private var authStore
    @State private var viewModel = SignInViewModel()

    var body: some View {
        HStack(spacing: 80) {
            VStack(alignment: .leading, spacing: 32) {
                Label("Raptorr", systemImage: "play.tv")
                    .font(.largeTitle.bold())

                Text("Sign in with your Plex account")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 16) {
                    Label("Scan the code with your phone's camera", systemImage: "qrcode.viewfinder")
                    Label("Or visit plex.tv/link and enter the code", systemImage: "link")
                }
                .font(.headline)
                .foregroundStyle(.secondary)

                if let code = viewModel.code {
                    Text(code)
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            qrCode
        }
        .padding(80)
        .task {
            if let token = await viewModel.run(client: client) {
                authStore.signIn(token: token)
            }
        }
    }

    @ViewBuilder
    private var qrCode: some View {
        if let url = viewModel.linkURL, let image = QRCodeGenerator.image(for: url.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(24)
                .background(.white, in: .rect(cornerRadius: 24))
                .frame(width: 440, height: 440)
                .accessibilityLabel("QR code to sign in at plex.tv/link")
        } else {
            ProgressView()
                .frame(width: 440, height: 440)
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthStore())
}
