import SwiftUI

/// The watched mark in a card's top right corner: a plain checkmark, shadowed so it reads
/// on light and dark artwork.
struct WatchedBadge: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.title3.bold())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 4)
            .padding(12)
            .accessibilityLabel("Watched")
    }
}

#Preview {
    Rectangle()
        .fill(.gray)
        .frame(width: 300, height: 169)
        .overlay(alignment: .topTrailing) { WatchedBadge() }
}
