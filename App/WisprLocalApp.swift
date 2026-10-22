import SwiftUI

@main
struct WisprLocalApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
    }
}
