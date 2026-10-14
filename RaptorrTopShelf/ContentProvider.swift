import TVServices

/// Shows Continue Watching on the Top Shelf as a row of 16:9 cards with progress bars, read
/// from the snapshot the app saves. With no snapshot (signed out, or the app hasn't loaded
/// Home yet) it returns nothing and the system shows the static Top Shelf image.
class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        guard TopShelfStore.directory != nil else {
            TopShelfStore.log("extension: no App Group container; check the App Groups capability on RaptorrTopShelf")
            return nil
        }
        guard let snapshot = TopShelfStore.read(), !snapshot.items.isEmpty else {
            TopShelfStore.log("extension: no saved items")
            return nil
        }
        TopShelfStore.log("extension: showing \(snapshot.items.count) items")

        let items = snapshot.items.map { item in
            let shelfItem = TVTopShelfSectionedItem(identifier: item.identifier)
            shelfItem.title = item.title
            shelfItem.imageShape = .hdtv
            if let fileName = item.imageFileName, let url = TopShelfStore.imageURL(fileName: fileName) {
                shelfItem.setImageURL(url, for: [.screenScale1x, .screenScale2x])
            }
            if let progress = item.progress {
                shelfItem.playbackProgress = progress
            }
            shelfItem.displayAction = TVTopShelfAction(url: item.displayURL)
            shelfItem.playAction = TVTopShelfAction(url: item.playURL)
            return shelfItem
        }

        let collection = TVTopShelfItemCollection(items: items)
        collection.title = "Continue Watching"
        return TVTopShelfSectionedContent(sections: [collection])
    }
}
