import SwiftUI

/// Full-screen VLC playback with Siri Remote controls.
///
/// Select or Play/Pause toggles playback, left/right skip 10 seconds, swipe down opens
/// audio and subtitle options, and Menu hides the info overlay or closes the player.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerViewModel
    @State private var isOverlayVisible = true
    @State private var isShowingTracks = false
    @State private var overlayHideTask: Task<Void, Never>?

    init(request: PlaybackRequest, server: PlexServer, client: PlexAPIClient = PlexAPIClient()) {
        _viewModel = State(initialValue: PlayerViewModel(request: request, server: server, client: client))
    }

    var body: some View {
        ZStack {
            VLCVideoSurface(videoView: viewModel.videoView)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .loading:
                ProgressView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("Can't Play This Item", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Close") { dismiss() }
                }
            default:
                EmptyView()
            }

            if isOverlayVisible {
                PlayerOverlay(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .background(.black)
        .focusable()
        .onTapGesture { togglePlayPause() }
        .onPlayPauseCommand { togglePlayPause() }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                viewModel.skip(seconds: -10)
                showOverlay()
            case .right:
                viewModel.skip(seconds: 10)
                showOverlay()
            case .down:
                isShowingTracks = true
            case .up:
                showOverlay()
            @unknown default:
                break
            }
        }
        .onExitCommand {
            if isOverlayVisible && viewModel.isPlaying {
                withAnimation { isOverlayVisible = false }
            } else {
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingTracks) {
            TrackSelectionView(viewModel: viewModel)
        }
        .task {
            await viewModel.run()
        }
        .onChange(of: viewModel.phase) { _, phase in
            switch phase {
            case .ended:
                dismiss()
            case .playing:
                scheduleOverlayHide()
            default:
                showOverlay(autoHide: false)
            }
        }
        .onDisappear {
            overlayHideTask?.cancel()
            viewModel.finish()
        }
    }

    private func togglePlayPause() {
        viewModel.togglePlayPause()
        showOverlay()
    }

    private func showOverlay(autoHide: Bool = true) {
        withAnimation { isOverlayVisible = true }
        if autoHide { scheduleOverlayHide() }
    }

    private func scheduleOverlayHide() {
        overlayHideTask?.cancel()
        overlayHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, viewModel.isPlaying else { return }
            withAnimation { isOverlayVisible = false }
        }
    }
}

#Preview {
    PlayerView(request: PlaybackRequest(item: .previewMovie, startOffsetMs: nil), server: .preview)
}
