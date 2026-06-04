import SwiftUI

/// Faithful re-creation of Lou's PAI statusline startup banner, sized for the watch.
/// Each logical row is one auto-shrinking monospace line, so it reads like a terminal.
struct PAIStatusLine: View {
    let time: String
    var place: String = "NEW YORK, NY"
    var temp: String = "72°F"
    var isNight: Bool = true

    private let sz: CGFloat = 9.5

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // ── header
            row(
                seg("✲ ", Theme.blue, .bold) + seg("PAI", Theme.blue, .bold)
                + seg("  │  ", Theme.dimmer) + seg("🇺🇸 " + place, Theme.fg)
                + seg("  │  ", Theme.dimmer) + seg(time, Theme.blue)
                + seg("  │  ", Theme.dimmer) + seg((isNight ? "🌙 " : "☀️ ") + temp, Theme.fg)
            )
            // remote-control premise + effort
            HStack(spacing: 4) {
                PulsingDot()
                seg("Remote Control active", Theme.green, .bold, size: 9)
                Spacer(minLength: 0)
                (seg("● ", Theme.orange, .regular, size: 8) + seg("high · /effort", Theme.dim, .regular, size: 8))
            }
            divider()

            // ── STATE bars
            row(
                seg("STATE: ", Theme.dim)
                + seg("HEALTH ", Theme.cyan) + seg("68% ", Theme.blue, .bold)
                + seg("CREATIVE ", Theme.dim) + seg("31% ", Theme.dim)
                + seg("FREEDOM ", Theme.cyan) + seg("78% ", Theme.blue, .bold)
                + seg("RELATIONS ", Theme.cyan) + seg("84% ", Theme.blue, .bold)
                + seg("FIN ", Theme.cyan) + seg("42%", Theme.dim)
            )
            divider()

            // ── versions / counts
            row(
                seg("CC: ", Theme.dim) + seg("2.1.114", Theme.blue)
                + seg(" │ ", Theme.dimmer) + seg("PAI:", Theme.dim) + seg("5.0.0 ", Theme.blue)
                + seg("ALG:", Theme.dim) + seg("3.28.0", Theme.blue)
                + seg(" │ ", Theme.dimmer) + seg("SK:", Theme.dim) + seg("47🌐 ", Theme.fg) + seg("56🏠", Theme.fg)
                + seg(" │ ", Theme.dimmer) + seg("WF:", Theme.dim) + seg("442", Theme.green)
                + seg(" │ ", Theme.dimmer) + seg("HK:", Theme.dim) + seg("39", Theme.cyan)
            )
            divider()

            // ── context meter
            HStack(spacing: 3) {
                seg("CONTEXT:", Theme.purple, .bold, size: 9)
                ContextDots()
                seg("4%", Theme.green, .bold, size: 9)
            }
            divider()

            // ── loaded files
            (
                seg("FILES(5): ", Theme.dim)
                + seg("PRINCIPAL_IDENTITY.md, DA_IDENTITY.md, PROJECTS.md, PRINCIPAL_TELOS.md, PAI_ARCHITECTURE_SUMMARY.md", Theme.lavender)
            )
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            divider()

            // ── usage
            row(
                seg("USE: ", Theme.dim) + seg("5HR: ", Theme.dim) + seg("71% ", Theme.orange, .bold)
                + seg("↻TODAY@1600 ", Theme.dim) + seg("│ ", Theme.dimmer)
                + seg("WEEK: ", Theme.dim) + seg("32% ", Theme.green, .bold)
                + seg("↻FRI@1400 ", Theme.dim) + seg("(", Theme.dimmer) + seg("SUB", Theme.orange)
                + seg("/", Theme.dimmer) + seg("API", Theme.dim) + seg(") (19m)", Theme.dimmer)
            )
            divider()

            // ── learning
            row(
                seg("LEARNING: ", Theme.green, .bold) + seg("│ ", Theme.dimmer)
                + seg("2IMP ", Theme.red) + seg("60m: ", Theme.dim) + seg("3.5 ", Theme.red)
                + seg("1d: ", Theme.dim) + seg("4 ", Theme.red) + seg("1mo: ", Theme.dim) + seg("4.3", Theme.red)
            )
            Histogram(label: "60m", seed: 7)
            Histogram(label: "1d",  seed: 3)
            Histogram(label: "1mo", seed: 11)
            divider()

            // ── quote
            (
                seg("\"The more one judges, the less one loves.\" ", Theme.gold)
                + seg("—Honore de Balzac", Theme.gold, .bold)
            )
            .lineLimit(3)
            .italic()
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private func row(_ t: Text) -> some View {
        t.lineLimit(1).minimumScaleFactor(0.35)
    }

    private func divider() -> some View {
        Rectangle().fill(Theme.dimmer.opacity(0.4)).frame(height: 0.5)
    }
}

/// Little database-cylinder context meter: a few filled, the rest empty, a couple hot dots.
private struct ContextDots: View {
    var body: some View {
        HStack(spacing: 1.0) {
            ForEach(0..<18, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: 2.8, height: 6)
            }
        }
    }
    private func color(for i: Int) -> Color {
        switch i {
        case 0...1:  return Theme.green
        case 5:      return Theme.orange
        case 10, 14: return Theme.red
        default:     return Theme.dimmer.opacity(0.55)
        }
    }
}

/// A learning-histogram row: label + a run of tiny colored bars at varied heights.
private struct Histogram: View {
    let label: String
    let seed: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.2) {
            Text(label)
                .font(Theme.mono(8))
                .foregroundColor(Theme.dim)
                .frame(width: 22, alignment: .trailing)
            ForEach(0..<34, id: \.self) { i in
                let h = bar(i)
                Rectangle()
                    .fill(color(i))
                    .frame(width: 2.4, height: h)
                    .opacity(h > 1 ? 1 : 0)
            }
        }
        .frame(height: 9, alignment: .bottom)
    }

    private func bar(_ i: Int) -> CGFloat {
        let v = (i &* 1103515245 &+ seed &* 12345) & 0xFF
        if v < 90 { return 0 }                 // gaps
        return CGFloat(2 + (v % 7))
    }
    private func color(_ i: Int) -> Color {
        let v = (i &* 2654435761 &+ seed) & 0xFF
        if v < 30 { return Theme.red }
        if v < 55 { return Theme.blue }
        return Theme.orange
    }
}
