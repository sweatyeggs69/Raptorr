import Foundation
import Testing
@testable import Raptorr

struct ImageDiskCacheTests {
    @Test func keyIgnoresHostAndToken() throws {
        let local = try #require(URL(string: "http://192.168.1.5:32400/photo/:/transcode?url=/library/metadata/1/thumb/2&width=800&X-Plex-Token=abc"))
        let relay = try #require(URL(string: "https://relay.plex.direct:8443/photo/:/transcode?width=800&url=/library/metadata/1/thumb/2&X-Plex-Token=xyz"))

        #expect(ImageDiskCache.key(for: local) == ImageDiskCache.key(for: relay))
        #expect(!ImageDiskCache.key(for: local).contains("abc"))
    }

    @Test func keySeparatesSizes() throws {
        let small = try #require(URL(string: "http://host/photo/:/transcode?url=/a&width=400"))
        let large = try #require(URL(string: "http://host/photo/:/transcode?url=/a&width=800"))

        #expect(ImageDiskCache.key(for: small) != ImageDiskCache.key(for: large))
    }

    @Test func storedDataSurvivesANewInstance() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try #require(URL(string: "http://host/photo/:/transcode?url=/a&X-Plex-Token=t"))
        let other = try #require(URL(string: "http://other/photo/:/transcode?url=/a&X-Plex-Token=u"))

        ImageDiskCache(directory: directory).store(Data([1, 2, 3]), for: url)
        let reopened = ImageDiskCache(directory: directory)

        #expect(reopened.contains(other))
        #expect(reopened.data(for: other) == Data([1, 2, 3]))
    }
}
