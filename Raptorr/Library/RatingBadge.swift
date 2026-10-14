import SwiftUI

/// A content rating ("PG-13", "TV-MA") in an outlined rounded box, the way the Apple TV app
/// shows ratings in its metadata lines.
struct RatingBadge: View {
    let rating: String

    var body: some View {
        Text(rating)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.secondary, lineWidth: 2)
            }
            .accessibilityLabel("Rated \(rating)")
    }
}

#Preview {
    HStack {
        RatingBadge(rating: "PG-13")
        RatingBadge(rating: "TV-MA")
    }
    .foregroundStyle(.secondary)
}
