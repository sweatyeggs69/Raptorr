import Foundation

/// A movie, show, season or episode (`Metadata` in the PMS spec).
nonisolated struct PlexMetadata: Decodable, Sendable, Hashable, Identifiable {
    let ratingKey: String
    let key: String?
    let type: String?
    let title: String
    let summary: String?
    let tagline: String?
    let year: Int?
    let index: Int?
    let parentIndex: Int?
    let duration: Int?
    let viewOffset: Int?
    let viewCount: Int?
    let leafCount: Int?
    let viewedLeafCount: Int?
    let thumb: String?
    let art: String?
    let parentThumb: String?
    let grandparentThumb: String?
    let grandparentArt: String?
    let parentTitle: String?
    let grandparentTitle: String?
    let parentRatingKey: String?
    let grandparentRatingKey: String?
    let contentRating: String?
    let studio: String?
    let audienceRating: Double?
    let originallyAvailableAt: String?
    let skipChildren: Bool?
    let media: [PlexMedia]?
    let genre: [PlexTag]?
    let director: [PlexTag]?
    let role: [PlexTag]?
    let image: [PlexImage]?

    var id: String { ratingKey }

    enum CodingKeys: String, CodingKey {
        case ratingKey, key, type, title, summary, tagline, year, index, parentIndex
        case duration, viewOffset, viewCount, leafCount, viewedLeafCount
        case thumb, art, parentThumb, grandparentThumb, grandparentArt
        case parentTitle, grandparentTitle, parentRatingKey, grandparentRatingKey
        case contentRating, studio, audienceRating, originallyAvailableAt, skipChildren
        case media = "Media"
        case genre = "Genre"
        case director = "Director"
        case role = "Role"
        case image = "Image"
    }

    init(
        ratingKey: String,
        key: String? = nil,
        type: String? = nil,
        title: String,
        summary: String? = nil,
        tagline: String? = nil,
        year: Int? = nil,
        index: Int? = nil,
        parentIndex: Int? = nil,
        duration: Int? = nil,
        viewOffset: Int? = nil,
        viewCount: Int? = nil,
        leafCount: Int? = nil,
        viewedLeafCount: Int? = nil,
        thumb: String? = nil,
        art: String? = nil,
        parentThumb: String? = nil,
        grandparentThumb: String? = nil,
        grandparentArt: String? = nil,
        parentTitle: String? = nil,
        grandparentTitle: String? = nil,
        parentRatingKey: String? = nil,
        grandparentRatingKey: String? = nil,
        contentRating: String? = nil,
        studio: String? = nil,
        audienceRating: Double? = nil,
        originallyAvailableAt: String? = nil,
        skipChildren: Bool? = nil,
        media: [PlexMedia]? = nil,
        genre: [PlexTag]? = nil,
        director: [PlexTag]? = nil,
        role: [PlexTag]? = nil,
        image: [PlexImage]? = nil
    ) {
        self.ratingKey = ratingKey
        self.key = key
        self.type = type
        self.title = title
        self.summary = summary
        self.tagline = tagline
        self.year = year
        self.index = index
        self.parentIndex = parentIndex
        self.duration = duration
        self.viewOffset = viewOffset
        self.viewCount = viewCount
        self.leafCount = leafCount
        self.viewedLeafCount = viewedLeafCount
        self.thumb = thumb
        self.art = art
        self.parentThumb = parentThumb
        self.grandparentThumb = grandparentThumb
        self.grandparentArt = grandparentArt
        self.parentTitle = parentTitle
        self.grandparentTitle = grandparentTitle
        self.parentRatingKey = parentRatingKey
        self.grandparentRatingKey = grandparentRatingKey
        self.contentRating = contentRating
        self.studio = studio
        self.audienceRating = audienceRating
        self.originallyAvailableAt = originallyAvailableAt
        self.skipChildren = skipChildren
        self.media = media
        self.genre = genre
        self.director = director
        self.role = role
        self.image = image
    }
}

// MARK: - Presentation helpers

extension PlexMetadata {
    var kind: MetadataKind { MetadataKind(rawValue: type ?? "") ?? .unknown }

    /// Poster to show in grids: episodes fall back to their show's poster.
    var posterPath: String? {
        switch kind {
        case .episode: grandparentThumb ?? parentThumb ?? thumb
        case .season: thumb ?? parentThumb
        default: thumb
        }
    }

    var backdropPath: String? { art ?? grandparentArt }

    /// 16:9 artwork: an episode's still, or a movie's or show's background art.
    var landscapeImagePath: String? {
        switch kind {
        case .episode: thumb ?? art ?? grandparentArt
        default: art ?? thumb
        }
    }

    /// The item whose metadata carries the logo: the show for episodes and seasons.
    var logoSourceRatingKey: String {
        switch kind {
        case .episode: grandparentRatingKey ?? ratingKey
        case .season: parentRatingKey ?? ratingKey
        default: ratingKey
        }
    }

    /// "S1 · E3 · 2024 · TV-14 · 45m · 4K" style summary line.
    var infoLine: String {
        var parts: [String] = []
        if let label = episodeLabel { parts.append(label) }
        if let year { parts.append(String(year)) }
        if let contentRating { parts.append(contentRating) }
        if let durationText { parts.append(durationText) }
        if let resolution = media?.first?.videoResolution { parts.append(resolution.uppercased()) }
        return parts.joined(separator: " · ")
    }

    /// The transparent title treatment (`Image` of type `clearLogo`), when the server has one.
    var logoPath: String? {
        image?.first { $0.type == "clearLogo" }?.url
    }

    /// "S2 · E5" style label for episodes.
    var episodeLabel: String? {
        guard kind == .episode, let parentIndex, let index else { return nil }
        return "S\(parentIndex) · E\(index)"
    }

    /// Compact season and episode, e.g. "S2E5".
    var shortEpisodeLabel: String? {
        guard kind == .episode, let parentIndex, let index else { return nil }
        return "S\(parentIndex)E\(index)"
    }

    /// Fraction watched, for items with a saved resume point.
    var progress: Double? {
        guard let viewOffset, let duration, duration > 0, viewOffset > 0 else { return nil }
        return min(Double(viewOffset) / Double(duration), 1)
    }

    var isWatched: Bool {
        switch kind {
        case .show, .season:
            if let leafCount, let viewedLeafCount { return leafCount > 0 && viewedLeafCount >= leafCount }
            return false
        default:
            return (viewCount ?? 0) > 0 && viewOffset == nil
        }
    }

    var durationText: String? {
        guard let duration, duration > 0 else { return nil }
        let totalMinutes = duration / 60_000
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// The first playable part, used for direct play.
    var primaryPart: PlexPart? {
        media?.first?.part?.first
    }
}
