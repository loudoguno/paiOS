import SwiftUI

/// Terminal input mode: talk to the on-device agent, or capture an issue for pai-upgrade.
enum TerminalMode: String, CaseIterable, Identifiable {
    case agent = "Agent"
    case issue = "Issue"
    var id: String { rawValue }
}

/// Drives the voice → on-device-format → review → file-to-GitHub flow.
/// Lives only on iPhone (the watch target doesn't compile Phone/).
@MainActor
final class IssueIntake: ObservableObject {
    enum Stage: Equatable { case idle, formatting, review, sending, done, failed }

    @Published var draft = ""                    // raw dictated text from the prompt bar
    @Published var stage: Stage = .idle
    @Published var title = ""
    @Published var body = ""
    @Published var labelsText = "voice"          // comma-separated, editable in the sheet
    @Published var resultNumber: Int?
    @Published var resultURL: URL?
    @Published var errorText: String?
    @Published var showComposer = false
    @Published var hasToken = KeychainStore.hasToken

    func refreshToken() { hasToken = KeychainStore.hasToken }

    func saveToken(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty { KeychainStore.clear() } else { KeychainStore.set(v) }
        refreshToken()
    }

    /// Take the dictated draft, format it on-device, and open the review sheet.
    func prepare() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorText = nil
        resultURL = nil
        resultNumber = nil
        stage = .formatting
        showComposer = true
        Task {
            let d = await Intelligence.shared.formatIssue(from: text)
            self.title = d.title
            self.body = d.body
            self.stage = .review
        }
    }

    /// File the reviewed issue to pai-upgrade.
    func send() {
        guard stage == .review || stage == .failed else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { errorText = "Title can't be empty."; return }
        let b = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let labels = labelsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        stage = .sending
        errorText = nil
        Task {
            do {
                let issue = try await GitHubClient.createIssue(title: t, body: b, labels: labels)
                self.resultNumber = issue.number
                self.resultURL = issue.url
                self.stage = .done
                self.draft = ""
            } catch {
                self.errorText = error.localizedDescription
                self.stage = .failed
            }
        }
    }

    func reset() {
        showComposer = false
        stage = .idle
        title = ""
        body = ""
        errorText = nil
    }
}

// MARK: - Terminal input UI (iOS)

/// Agent / Issue segmented toggle plus a settings gear, sitting above the prompt line.
struct TerminalModeToggle: View {
    @Binding var mode: TerminalMode
    var hasToken: Bool
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TerminalMode.allCases) { m in
                Button { mode = m } label: {
                    seg(m.rawValue, mode == m ? Theme.userFg : Theme.dim,
                        mode == m ? .bold : .regular, size: 10)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(mode == m ? Theme.burnt.opacity(0.22) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            if mode == .issue && !hasToken {
                seg("no token", Theme.red, .regular, size: 8.5)
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
            }
            .buttonStyle(.plain)
        }
    }
}

/// The Issue-mode prompt line — mirrors PromptBar but routes to the issue flow on submit.
struct IssuePromptBar: View {
    @ObservedObject var intake: IssueIntake
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            seg("✦", Theme.green, .bold, size: 13)
            TextField("Dictate an issue for pai-upgrade…", text: $intake.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .foregroundColor(Theme.userFg)
                .focused($focused)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit { intake.prepare() }
            Button { intake.prepare() } label: {
                seg("file", Theme.green, .bold, size: 10)
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .disabled(intake.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.green.opacity(0.5), lineWidth: 0.75)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green.opacity(0.04)))
        )
    }
}

// MARK: - Review + send sheet

struct IssueComposerView: View {
    @ObservedObject var intake: IssueIntake
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Group {
                    switch intake.stage {
                    case .formatting: formatting
                    case .done:       done
                    default:          reviewForm
                    }
                }
                .padding(16)
            }
            .navigationTitle("File to pai-upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(intake.stage == .done ? "Done" : "Cancel") { intake.reset(); dismiss() }
                        .foregroundColor(Theme.dim)
                }
            }
        }
    }

    private var formatting: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.green)
            seg("Shaping your note on-device…", Theme.dim, .regular, size: 11)
        }
    }

    private var reviewForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            seg("loudoguno/pai-upgrade", Theme.dim, .regular, size: 9.5)

            seg("TITLE", Theme.cyan, .bold, size: 9)
            TextField("Title", text: $intake.title, axis: .vertical)
                .font(Theme.mono(13, .bold))
                .foregroundColor(Theme.userFg)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.04)))

            seg("BODY", Theme.cyan, .bold, size: 9)
            TextEditor(text: $intake.body)
                .font(Theme.mono(11))
                .foregroundColor(Theme.fg)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: 240)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.04)))

            seg("LABELS (comma-separated)", Theme.cyan, .bold, size: 9)
            TextField("voice", text: $intake.labelsText)
                .font(Theme.mono(10))
                .foregroundColor(Theme.orange)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.04)))

            if let err = intake.errorText {
                seg("⚠ " + err, Theme.red, .regular, size: 10)
            }

            Button(action: { intake.send() }) {
                HStack {
                    if intake.stage == .sending {
                        ProgressView().tint(Theme.bg).scaleEffect(0.8)
                        seg("Filing…", Theme.bg, .bold, size: 12)
                    } else {
                        seg(intake.stage == .failed ? "Retry" : "Send to pai-upgrade", Theme.bg, .bold, size: 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 9).fill(intake.hasToken ? Theme.green : Theme.dim))
            }
            .buttonStyle(.plain)
            .disabled(intake.stage == .sending || !intake.hasToken)

            if !intake.hasToken {
                seg("Add a GitHub token in Settings (gear) first.", Theme.red, .regular, size: 9.5)
            }
            Spacer(minLength: 0)
        }
    }

    private var done: some View {
        VStack(spacing: 14) {
            seg("✓", Theme.green, .bold, size: 40)
            if let n = intake.resultNumber {
                seg("Filed issue #\(n)", Theme.userFg, .bold, size: 14)
            }
            if let url = intake.resultURL {
                Button { openURL(url) } label: {
                    seg("Open on GitHub →", Theme.blue, .regular, size: 11)
                }
                .buttonStyle(.plain)
            }
            Button { intake.reset(); dismiss() } label: {
                seg("Done", Theme.bg, .bold, size: 12)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.green))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - Token settings sheet

struct TokenSettingsView: View {
    @ObservedObject var intake: IssueIntake
    @Environment(\.dismiss) private var dismiss
    @State private var entry = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    seg("GitHub token", Theme.userFg, .bold, size: 13)
                    seg("Fine-grained PAT scoped to loudoguno/pai-upgrade with Issues: Read & write. Stored only in this device's Keychain.",
                        Theme.dim, .regular, size: 10)

                    SecureField("github_pat_…", text: $entry)
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.userFg)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.05)))

                    HStack {
                        seg(intake.hasToken ? "● token saved" : "○ no token saved",
                            intake.hasToken ? Theme.green : Theme.dim, .regular, size: 10)
                        Spacer()
                        if intake.hasToken {
                            Button { intake.saveToken(""); entry = "" } label: {
                                seg("Clear", Theme.red, .regular, size: 10)
                            }.buttonStyle(.plain)
                        }
                    }

                    Button {
                        intake.saveToken(entry)
                        entry = ""
                        dismiss()
                    } label: {
                        seg("Save", Theme.bg, .bold, size: 12)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 9)
                                .fill(entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dim : Theme.green))
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(Theme.dim)
                }
            }
        }
    }
}
