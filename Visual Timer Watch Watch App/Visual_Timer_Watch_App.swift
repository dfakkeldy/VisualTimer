import SwiftUI

@main
struct Visual_Timer_Watch_App: App {

    /// App-level owner of timers and alerts, created at launch so the
    /// notification delegate is in place before any timer runs.
    @StateObject private var model = WatchAppModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView(model: model)
        }
    }
}
