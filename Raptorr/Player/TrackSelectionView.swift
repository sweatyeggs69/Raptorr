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
                    trackRow(name: "Off", isSelected: viewModel.subtitleMode == .off) {
                        viewModel.selectSubtitleMode(.off)
                    }
                    trackRow(
                        name: "Auto (Recommended)",
                        detail: "Shows forced subtitles when dialogue isn't in the audio language",
                        isSelected: viewModel.subtitleMode == .auto
                    ) {
                        viewModel.selectSubtitleMode(.auto)
                    }
                    ForEach(viewModel.subtitleTracks) { track in
                        trackRow(name: track.name, isSelected: viewModel.subtitleMode == .track(id: track.id)) {
                            viewModel.selectSubtitleMode(.track(id: track.id))
                        }
                    }
                }
            }
            .navigationTitle("Audio & Subtitles")
        }
    }

    private func trackRow(
        name: String,
        detail: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
