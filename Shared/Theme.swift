import SwiftUI

/// Color + type system tuned to match Lou's PAI statusline screenshot.
enum Theme {
    static let bg        = Color(hex: 0x0B1018)   // near-black navy terminal bg
    static let blue      = Color(hex: 0x5BA8FF)   // bright values / header
    static let cyan      = Color(hex: 0x6FC3CF)   // STATE labels
    static let dim       = Color(hex: 0x6B7480)   // muted gray labels
    static let dimmer    = Color(hex: 0x4A525E)   // empty context dots
    static let purple    = Color(hex: 0xB4A0F0)   // CONTEXT / FILES labels
    static let lavender  = Color(hex: 0x9DB4FF)   // file names
    static let green     = Color(hex: 0x6FD08C)   // good values / LEARNING
    static let orange    = Color(hex: 0xE0A45C)   // usage / histogram
    static let red       = Color(hex: 0xE06C75)   // hot values
    static let gold      = Color(hex: 0xD6B36A)   // quote
    static let burnt     = Color(hex: 0xC8612E)   // burnt-orange Claude ✻
    static let fg        = Color(hex: 0xD8DEE9)   // default text
    static let userFg    = Color(hex: 0xE8EDF4)

    /// Monospaced font at an explicit point size.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double( hex        & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

/// Tiny helper to build colored monospace runs that concatenate with `+`.
func seg(_ s: String, _ c: Color, _ w: Font.Weight = .regular, size: CGFloat = 9.5) -> Text {
    Text(s).foregroundColor(c).font(Theme.mono(size, w))
}
