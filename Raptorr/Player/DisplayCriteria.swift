import AVFoundation
import AVKit
import CoreMedia

/// The display mode a video stream wants: its frame rate and dynamic range. The Apple TV's
/// Match Content settings only switch modes when an app asks; AVPlayer does that on its own,
/// VLC doesn't, so the player asks through the window's `AVDisplayManager`.
enum DisplayCriteria {
    static func make(for stream: PlexStream) -> AVDisplayCriteria? {
        guard let frameRate = stream.frameRate?.value, frameRate > 0 else { return nil }

        let transfer: CFString = switch stream.colorTrc {
        case "smpte2084": kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ
        case "arib-std-b67": kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG
        default: kCMFormatDescriptionTransferFunction_ITU_R_709_2
        }
        let isWideGamut = stream.colorPrimaries == "bt2020"
        let extensions: [CFString: Any] = [
            kCMFormatDescriptionExtension_TransferFunction: transfer,
            kCMFormatDescriptionExtension_ColorPrimaries: isWideGamut
                ? kCMFormatDescriptionColorPrimaries_ITU_R_2020
                : kCMFormatDescriptionColorPrimaries_ITU_R_709_2,
            kCMFormatDescriptionExtension_YCbCrMatrix: (stream.colorSpace ?? "").hasPrefix("bt2020")
                ? kCMFormatDescriptionYCbCrMatrix_ITU_R_2020
                : kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2,
        ]
        let codec: CMVideoCodecType = stream.codec == "hevc" ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264

        var description: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codec,
            width: Int32(stream.width ?? 3840),
            height: Int32(stream.height ?? 2160),
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &description
        )
        guard status == noErr, let description else { return nil }
        return AVDisplayCriteria(refreshRate: Float(frameRate), formatDescription: description)
    }
}
