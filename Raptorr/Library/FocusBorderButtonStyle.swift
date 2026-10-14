import SwiftUI

/// Card buttons without the system's zoom on focus; the focused card shows a border on its
/// artwork instead (`focusBorder(_:)`).
struct FocusBorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == FocusBorderButtonStyle {
    static var focusBorder: FocusBorderButtonStyle { FocusBorderButtonStyle() }
}

#Preview {
    Button {} label: {
        Rectangle()
            .fill(.gray)
            .frame(width: 300, height: 450)
            .focusBorder(.rect(cornerRadius: 12))
    }
    .buttonStyle(.focusBorder)
}
