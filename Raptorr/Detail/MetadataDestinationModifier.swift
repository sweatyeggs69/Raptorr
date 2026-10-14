import SwiftUI

/// Routes a pushed `PlexMetadata` value to the right detail screen, and a cast member
/// (`PlexTag`) to their person page.
struct MetadataDestinationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
        .navigationDestination(for: PlexTag.self) { person in
            PersonView(person: person)
                .modifier(PopOnExitModifier())
        }
        .navigationDestination(for: PlexMetadata.self) { item in
            Group {
                switch item.kind {
                case .show, .season:
                    ShowDetailView(item: item)
                default:
                    ItemDetailView(item: item)
                }
            }
            .modifier(PopOnExitModifier())
        }
    }
}

extension View {
    func metadataDestinations() -> some View {
        modifier(MetadataDestinationModifier())
    }
}
