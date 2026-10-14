import SwiftUI

/// Fixed slot sizes for the Home header's title area, so the logo, title, metadata and
/// description never shift as focus moves.
enum HeaderLayout {
    static let logoWidth: CGFloat = TitleLogo.widthLimit
    static let logoHeight: CGFloat = 180
    static let spacing: CGFloat = 12
    static let summaryWidth: CGFloat = 1000
    static let summaryLines = 3
}
