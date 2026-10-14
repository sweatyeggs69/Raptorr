import SwiftUI

/// The watched mark in a card's top right corner: a small black check in a white circle,
/// shadowed so it reads on light and dark artwork.
struct WatchedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.black, .white)
            .font(.callout)
            .shadow(color: .black.opacity(0.4), radius: 3)
            .padding(10)
            .accessibilityLabel("Watched")
    }
}

#Preview {
    Rectangle()
        .fill(.gray)
        .frame(width: 300, height: 169)
        .overlay(alignment: .topTrailing) { WatchedBadge() }
}
