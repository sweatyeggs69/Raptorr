import SwiftUI

/// Full-bleed background art, darkened toward the content side so text stays readable.
struct BackdropView: View {
    let path: String?

    var body: some View {
        ZStack {
            Color.black
            if path != nil {
                ArtworkImage(path: path, width: 1920, height: 1080, placeholderSymbol: "photo")
            }
            LinearGradient(
                colors: [.black.opacity(0.9), .black.opacity(0.6), .black.opacity(0.2)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    BackdropView(path: nil)
}
