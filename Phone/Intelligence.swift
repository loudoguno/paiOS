import Foundation
import FoundationModels

/// Wraps Apple's on-device Foundation Models (~3B parameters, runs on the Neural Engine,
/// fully private, no network). Generates Claude-Code-style replies from a task prompt.
final class Intelligence: PromptResponder {
    static let shared = Intelligence()

    private let instructions = """
    You are Claude Code, a terminal coding agent running inside the user's PAI (Personal AI \
    Infrastructure). The user gives you a software task. Reply as if you just completed it: \
    two to five short lines of plain text — a concise summary of what you changed, a \
    file-change line such as "StatusLine.ts (+12 -3)" when it fits, and end with a brief \
    follow-up question or status. Be specific and technical. No preamble, no markdown \
    headings, no bullet characters.
    """

    /// Warm the model so the first real generation is fast.
    func prewarm() {
        guard case .available = SystemLanguageModel.default.availability else { return }
        LanguageModelSession(instructions: instructions).prewarm()
    }

    /// Generate a reply on-device. Returns "" if Apple Intelligence is unavailable so the
    /// caller can fall back gracefully.
    func respond(to prompt: String) async -> String {
        guard case .available = SystemLanguageModel.default.availability else { return "" }
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }
}
