import SwiftUI

/// Shows a checkmark only on the selected season so the row reads like a picker.
struct SeasonLabelStyle: LabelStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if isSelected {
                configuration.icon
            }
            configuration.title
        }
        .fontWeight(isSelected ? .semibold : .regular)
    }
}
