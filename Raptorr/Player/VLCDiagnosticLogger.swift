#if DEBUG
import Foundation
import VLCKit

/// Debug builds only: prints VLC's warnings and errors, plus its debug messages about seeking
/// (the MKV demuxer's index and cues, and network access), to diagnose slow seeks.
nonisolated final class VLCDiagnosticLogger: NSObject, VLCLogging, @unchecked Sendable {
    var level: VLCLogLevel = .debug

    private static let seekModules = ["mkv", "http", "access", "stream", "prefetch", "cache"]
    private static let seekWords = ["seek", "cue", "cluster", "index"]

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let module = context?.module ?? ""
        let lowered = message.lowercased()
        let isAboutSeeking = Self.seekModules.contains { module.contains($0) }
            || Self.seekWords.contains { lowered.contains($0) }
        guard logLevel.rawValue <= VLCLogLevel.warning.rawValue || isAboutSeeking else { return }
        print("[VLC \(module)] \(message)")
    }
}
#endif
