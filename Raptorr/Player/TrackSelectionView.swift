import SwiftUI

/// Audio and subtitle choices for the current item.
struct TrackSelectionView: View {
    let viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Audio and Subtitles side by side, like the Apple TV app's player menu, wide enough
        // that long track names and the Auto description fit on one or two lines.
        HStack(alignment: .top, spacing: 80) {
            column("Audio") {
                if viewModel.audioTracks.isEmpty {
                    Text("No audio tracks")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.audioTracks) { track in
                    trackRow(name: track.name, isSelected: track.isSelected) {
                        viewModel.selectAudioTrack(id: track.id)
                    }
                }
            }

            column("Subtitles") {
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
        .padding(60)
        .frame(width: 1500, height: 800, alignment: .top)
        .presentationSizing(.fitted)
    }

    private func column<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title3.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
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
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                // The checkmark leads, and its space is kept on every row so names line up.
                Image(systemName: "checkmark")
                    .opacity(isSelected ? 1 : 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
