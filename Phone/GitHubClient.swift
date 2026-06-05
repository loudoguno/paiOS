import Foundation

/// Files issues into loudoguno/pai-upgrade using a fine-grained PAT from the Keychain.
/// Same `URLSession` shape as `LocationWeather`; the token only ever travels to GitHub.
enum GitHubClient {
    static let repo = "loudoguno/pai-upgrade"

    struct CreatedIssue { let number: Int; let url: URL }

    enum GitHubError: LocalizedError {
        case noToken
        case http(Int, String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noToken:            return "No GitHub token saved — add one in Settings."
            case .http(let c, let m): return "GitHub \(c): \(m)"
            case .badResponse:        return "Unexpected response from GitHub."
            }
        }
    }

    /// Create an issue. Tries with `labels`; if GitHub rejects them (422 — e.g. a label
    /// that doesn't exist in the repo), it retries once without labels so the note still files.
    static func createIssue(title: String, body: String, labels: [String] = []) async throws -> CreatedIssue {
        guard let token = KeychainStore.get() else { throw GitHubError.noToken }
        do {
            return try await post(title: title, body: body, labels: labels, token: token)
        } catch GitHubError.http(422, _) where !labels.isEmpty {
            return try await post(title: title, body: body, labels: [], token: token)
        }
    }

    private static func post(title: String, body: String, labels: [String], token: String) async throws -> CreatedIssue {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/issues") else {
            throw GitHubError.badResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = ["title": title, "body": body]
        if !labels.isEmpty { payload["labels"] = labels }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GitHubError.badResponse }

        guard (200...299).contains(http.statusCode) else {
            var msg = "request failed"
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let m = obj["message"] as? String { msg = m }
            throw GitHubError.http(http.statusCode, msg)
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let number = obj["number"] as? Int,
              let urlStr = obj["html_url"] as? String,
              let issueURL = URL(string: urlStr)
        else { throw GitHubError.badResponse }

        return CreatedIssue(number: number, url: issueURL)
    }
}
