import SwiftUI

struct ContentView: View {
    @StateObject private var engine = PAIEngine()
    @StateObject private var weather = LocationWeather()
    @State private var clock = Self.now()

    #if os(iOS)
    @StateObject private var intake = IssueIntake()
    @State private var mode: TerminalMode = .agent
    @State private var showSettings = false
    #endif

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // ── Claude Code startup header (top)
                    ClaudeCodeHeader()

                    // ── conversation (scrollback)
                    ForEach(engine.lines) { line in
                        TranscriptRow(line: line)
                    }

                    if engine.phase == .thinking {
                        Throbber(engine: engine)
                    }

                    // ── input line / interrupt — the active row we keep in view
                    Group {
                        if engine.phase == .idle {
                            #if os(iOS)
                            VStack(alignment: .leading, spacing: 5) {
                                TerminalModeToggle(mode: $mode, hasToken: intake.hasToken) {
                                    intake.refreshToken(); showSettings = true
                                }
                                if mode == .issue {
                                    IssuePromptBar(intake: intake)
                                } else {
                                    PromptBar(engine: engine)
                                }
                            }
                            #else
                            PromptBar(engine: engine)
                            #endif
                        } else {
                            InterruptBar(engine: engine)
                        }
                    }
                    .id("active")

                    // ── PAI statusline pinned beneath the conversation, just like the terminal
                    Rectangle().fill(Theme.dimmer.opacity(0.4)).frame(height: 0.5).padding(.top, 3)
                    PAIStatusLine(time: clock, place: weather.place, temp: weather.temp, isNight: weather.isNight)
                    seg("← for agents", Theme.dim, .regular, size: 9)
                        .padding(.bottom, 2)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .onAppear { weather.start(); maybeAutoDemo() }
            .onReceive(timer) { _ in clock = Self.now() }
            .onChange(of: engine.lines.count) { _, _ in
                withAnimation { proxy.scrollTo("active", anchor: .bottom) }
            }
            .onChange(of: engine.phase) { _, _ in
                withAnimation { proxy.scrollTo("active", anchor: .bottom) }
            }
            #if os(iOS)
            .sheet(isPresented: $intake.showComposer) {
                IssueComposerView(intake: intake)
            }
            .sheet(isPresented: $showSettings) {
                TokenSettingsView(intake: intake)
            }
            #endif
        }
    }

    /// Simulator-only self-test hook: set env KC_DEMO=1 to auto-fire a prompt so the
    /// throbber + streamed-response states can be captured without manual input.
    /// Never triggers in normal use on the watch.
    private func maybeAutoDemo() {
        guard ProcessInfo.processInfo.environment["KC_DEMO"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            engine.draft = "wire the new voice into the notify path"
            engine.send()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static func now() -> String { timeFormatter.string(from: Date()) }
}

/// The Claude Code startup header: pixel mascot + version, model, cwd, setup issues.
struct ClaudeCodeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 7) {
                ClaudeBot()
                VStack(alignment: .leading, spacing: 1) {
                    (seg("Claude Code", Theme.userFg, .bold, size: 12)
                        + seg(" v2.1.162", Theme.dim, .regular, size: 9))
                    seg("Opus 4.8 (1M context) · Claude Max", Theme.dim, .regular, size: 8)
                        .lineLimit(1).minimumScaleFactor(0.55)
                    seg("~/code", Theme.dim, .regular, size: 8.5)
                }
            }
            (seg("⚠ ", Theme.orange, .regular, size: 9)
                + seg("2 setup issues: ", Theme.dim, .regular, size: 9)
                + seg("MCP", Theme.fg, .regular, size: 9)
                + seg(" · ", Theme.dimmer, .regular, size: 9)
                + seg("/doctor", Theme.blue, .regular, size: 9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pixel-art Claude Code "alien" mascot — same artwork as the app icon.
struct ClaudeBot: View {
    private let rows = [
        "..X...X..",   // antennae
        ".XXXXXXX.",   // head top
        "XXXXXXXXX",
        "XooXXXooX",   // eyes
        "XXXXXXXXX",
        "XXXXXXXXX",
        "XXXXXXXXX",
        ".X.X.X.X."    // legs
    ]
    private let s: CGFloat = 3.6

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { r in
                let chars = Array(rows[r])
                HStack(spacing: 0) {
                    ForEach(chars.indices, id: \.self) { c in
                        Rectangle().fill(col(chars[c])).frame(width: s, height: s)
                    }
                }
            }
        }
        .padding(.top, 1)
    }

    private func col(_ ch: Character) -> Color {
        switch ch {
        case "X": return Color(hex: 0xCC6E42)
        case "o": return Color(hex: 0x171110)
        default:  return .clear
        }
    }
}

/// One line of transcript: user prompt, tool action, or streamed assistant text.
struct TranscriptRow: View {
    let line: Line

    var body: some View {
        switch line.role {
        case .user:
            (seg("> ", Theme.blue, .bold, size: 11) + seg(line.text, Theme.userFg, .regular, size: 11))
                .fixedSize(horizontal: false, vertical: true)
        case .tool:
            Text(line.text)
                .font(Theme.mono(10))
                .foregroundColor(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        case .assistant:
            Text(line.text)
                .font(Theme.mono(11))
                .foregroundColor(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The thinking indicator: braille spinner + whimsical gerund + token/elapsed + esc-to-interrupt.
struct Throbber: View {
    @ObservedObject var engine: PAIEngine
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            (seg(engine.brailleFrame + " ", Theme.orange, .bold, size: 12)
                + seg(engine.spinnerWord + "…", Theme.orange, .regular, size: 12))
                .opacity(pulse ? 1.0 : 0.55)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            (seg("(\(Int(engine.elapsed))s · ↑ ", Theme.dim, .regular, size: 8.5)
                + seg(tok, Theme.dim, .regular, size: 8.5)
                + seg(" tokens · ", Theme.dim, .regular, size: 8.5)
                + seg("esc to interrupt", Theme.red, .regular, size: 8.5)
                + seg(")", Theme.dim, .regular, size: 8.5))
        }
        .padding(.vertical, 2)
    }

    private var tok: String {
        engine.tokens >= 1000
            ? String(format: "%.1fk", Double(engine.tokens) / 1000.0)
            : "\(engine.tokens)"
    }
}

/// The prompt line. Tap to type / Scribble / dictate (watchOS input is free).
struct PromptBar: View {
    @ObservedObject var engine: PAIEngine
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            // Static burnt-orange Claude throbber as the prompt indicator.
            seg("✻", Theme.burnt, .bold, size: 13)
            TextField("Message Claude…", text: $engine.draft)
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .foregroundColor(Theme.userFg)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { engine.send() }
                .disabled(engine.phase != .idle)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.dimmer.opacity(0.6), lineWidth: 0.75)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        )
    }
}

/// Always-enabled interrupt target shown while the agent is thinking or streaming.
struct InterruptBar: View {
    @ObservedObject var engine: PAIEngine
    var body: some View {
        Button(action: { engine.interrupt() }) {
            HStack(spacing: 5) {
                seg("◼ ", Theme.red, .bold, size: 11)
                    + seg("tap to interrupt", Theme.dim, .regular, size: 10)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.red.opacity(0.5), lineWidth: 0.75)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.red.opacity(0.06)))
            )
        }
        .buttonStyle(.plain)
    }
}

/// A green "connection alive" dot that gently breathes.
struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.green)
            .frame(width: 6, height: 6)
            .opacity(on ? 1.0 : 0.4)
            .shadow(color: Theme.green.opacity(on ? 0.7 : 0.0), radius: 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

#Preview {
    ContentView()
}
