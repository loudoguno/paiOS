import SwiftUI

@main
struct PaiOSWatchApp: App {
    init() { Connectivity.shared.activate() }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
