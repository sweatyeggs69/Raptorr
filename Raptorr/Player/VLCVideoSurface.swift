import SwiftUI
import UIKit

/// Hosts the view VLC draws video into.
struct VLCVideoSurface: UIViewRepresentable {
    let videoView: UIView

    func makeUIView(context: Context) -> UIView {
        videoView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
