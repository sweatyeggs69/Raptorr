import SwiftUI

/// A titled horizontal row of posters or 16:9 cards.
struct MediaShelf: View {
    let title: String
    let items: [PlexMetadata]
    var style: ShelfStyle = .poster
    /// Called with the card that just gained focus.
    var onFocus: ((PlexMetadata) -> Void)?
    /// Changing this forgets the last focused card, so focus next lands on the first one.
    var resetID = 0

    @FocusState private var focusedID: String?
    /// The card that last had focus, so coming back to the row returns to it.
    @State private var lastFocusedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(items) { item in
                        switch style {
                        case .poster:
                            PosterCard(item: item, width: style.cardWidth, onFocus: focusAction(for: item), focus: $focusedID)
                        case .landscape:
                            LandscapeCard(item: item, width: style.cardWidth, onFocus: focusAction(for: item), focus: $focusedID)
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        .fullWidthFocusSection()
        .onChange(of: focusedID) { previous, id in
            guard let id else { return }
            // Focus coming in from another row lands on whichever card sits under the old
            // one; send it to the card last focused here, or the first, like the TV app.
            if previous == nil, let target = lastFocusedID ?? items.first?.id, target != id {
                Task { focusedID = target }
                return
            }
            lastFocusedID = id
        }
        .onChange(of: resetID) {
            lastFocusedID = nil
        }
    }

    private func focusAction(for item: PlexMetadata) -> (() -> Void)? {
        guard let onFocus else { return nil }
        return { onFocus(item) }
    }
}

#Preview {
    NavigationStack {
        MediaShelf(title: "Continue Watching", items: [.previewEpisode, .previewMovie], style: .landscape)
    }
}
