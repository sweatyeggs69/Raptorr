#if DEBUG
import Foundation
import VLCKit

/// Debug builds only: prints VLC's warnings and errors. Not debug messages: VLC sends
/// thousands a second during playback, which made video choppy on a real Apple TV.
nonisolated final class VLCDiagnosticLogger: NSObject, VLCLogging, @unchecked Sendable {
    var level: VLCLogLevel = .warning

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        print("[VLC \(context?.module ?? "")] \(message)")
    }
}
#endif
