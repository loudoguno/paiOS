import SwiftUI

@main
struct PaiOSApp: App {
    init() {
        // Activate the watch link and wire the on-device model as the responder.
        Connectivity.shared.responder = Intelligence.shared
        Connectivity.shared.activate()
        Intelligence.shared.prewarm()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
