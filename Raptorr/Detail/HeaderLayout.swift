import SwiftUI

/// Fixed slot sizes for the title area shared by Home and the detail pages, so the logo,
/// title, metadata and description sit in the same place everywhere and never shift.
enum HeaderLayout {
    static let logoWidth: CGFloat = 640
    static let logoHeight: CGFloat = 180
    static let spacing: CGFloat = 12
    static let summaryWidth: CGFloat = 1000
    static let summaryLines = 3
}
