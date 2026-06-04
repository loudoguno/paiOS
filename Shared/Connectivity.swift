import Foundation
import WatchConnectivity

/// Anything that can turn a prompt into a reply (the iPhone's on-device model).
protocol PromptResponder: AnyObject {
    func respond(to prompt: String) async -> String
}

/// The watch ↔ iPhone link. The watch asks the phone to generate; the phone answers
/// with the on-device model. Both apps share this; only the phone sets `responder`.
final class Connectivity: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = Connectivity()

    weak var responder: PromptResponder?
    @Published var reachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Watch side: ask the paired iPhone to generate. Returns nil if unreachable or it fails.
    func requestGeneration(_ prompt: String) async -> String? {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            WCSession.default.sendMessage(
                ["prompt": prompt],
                replyHandler: { reply in
                    let answer = reply["answer"] as? String
                    cont.resume(returning: (answer?.isEmpty == false) ? answer : nil)
                },
                errorHandler: { _ in cont.resume(returning: nil) }
            )
        }
    }

    // iPhone side: receive a prompt, generate, reply.
    func session(_ s: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let prompt = message["prompt"] as? String, let responder = responder else {
            replyHandler(["answer": ""]); return
        }
        Task {
            let answer = await responder.respond(to: prompt)
            replyHandler(["answer": answer])
        }
    }

    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.reachable = s.isReachable }
    }
    func sessionReachabilityDidChange(_ s: WCSession) {
        DispatchQueue.main.async { self.reachable = s.isReachable }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ s: WCSession) {}
    func sessionDidDeactivate(_ s: WCSession) { WCSession.default.activate() }
    #endif
}
