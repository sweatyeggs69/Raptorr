import Foundation

/// Thin client for plex.tv and Plex Media Server.
///
/// Every PMS endpoint used here is documented in `plex-api.json` at the repo root; check it
/// before adding or changing a request. The plex.tv calls (`/api/v2/pins`, `/api/v2/resources`)
/// follow the "Authenticating with Plex" section of that spec's introduction.
nonisolated final class PlexAPIClient: Sendable {
    static let libraryIdentifier = "com.plexapp.plugins.library"
    /// The app's one client, the environment's default, so it isn't rebuilt on every access.
    static let shared = PlexAPIClient()

    private let session: URLSession
    private let cache: PlexResponseCache

    init(session: URLSession = .shared, cache: PlexResponseCache = .shared) {
        self.session = session
        self.cache = cache
    }

    /// Forgets every cached library response and downloaded image, e.g. on sign out.
    func clearCache() async {
        await cache.removeAll()
        ImageDiskCache.shared.removeAll()
    }

    // MARK: - plex.tv

    /// Creates a short PIN that the user can enter at plex.tv/link or claim by scanning a QR code.
    /// (`strong=true` would create a long code meant only for the Auth App URL.)
    func createPin() async throws -> PlexPin {
        let request = plexTVRequest(path: "/api/v2/pins", method: "POST")
        return try await decode(PlexPin.self, from: request)
    }

    func checkPin(id: Int) async throws -> PlexPin {
        let request = plexTVRequest(path: "/api/v2/pins/\(id)", method: "GET")
        return try await decode(PlexPin.self, from: request)
    }

    func resources(token: String) async throws -> [PlexResource] {
        var request = plexTVRequest(
            path: "/api/v2/resources",
            method: "GET",
            query: [
                URLQueryItem(name: "includeHttps", value: "1"),
                URLQueryItem(name: "includeRelay", value: "1"),
            ]
        )
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        return try await decode([PlexResource].self, from: request)
    }

    // MARK: - Server identity

    /// `GET /identity` on one connection URI, returning the server's `machineIdentifier`.
    /// Cheap and unauthenticated, so it doubles as the reachability probe; checking the
    /// identifier makes sure a LAN address reached this server and not another one.
    func machineIdentifier(atURI uri: String, timeout: TimeInterval) async -> String? {
        guard var components = URLComponents(string: uri) else { return nil }
        components.path = "/identity"
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        for (field, value) in Self.identificationHeaders() {
            request.setValue(value, forHTTPHeaderField: field)
        }
        guard let data = try? await fetch(request),
              let response = try? decodeBody(PlexResponse.self, from: data, path: "/identity") else { return nil }
        return response.mediaContainer.machineIdentifier
    }

    // MARK: - Libraries

    func librarySections(server: PlexServer, from source: DataSource = .network) async throws -> [LibrarySection] {
        try await container(server: server, path: "/library/sections/all", source: source).directory ?? []
    }

    /// One page of a library, sorted by title.
    func sectionItems(
        server: PlexServer,
        section: LibrarySection,
        start: Int,
        size: Int,
        from source: DataSource = .network
    ) async throws -> (items: [PlexMetadata], totalSize: Int?) {
        var query = [URLQueryItem(name: "sort", value: "titleSort")]
        if let type = section.type.metadataTypeNumber {
            query.append(URLQueryItem(name: "type", value: "\(type)"))
        }
        let response = try await container(
            server: server,
            path: "/library/sections/\(section.key)/all",
            query: query,
            page: (start, size),
            source: source
        )
        return (response.metadata ?? [], response.totalSize)
    }

    // MARK: - Hubs

    func continueWatching(server: PlexServer, count: Int = 20, from source: DataSource = .network) async throws -> [Hub] {
        try await container(
            server: server,
            path: "/hubs/continueWatching",
            query: [URLQueryItem(name: "count", value: "\(count)")],
            source: source
        ).hub ?? []
    }

    func sectionHubs(
        server: PlexServer,
        sectionKey: String,
        count: Int = 20,
        from source: DataSource = .network
    ) async throws -> [Hub] {
        try await container(
            server: server,
            path: "/hubs/sections/\(sectionKey)",
            query: [URLQueryItem(name: "count", value: "\(count)")],
            source: source
        ).hub ?? []
    }

    func search(server: PlexServer, query: String, limit: Int = 20) async throws -> [Hub] {
        try await container(
            server: server,
            path: "/hubs/search",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        ).hub ?? []
    }

    // MARK: - Metadata

    func metadata(server: PlexServer, ratingKey: String, from source: DataSource = .network) async throws -> PlexMetadata? {
        try await container(server: server, path: "/library/metadata/\(ratingKey)", source: source).metadata?.first
    }

    /// Fetches full metadata for several items in one `GET /library/metadata/{ids}` request
    /// (ids comma separated) and caches each item as if it had been fetched on its own, so a
    /// detail page opened later finds it with `metadata(server:ratingKey:from: .cache)`.
    func cacheMetadata(server: PlexServer, ratingKeys: [String]) async throws {
        guard !ratingKeys.isEmpty else { return }
        let path = "/library/metadata/" + ratingKeys.joined(separator: ",")
        guard let request = serverRequest(server: server, path: path) else { throw PlexAPIError.invalidURL }
        let data = try await fetch(request)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let container = root["MediaContainer"] as? [String: Any],
              let items = container["Metadata"] as? [[String: Any]] else { return }
        for item in items {
            guard let ratingKey = item["ratingKey"] as? String else { continue }
            var single = container
            single["Metadata"] = [item]
            single["size"] = 1
            let body = try JSONSerialization.data(withJSONObject: ["MediaContainer": single])
            let key = PlexResponseCache.Key(
                serverID: server.machineIdentifier,
                path: "/library/metadata/\(ratingKey)",
                query: [],
                page: nil
            )
            await cache.store(body, for: key)
        }
    }

    /// Titles similar to a movie or show (`GET /library/metadata/{ids}/similar`).
    func similar(
        server: PlexServer,
        ratingKey: String,
        count: Int = 20,
        from source: DataSource = .network
    ) async throws -> [PlexMetadata] {
        try await container(
            server: server,
            path: "/library/metadata/\(ratingKey)/similar",
            query: [URLQueryItem(name: "count", value: "\(count)")],
            source: source
        ).metadata ?? []
    }

    /// Seasons of a show, or episodes of a season. The spec requires paging headers here.
    func children(
        server: PlexServer,
        ratingKey: String,
        size: Int = 500,
        from source: DataSource = .network
    ) async throws -> [PlexMetadata] {
        try await container(
            server: server,
            path: "/library/metadata/\(ratingKey)/children",
            page: (0, size),
            source: source
        ).metadata ?? []
    }

    /// All episodes of a show, for shows flagged `skipChildren` (no season level).
    func grandchildren(
        server: PlexServer,
        ratingKey: String,
        size: Int = 1000,
        from source: DataSource = .network
    ) async throws -> [PlexMetadata] {
        try await container(
            server: server,
            path: "/library/metadata/\(ratingKey)/grandchildren",
            page: (0, size),
            source: source
        ).metadata ?? []
    }

    // MARK: - Playback reporting

    enum TimelineState: String, Sendable {
        case playing, paused, buffering, stopped
    }

    /// `POST /:/timeline`, sent on every state change and every 10 seconds while playing.
    func reportTimeline(
        server: PlexServer,
        item: PlexMetadata,
        state: TimelineState,
        timeMs: Int,
        durationMs: Int,
        sessionIdentifier: String
    ) async {
        var query = [
            URLQueryItem(name: "ratingKey", value: item.ratingKey),
            URLQueryItem(name: "key", value: item.key ?? "/library/metadata/\(item.ratingKey)"),
            URLQueryItem(name: "state", value: state.rawValue),
            URLQueryItem(name: "time", value: "\(timeMs)"),
            URLQueryItem(name: "duration", value: "\(durationMs)"),
        ]
        if state == .stopped {
            query.append(URLQueryItem(name: "continuing", value: "0"))
        }
        guard var request = serverRequest(server: server, path: "/:/timeline", query: query, method: "POST") else {
            return
        }
        request.setValue(sessionIdentifier, forHTTPHeaderField: "X-Plex-Session-Identifier")
        await fireAndForget(request, label: "timeline")
    }

    /// `PUT /:/scrobble`, marks an item as played.
    func scrobble(server: PlexServer, ratingKey: String) async {
        await setWatched(server: server, ratingKey: ratingKey, path: "/:/scrobble")
    }

    /// `PUT /:/unscrobble`, marks an item as unplayed.
    func unscrobble(server: PlexServer, ratingKey: String) async {
        await setWatched(server: server, ratingKey: ratingKey, path: "/:/unscrobble")
    }

    private func setWatched(server: PlexServer, ratingKey: String, path: String) async {
        let query = [
            URLQueryItem(name: "identifier", value: Self.libraryIdentifier),
            URLQueryItem(name: "key", value: ratingKey),
        ]
        guard let request = serverRequest(server: server, path: path, query: query, method: "PUT") else { return }
        await fireAndForget(request, label: path)
    }

    // MARK: - Stream selection

    /// `PUT /library/parts/{partId}` saves the user's audio/subtitle choice on the server so
    /// it is preselected next time (and on other Plex clients). `subtitleStreamID` 0 means none.
    func setStreamSelection(server: PlexServer, partId: Int, audioStreamID: Int? = nil, subtitleStreamID: Int? = nil) async {
        var query = [URLQueryItem(name: "allParts", value: "1")]
        if let audioStreamID {
            query.append(URLQueryItem(name: "audioStreamID", value: "\(audioStreamID)"))
        }
        if let subtitleStreamID {
            query.append(URLQueryItem(name: "subtitleStreamID", value: "\(subtitleStreamID)"))
        }
        guard let request = serverRequest(server: server, path: "/library/parts/\(partId)", query: query, method: "PUT") else {
            return
        }
        await fireAndForget(request, label: "stream selection")
    }

    // MARK: - URLs handed to other components

    /// Direct-play URL for a media part (`GET /library/parts/{partId}/{changestamp}/{filename}`).
    /// VLCKit opens this URL itself, so the token rides in the query string.
    func partURL(server: PlexServer, partKey: String) -> URL? {
        tokenizedURL(server: server, path: partKey)
    }

    /// Sidecar subtitle file (`GET /library/streams/{streamId}.{ext}`), from a stream's `key`.
    func subtitleURL(server: PlexServer, streamKey: String) -> URL? {
        tokenizedURL(server: server, path: streamKey)
    }

    /// Resized artwork through `GET /photo/:/transcode`.
    func artworkURL(server: PlexServer, path: String?, width: Int, height: Int) -> URL? {
        guard let path, !path.isEmpty,
              let baseURL = server.baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/photo/:/transcode"
        components.queryItems = [
            URLQueryItem(name: "url", value: path),
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "height", value: "\(height)"),
            URLQueryItem(name: "minSize", value: "1"),
            URLQueryItem(name: "upscale", value: "1"),
            URLQueryItem(name: "X-Plex-Token", value: server.accessToken),
        ]
        return components.url
    }

    /// A clear logo through `GET /photo/:/transcode`, kept as PNG so its transparency survives
    /// and scaled to fit inside the box rather than fill it.
    func logoURL(server: PlexServer, path: String?, width: Int, height: Int) -> URL? {
        guard let path, !path.isEmpty,
              let baseURL = server.baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/photo/:/transcode"
        components.queryItems = [
            URLQueryItem(name: "url", value: path),
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "height", value: "\(height)"),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "upscale", value: "1"),
            URLQueryItem(name: "X-Plex-Token", value: server.accessToken),
        ]
        return components.url
    }

    // MARK: - Request building

    /// The `X-Plex-*` identification headers the spec asks clients to send on every request.
    static func identificationHeaders() -> [String: String] {
        [
            "X-Plex-Client-Identifier": PlexClientIdentity.clientIdentifier,
            "X-Plex-Product": PlexClientIdentity.product,
            "X-Plex-Version": PlexClientIdentity.version,
            "X-Plex-Platform": PlexClientIdentity.platform,
            "X-Plex-Platform-Version": PlexClientIdentity.platformVersion,
            "X-Plex-Device": PlexClientIdentity.device,
            "X-Plex-Device-Name": PlexClientIdentity.deviceName,
            "Accept": "application/json",
        ]
    }

    private func plexTVRequest(path: String, method: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "plex.tv"
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        for (field, value) in Self.identificationHeaders() {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func serverRequest(
        server: PlexServer,
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        page: (start: Int, size: Int)? = nil
    ) -> URLRequest? {
        guard let baseURL = server.baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (field, value) in Self.identificationHeaders() {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue(server.accessToken, forHTTPHeaderField: "X-Plex-Token")
        if let page {
            request.setValue("\(page.start)", forHTTPHeaderField: "X-Plex-Container-Start")
            request.setValue("\(page.size)", forHTTPHeaderField: "X-Plex-Container-Size")
        }
        return request
    }

    private func tokenizedURL(server: PlexServer, path: String) -> URL? {
        guard let baseURL = server.baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "X-Plex-Token", value: server.accessToken),
            URLQueryItem(name: "X-Plex-Client-Identifier", value: PlexClientIdentity.clientIdentifier),
            URLQueryItem(name: "X-Plex-Product", value: PlexClientIdentity.product),
            URLQueryItem(name: "X-Plex-Platform", value: PlexClientIdentity.platform),
        ]
        return components.url
    }

    // MARK: - Execution

    /// Library requests go through here. `source: nil` skips the cache entirely (search).
    private func container(
        server: PlexServer,
        path: String,
        query: [URLQueryItem] = [],
        page: (start: Int, size: Int)? = nil,
        source: DataSource? = nil
    ) async throws -> MediaContainer {
        let cacheKey = PlexResponseCache.Key(serverID: server.machineIdentifier, path: path, query: query, page: page)
        if source == .cache {
            guard let data = await cache.data(for: cacheKey) else { throw PlexAPIError.notCached }
            return try decodeBody(PlexResponse.self, from: data, path: path).mediaContainer
        }
        guard let request = serverRequest(server: server, path: path, query: query, page: page) else {
            throw PlexAPIError.invalidURL
        }
        let data = try await fetch(request)
        let response = try decodeBody(PlexResponse.self, from: data, path: path)
        if source == .network {
            await cache.store(data, for: cacheKey)
        }
        return response.mediaContainer
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
        try decodeBody(T.self, from: try await fetch(request), path: request.url?.path ?? "")
    }

    private func fetch(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlexAPIError.networkError(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 401 { throw PlexAPIError.unauthorized }
            throw PlexAPIError.serverError(http.statusCode)
        }
        return data
    }

    private func decodeBody<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PlexAPIError.decodingError(error, path: path)
        }
    }

    private func fireAndForget(_ request: URLRequest, label: String) async {
        let result = try? await session.data(for: request)
        #if DEBUG
        let status = (result?.1 as? HTTPURLResponse)?.statusCode ?? -1
        if !(200...299).contains(status) {
            print("[PlexAPI] \(label) failed: \(status)")
        }
        #else
        _ = result
        #endif
    }
}
