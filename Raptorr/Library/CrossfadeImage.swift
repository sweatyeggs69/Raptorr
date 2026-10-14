import SwiftUI
import UIKit

/// A remote image that crossfades whenever its URL changes.
///
/// `AsyncImage` drops the old image as soon as the URL changes, so a new backdrop or card
/// would flash through its placeholder. This keeps showing the previous image until the next
/// one has loaded, then fades between them. Loads go through `URLSession.shared`, so they use
/// the app's URL cache.
struct CrossfadeImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode
    var alignment: Alignment
    /// Shown before anything has loaded; `true` when the last load failed.
    var placeholder: (_ failed: Bool) -> Placeholder

    @State private var image: UIImage?
    @State private var imageURL: URL?
    @State private var failed = false

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: @escaping (_ failed: Bool) -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.alignment = alignment
        self.placeholder = placeholder
        // Start on the cached image, if any, so a view rebuilt after scrolling back on
        // screen appears with its artwork already there, without a fade.
        let cached = url.flatMap(ImageMemoryCache.shared.image(for:))
        _image = State(initialValue: cached)
        _imageURL = State(initialValue: cached == nil ? nil : url)
    }

    var body: some View {
        ZStack(alignment: alignment) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    .id(imageURL)
                    .transition(.opacity)
            } else {
                placeholder(failed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: imageURL)
        .animation(.easeInOut(duration: 0.35), value: failed)
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            imageURL = nil
            failed = false
            return
        }
        guard url != imageURL else { return }
        if let cached = ImageMemoryCache.shared.image(for: url) {
            image = cached
            imageURL = url
            failed = false
            return
        }
        let loaded = try? await URLSession.shared.data(from: url).0
        guard !Task.isCancelled else { return }
        // Decode off the main thread so large backdrops don't stall focus movement.
        let decoded = await Task.detached(priority: .userInitiated) {
            loaded.flatMap(UIImage.init(data:))?.preparingForDisplay()
        }.value
        guard !Task.isCancelled else { return }
        if let decoded {
            ImageMemoryCache.shared.store(decoded, for: url)
            image = decoded
            imageURL = url
            failed = false
        } else {
            image = nil
            imageURL = nil
            failed = true
        }
    }
}

#Preview {
    CrossfadeImage(url: nil) { _ in
        Rectangle().fill(.quaternary)
    }
    .frame(width: 480, height: 270)
}
