import Foundation
import Testing
@testable import Raptorr

struct PlexResponseCacheTests {
    private func makeCache() -> (PlexResponseCache, URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return (PlexResponseCache(directory: directory), directory)
    }

    @Test func keyIgnoresQueryOrder() {
        let first = PlexResponseCache.Key(
            serverID: "abc",
            path: "/library/sections/1/all",
            query: [URLQueryItem(name: "sort", value: "titleSort"), URLQueryItem(name: "type", value: "1")],
            page: (0, 100)
        )
        let second = PlexResponseCache.Key(
            serverID: "abc",
            path: "/library/sections/1/all",
            query: [URLQueryItem(name: "type", value: "1"), URLQueryItem(name: "sort", value: "titleSort")],
            page: (0, 100)
        )

        #expect(first == second)
        #expect(first.fileName == second.fileName)
    }

    @Test func keySeparatesPagesAndServers() {
        let page0 = PlexResponseCache.Key(serverID: "abc", path: "/p", query: [], page: (0, 100))
        let page1 = PlexResponseCache.Key(serverID: "abc", path: "/p", query: [], page: (100, 100))
        let otherServer = PlexResponseCache.Key(serverID: "def", path: "/p", query: [], page: (0, 100))

        #expect(page0 != page1)
        #expect(page0.fileName != otherServer.fileName)
    }

    @Test func storedDataSurvivesANewInstance() async {
        let (cache, directory) = makeCache()
        let key = PlexResponseCache.Key(serverID: "abc", path: "/library/sections/all", query: [], page: nil)
        await cache.store(Data("hello".utf8), for: key)

        let reopened = PlexResponseCache(directory: directory)
        #expect(await reopened.data(for: key) == Data("hello".utf8))
    }

    @Test func removeAllForgetsEverything() async {
        let (cache, _) = makeCache()
        let key = PlexResponseCache.Key(serverID: "abc", path: "/library/sections/all", query: [], page: nil)
        await cache.store(Data("hello".utf8), for: key)
        await cache.removeAll()

        #expect(await cache.data(for: key) == nil)
    }

    @Test func cacheOnlyRequestThrowsOnMiss() async {
        let (cache, _) = makeCache()
        let client = PlexAPIClient(cache: cache)
        let server = PlexServer(
            name: "Test",
            uri: "http://127.0.0.1:1",
            machineIdentifier: "abc",
            accessToken: "secret",
            owned: true,
            connections: []
        )

        await #expect(throws: PlexAPIError.self) {
            try await client.librarySections(server: server, from: .cache)
        }
    }

    @Test func cacheOnlyRequestDecodesStoredResponse() async throws {
        let (cache, _) = makeCache()
        let client = PlexAPIClient(cache: cache)
        let server = PlexServer(
            name: "Test",
            uri: "http://127.0.0.1:1",
            machineIdentifier: "abc",
            accessToken: "secret",
            owned: true,
            connections: []
        )
        let json = #"{"MediaContainer":{"size":1,"Directory":[{"key":"1","type":"movie","title":"Movies"}]}}"#
        await cache.store(
            Data(json.utf8),
            for: PlexResponseCache.Key(serverID: "abc", path: "/library/sections/all", query: [], page: nil)
        )

        let sections = try await client.librarySections(server: server, from: .cache)
        #expect(sections.map(\.title) == ["Movies"])
    }
}
