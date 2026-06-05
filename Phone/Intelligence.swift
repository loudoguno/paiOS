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

/// The shaped result of turning a spoken note into a GitHub issue.
struct IssueDraft {
    var title: String
    var body: String
}

extension Intelligence {
    private static let issueInstructions = """
    You convert a short spoken note into a GitHub issue for an operations repository. Output \
    plain text in exactly this shape: the FIRST line is a concise, specific, imperative title \
    under 70 characters; then ONE blank line; then the body — a clear description in plain \
    sentences, using "- " bullets for any steps, tasks, or lists. Do not use markdown \
    headings, code fences, or a "Title:" label. Do not invent details that were not said; if \
    the note is vague, keep the body short rather than padding it.
    """

    /// Reshape a dictated transcript into a clean issue (title + body) entirely on-device.
    /// Falls back to a sensible split of the raw text if Apple Intelligence is unavailable.
    func formatIssue(from transcript: String) async -> IssueDraft {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .available = SystemLanguageModel.default.availability else {
            return Self.fallbackIssue(from: cleaned)
        }
        do {
            let session = LanguageModelSession(instructions: Self.issueInstructions)
            let response = try await session.respond(to: cleaned)
            return Self.parseIssue(response.content, original: cleaned)
        } catch {
            return Self.fallbackIssue(from: cleaned)
        }
    }

    /// Split the model's "title\n\nbody" output into fields, tolerating stray prefixes.
    static func parseIssue(_ raw: String, original: String) -> IssueDraft {
        let lines = raw.components(separatedBy: "\n")
        guard let titleIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return fallbackIssue(from: original)
        }
        var title = lines[titleIdx].trimmingCharacters(in: .whitespaces)
        // Strip a few shapes the small model sometimes emits despite instructions.
        for prefix in ["Title:", "title:", "#", "-", "•"] {
            if title.hasPrefix(prefix) { title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
        }
        title = String(title.prefix(120))

        let body = lines[(titleIdx + 1)...]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return IssueDraft(
            title: title.isEmpty ? String(original.prefix(60)) : title,
            body:  body.isEmpty  ? original : body
        )
    }

    /// No-model fallback: first sentence becomes the title, full note becomes the body.
    static func fallbackIssue(from text: String) -> IssueDraft {
        let firstSentence = text.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? text
        let title = String(firstSentence.prefix(60)).trimmingCharacters(in: .whitespaces)
        return IssueDraft(title: title.isEmpty ? "Voice note" : title, body: text.isEmpty ? "(empty)" : text)
    }
}
