import SwiftUI

@main
struct AgentSchedulerApp: App {
    @State private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environment(store)
        } label: {
            Image("MenuIcon")
        }
        .menuBarExtraStyle(.window)

        Window("Agent Scheduler", id: "setup") {
            SetupView().environment(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(store.tasks.isEmpty ? .presented : .suppressed)
        .restorationBehavior(.disabled)
    }
}
