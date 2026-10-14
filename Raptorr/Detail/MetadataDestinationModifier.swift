import SwiftUI

/// Routes a pushed `PlexMetadata` value to the right detail screen.
struct MetadataDestinationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: PlexMetadata.self) { item in
            switch item.kind {
            case .show, .season:
                ShowDetailView(item: item)
            default:
                ItemDetailView(item: item)
            }
        }
    }
}

extension View {
    func metadataDestinations() -> some View {
        modifier(MetadataDestinationModifier())
    }
}
