import SwiftUI

/// Fixed slot sizes for the Home header's title area, so the logo, title, metadata and
/// description never shift as focus moves.
enum HeaderLayout {
    static let logoWidth: CGFloat = TitleLogo.widthLimit
    static let logoHeight: CGFloat = 180
    static let spacing: CGFloat = 12
    /// Extra space under the logo box. Text lines carry their own leading, so a logo that
    /// fills its box needs this to look as far from the metadata as the metadata is from
    /// the description.
    static let logoBottomPadding: CGFloat = 12
    static let summaryWidth: CGFloat = 1000
    static let summaryLines = 3
}
