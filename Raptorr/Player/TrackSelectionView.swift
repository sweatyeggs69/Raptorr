import SwiftUI

/// Audio and subtitle choices for the current item.
struct TrackSelectionView: View {
    let viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Audio") {
                    if viewModel.audioTracks.isEmpty {
                        Text("No audio tracks").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.audioTracks) { track in
                        trackRow(name: track.name, isSelected: track.isSelected) {
                            viewModel.selectAudioTrack(id: track.id)
                        }
                    }
                }

                Section("Subtitles") {
                    trackRow(name: "Off", isSelected: !viewModel.subtitleTracks.contains(where: \.isSelected)) {
                        viewModel.selectSubtitleTrack(id: nil)
                    }
                    ForEach(viewModel.subtitleTracks) { track in
                        trackRow(name: track.name, isSelected: track.isSelected) {
                            viewModel.selectSubtitleTrack(id: track.id)
                        }
                    }
                }
            }
            .navigationTitle("Audio & Subtitles")
        }
    }

    private func trackRow(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack {
                Text(name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

#Preview {
    TrackSelectionView(
        viewModel: PlayerViewModel(
            request: PlaybackRequest(item: .previewMovie, startOffsetMs: nil),
            server: .preview,
            client: PlexAPIClient()
        )
    )
}
