import SwiftUI
import DaylightCore

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

enum Design {
    static let ink = Color(hex: 0x2D302C)
    static let muted = Color(hex: 0x74766F)
    static let canvas = Color(hex: 0xF5F4EF)
    static let line = Color(hex: 0xE3E2DB)
    static let orange = Color(hex: 0xBE5035)
}

extension Accent {
    var color: Color {
        switch self {
        case .coral: Color(hex: 0xF18B6C)
        case .gold: Color(hex: 0xE6BB61)
        case .mint: Color(hex: 0xA3C9B5)
        case .blue: Color(hex: 0x99B6E1)
        case .rose: Color(hex: 0xD9A2B7)
        }
    }
    var darkColor: Color {
        switch self {
        case .coral: Color(hex: 0xA13D27)
        case .gold: Color(hex: 0x80601F)
        case .mint: Color(hex: 0x31664D)
        case .blue: Color(hex: 0x3D5D91)
        case .rose: Color(hex: 0x884B63)
        }
    }
}

extension WidgetTheme {
    var background: Color {
        switch self {
        case .midnight: Color(hex: 0x212422)
        case .paper: Color(hex: 0xF9F8F3)
        case .sand: Color(hex: 0xE9DDC9)
        case .forest: Color(hex: 0x20382F)
        }
    }
    var foreground: Color { isDark ? Color(hex: 0xF4F1E8) : Color(hex: 0x30352E) }
    var secondary: Color { isDark ? Color(hex: 0xAFB3AA) : Color(hex: 0x656A60) }
    var isDark: Bool { self == .midnight || self == .forest }
    var flap: Color { isDark ? Color.white.opacity(0.055) : Color.white.opacity(0.47) }
    func tint(_ accent: Accent) -> Color { isDark ? accent.color : accent.darkColor }
}

struct IconButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium)).frame(width: 30, height: 30)
                .contentShape(Rectangle())
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
