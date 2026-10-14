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
    private(set) var subtitleMode: SubtitleMode = .auto
    /// Clear logo for the overlay: the movie's own, or the show's for an episode.
    private(set) var logoPath: String?

    /// VLC renders into this view; `VLCVideoSurface` puts it on screen.
    let videoView = UIView()

    private let player = VLCMediaPlayer()
    private let request: PlaybackRequest
    private let server: PlexServer
    private let client: PlexAPIClient
    private let sessionIdentifier = UUID().uuidString
    @ObservationIgnored private var hasStartedPlaying = false
    @ObservationIgnored private var hasFinished = false
    @ObservationIgnored private var plexAudioStreams: [PlexStream] = []
    @ObservationIgnored private var plexSubtitleStreams: [PlexStream] = []
    @ObservationIgnored private var hasAppliedInitialTracks = false
    @ObservationIgnored private var playingTicks = 0
    /// The resume point, until playback has reached it. VLC's `:start-time=` option left
    /// resumed playback stuck at 0:00, so the player seeks once playback starts instead.
    @ObservationIgnored private var pendingResumeMs: Int?
    @ObservationIgnored private var resumeDeadline: ContinuousClock.Instant?
    @ObservationIgnored private var hasSentResumeSeek = false
    @ObservationIgnored private var resumeLandedAtMs: Int?

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
        #if DEBUG
        // VLC's own messages about seeking (demuxer index, network access).
        VLCLibrary.shared().loggers = [VLCDiagnosticLogger()]
        #endif
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
            // Checks often while a resume is pending, so each step of it starts right away.
            try? await Task.sleep(for: .milliseconds(pendingResumeMs == nil ? 500 : 50))
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
        if item.kind == .episode, let showKey = item.grandparentRatingKey {
            logoPath = try? await client.metadata(server: server, ratingKey: showKey)?.logoPath
        } else {
            logoPath = item.logoPath
        }

        guard let part = item.primaryPart,
              let partKey = part.key,
              let url = client.partURL(server: server, partKey: partKey),
              let media = VLCMedia(url: url) else {
            phase = .failed(PlexAPIError.noPlayableMedia.localizedDescription)
            return
        }

        plexAudioStreams = TrackMatching.plexAudioStreams(in: part)
        plexSubtitleStreams = TrackMatching.plexSubtitleStreams(in: part)

        // Seeks land on the nearest keyframe instead of decoding up to the exact frame, which
        // stalled the hardware decoder on large files (resume froze while the clock ran).
        media.addOption(":input-fast-seek")
        // VLC's default MKV demuxer treats the file's seek index (cues) as untrusted and, since
        // it can't scan ahead over HTTP, seeked from the first frame instead: resume and
        // scrubbing took 20+ seconds. Its trusted variant jumps straight to the cue.
        if partKey.lowercased().hasSuffix(".mkv") {
            media.addOption(":demux=mkv_trusted,any")
        }
        // VLC buffers a full second of network data before it starts and after every seek. On
        // the home network a third of that is plenty; remote and relay keep the default.
        if server.connectionKind == .local {
            media.addOption(":network-caching=300")
        }
        if let offset = request.startOffsetMs, offset > 0 {
            pendingResumeMs = offset
            currentTimeMs = offset
            // Hidden until the seek lands, so the opening frames never flash by.
            videoView.isHidden = true
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
            // The Top Shelf's Continue Watching now has a new resume point (or one item fewer).
            if let hubs = try? await client.continueWatching(server: server) {
                await TopShelfPublisher(client: client).publish(hubs.flatMap(\.items), server: server)
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
        hasAppliedInitialTracks = true
        player.audioTracks.first { $0.trackId == id }?.isSelectedExclusively = true
        refreshTracks()
        // Auto follows the audio language, so a new language may need a different forced track.
        if subtitleMode == .auto { applySubtitleMode() }
        if let streamID = audioTracks.first(where: { $0.id == id })?.plexStreamID {
            saveSelection(audioStreamID: streamID)
        }
    }

    func selectSubtitleMode(_ mode: SubtitleMode) {
        hasAppliedInitialTracks = true
        subtitleMode = mode
        applySubtitleMode()
        switch mode {
        case .off, .auto:
            saveSelection(subtitleStreamID: 0)
        case .track(let id):
            if let streamID = subtitleTracks.first(where: { $0.id == id })?.plexStreamID {
                saveSelection(subtitleStreamID: streamID)
            }
        }
    }

    private func applySubtitleMode() {
        let selectedID: String? = switch subtitleMode {
        case .off: nil
        case .auto:
            TrackMatching.forcedTrack(
                in: subtitleTracks,
                audioLanguage: audioTracks.first(where: \.isSelected)?.languageCode
            )?.id
        case .track(let id): id
        }
        if let selectedID, let track = player.textTracks.first(where: { $0.trackId == selectedID }) {
            track.isSelectedExclusively = true
        } else {
            player.deselectAllTextTracks()
        }
        refreshTracks()
    }

    /// Once VLC has listed the tracks, start on the server's preferred audio and subtitle,
    /// or Auto (forced only) when no subtitle was chosen. Gives up waiting for sidecar files
    /// after a few seconds so the user's preference still applies to what has loaded.
    private func applyInitialTracksIfReady() {
        guard !hasAppliedInitialTracks, hasStartedPlaying else { return }
        playingTicks += 1
        let allListed = player.audioTracks.count >= plexAudioStreams.count
            && player.textTracks.count >= plexSubtitleStreams.count
        guard allListed || playingTicks >= 10 else { return }
        hasAppliedInitialTracks = true

        if let preferredAudio = audioTracks.first(where: \.isPlexSelected), !preferredAudio.isSelected {
            player.audioTracks.first { $0.trackId == preferredAudio.id }?.isSelectedExclusively = true
            refreshTracks()
        }
        subtitleMode = TrackMatching.initialSubtitleMode(for: subtitleTracks)
        applySubtitleMode()
    }

    private func saveSelection(audioStreamID: Int? = nil, subtitleStreamID: Int? = nil) {
        guard let partID = item.primaryPart?.id else { return }
        let server = server
        let client = client
        Task {
            await client.setStreamSelection(
                server: server,
                partId: partID,
                audioStreamID: audioStreamID,
                subtitleStreamID: subtitleStreamID
            )
        }
    }

    // MARK: - State sync

    private func sync() {
        if let length = player.media?.length.intValue, length > 0 {
            durationMs = Int(length)
        }
        if pendingResumeMs != nil, player.state == .playing {
            seekToResumePoint()
        }
        // Until the resume seek lands, the timeline shows the resume point, not 0:00.
        currentTimeMs = pendingResumeMs ?? Int(player.time.intValue)

        switch player.state {
        case .playing:
            hasStartedPlaying = true
            phase = pendingResumeMs == nil ? .playing : .loading
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
        applyInitialTracksIfReady()
    }

    /// Seeks to the resume point once VLC's video is actually running, then shows the video
    /// when playback is moving from there. Seeking the moment VLC reports playing (before its
    /// video output exists) froze the picture for a long time; a later seek, like a skip, works.
    /// Audio stays muted until then, so the opening never plays out loud.
    private func seekToResumePoint() {
        guard let target = pendingResumeMs else { return }
        if resumeDeadline == nil {
            resumeDeadline = .now + .seconds(10)
            player.audio?.isMuted = true
        }
        let time = Int(player.time.intValue)
        let isPastDeadline = ContinuousClock.now >= resumeDeadline!

        if !hasSentResumeSeek {
            let isVideoRunning = player.hasVideoOut && time >= 300
            guard player.isSeekable, isVideoRunning || isPastDeadline else { return }
            hasSentResumeSeek = true
            player.time = VLCTime(number: NSNumber(value: target))
            #if DEBUG
            print("[Player] resume seek to \(target)ms sent at \(time)ms (video out: \(player.hasVideoOut)) \(Date.now.formatted(date: .omitted, time: .standard))")
            #endif
            return
        }

        // Landed (fast seek stops on the keyframe before the target) and moving on from there.
        if resumeLandedAtMs == nil, time >= target - 5000 {
            resumeLandedAtMs = time
        }
        let isMoving = resumeLandedAtMs.map { time >= $0 + 300 } ?? false
        #if DEBUG
        print("[Player] resume: time=\(time)ms target=\(target)ms landed=\(resumeLandedAtMs.map(String.init) ?? "no")")
        #endif
        if isMoving || isPastDeadline {
            #if DEBUG
            print("[Player] resume shown (moving: \(isMoving)) \(Date.now.formatted(date: .omitted, time: .standard))")
            #endif
            pendingResumeMs = nil
            videoView.isHidden = false
            player.audio?.isMuted = false
        }
    }

    private func refreshTracks() {
        let audio = TrackMatching.options(
            vlc: player.audioTracks.map { TrackMatching.VLCTrack(id: $0.trackId, name: $0.trackName, isSelected: $0.isSelected) },
            plex: plexAudioStreams
        )
        let subtitles = TrackMatching.options(
            vlc: player.textTracks.map { TrackMatching.VLCTrack(id: $0.trackId, name: $0.trackName, isSelected: $0.isSelected) },
            plex: plexSubtitleStreams
        )
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
