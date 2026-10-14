import Foundation
import Observation
import UIKit
import VLCKit

/// Owns the VLC player for one playback session and reports progress back to Plex.
@Observable
final class PlayerViewModel {
    private(set) var item: PlexMetadata
    private(set) var phase: PlayerPhase = .loading
    private(set) var currentTimeMs = 0
    private(set) var durationMs: Int
    private(set) var audioTracks: [TrackOption] = []
    private(set) var subtitleTracks: [TrackOption] = []

    /// VLC renders into this view; `VLCVideoSurface` puts it on screen.
    let videoView = UIView()

    private let player = VLCMediaPlayer()
    private let request: PlaybackRequest
    private let server: PlexServer
    private let client: PlexAPIClient
    private let sessionIdentifier = UUID().uuidString
    @ObservationIgnored private var hasStartedPlaying = false
    @ObservationIgnored private var hasFinished = false

    /// Plex asks for a timeline report on every state change and every 10 seconds otherwise.
    private let reportInterval: Duration = .seconds(10)

    init(request: PlaybackRequest, server: PlexServer, client: PlexAPIClient) {
        self.request = request
        self.server = server
        self.client = client
        self.item = request.item
        self.durationMs = request.item.duration ?? 0
        videoView.backgroundColor = .black
        player.drawable = videoView
    }

    var isPlaying: Bool { phase == .playing }

    var progress: Double {
        guard durationMs > 0 else { return 0 }
        return min(max(Double(currentTimeMs) / Double(durationMs), 0), 1)
    }

    // MARK: - Lifecycle

    /// Starts playback and keeps state in sync until playback ends or the task is cancelled.
    func run() async {
        await start()
        guard phase != .ended, !isFailed else { return }

        var lastReportedPhase: PlayerPhase?
        var lastReport = ContinuousClock.now
        while !Task.isCancelled {
            sync()
            if phase == .ended || isFailed { break }
            if phase != lastReportedPhase || ContinuousClock.now - lastReport >= reportInterval {
                reportTimeline()
                lastReportedPhase = phase
                lastReport = .now
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        finish()
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func start() async {
        // List and hub responses can omit media parts, so fetch the full item first.
        if let full = try? await client.metadata(server: server, ratingKey: request.item.ratingKey) {
            item = full
            if let duration = full.duration { durationMs = duration }
        }

        guard let part = item.primaryPart,
              let partKey = part.key,
              let url = client.partURL(server: server, partKey: partKey),
              let media = VLCMedia(url: url) else {
            phase = .failed(PlexAPIError.noPlayableMedia.localizedDescription)
            return
        }

        if let offset = request.startOffsetMs, offset > 0 {
            media.addOption(":start-time=\(Double(offset) / 1000)")
        }
        player.media = media
        player.play()

        // Sidecar subtitle files live next to the media on the server; offer them as extra tracks.
        for stream in part.stream ?? [] where stream.isExternalSubtitle {
            if let key = stream.key, let subtitleURL = client.subtitleURL(server: server, streamKey: key) {
                _ = player.addPlaybackSlave(subtitleURL, type: .subtitle, enforce: false)
            }
        }
    }

    /// Ends the session: tells Plex where playback stopped and marks the item watched near the end.
    func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        sync()
        player.stop()

        let item = item
        let server = server
        let client = client
        let sessionIdentifier = sessionIdentifier
        let time = currentTimeMs
        let duration = durationMs
        let watched = phase == .ended || (duration > 0 && Double(time) / Double(duration) >= 0.9)
        // Unstructured so the final report survives the view's task being cancelled.
        Task {
            await client.reportTimeline(
                server: server,
                item: item,
                state: .stopped,
                timeMs: time,
                durationMs: duration,
                sessionIdentifier: sessionIdentifier
            )
            if watched {
                await client.scrobble(server: server, ratingKey: item.ratingKey)
            }
        }
    }

    // MARK: - Controls

    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
        sync()
    }

    func skip(seconds: Double) {
        guard player.isSeekable else { return }
        if seconds >= 0 {
            player.jumpForward(seconds)
        } else {
            player.jumpBackward(-seconds)
        }
    }

    func selectAudioTrack(id: String) {
        player.audioTracks.first { $0.trackId == id }?.isSelectedExclusively = true
        refreshTracks()
    }

    /// Pass `nil` to turn subtitles off.
    func selectSubtitleTrack(id: String?) {
        if let id {
            player.textTracks.first { $0.trackId == id }?.isSelectedExclusively = true
        } else {
            player.deselectAllTextTracks()
        }
        refreshTracks()
    }

    // MARK: - State sync

    private func sync() {
        currentTimeMs = Int(player.time.intValue)
        if let length = player.media?.length.intValue, length > 0 {
            durationMs = Int(length)
        }

        switch player.state {
        case .playing:
            hasStartedPlaying = true
            phase = .playing
        case .paused:
            phase = .paused
        case .stopped, .stopping:
            if hasStartedPlaying { phase = .ended }
        case .error:
            phase = .failed("VLC couldn't play this file.")
        default:
            if !hasStartedPlaying { phase = .loading }
        }
        refreshTracks()
    }

    private func refreshTracks() {
        let audio = player.audioTracks.map {
            TrackOption(id: $0.trackId, name: $0.trackName, isSelected: $0.isSelected)
        }
        let subtitles = player.textTracks.map {
            TrackOption(id: $0.trackId, name: $0.trackName, isSelected: $0.isSelected)
        }
        if audio != audioTracks { audioTracks = audio }
        if subtitles != subtitleTracks { subtitleTracks = subtitles }
    }

    private func reportTimeline() {
        let state: PlexAPIClient.TimelineState = switch phase {
        case .playing: .playing
        case .paused: .paused
        case .loading: .buffering
        case .ended, .failed: .stopped
        }
        let item = item
        let server = server
        let client = client
        let sessionIdentifier = sessionIdentifier
        let time = currentTimeMs
        let duration = durationMs
        Task {
            await client.reportTimeline(
                server: server,
                item: item,
                state: state,
                timeMs: time,
                durationMs: duration,
                sessionIdentifier: sessionIdentifier
            )
        }
    }
}
