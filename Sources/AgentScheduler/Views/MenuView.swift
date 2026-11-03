import AppKit
import SwiftUI

struct MenuView: View {
    @Environment(Store.self) private var store
    @State private var open: ClaudeTask?
    @State private var height: CGFloat = 0

    var body: some View {
        Group {
            if let task = open {
                TaskView(task: task) { open = nil }
                    .id(task.id)
                    .frame(height: 480)
            } else {
                TaskList { open = $0 }
            }
        }
        .frame(width: 300)
        .padding(6)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .background(WindowFitter(height: height))
    }
}

struct TaskList: View {
    @Environment(Store.self) private var store
    @Environment(\.openWindow) private var openWindow
    let onOpen: (ClaudeTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusLine(openSetup: openSetup)
            Separator()
            ForEach(store.tasks) { task in
                Row(action: { onOpen(task) }) { _ in
                    Text(task.name).lineLimit(1)
                    Spacer(minLength: 12)
                    if store.running.contains(task.id) {
                        Hint(text: "Running")
                    } else {
                        if store.runs[task.id]?.succeeded == false {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(.tertiary)
                        }
                        Hint(text: task.summary)
                    }
                }
                .contextMenu {
                    Button("Move to Bin") { store.delete(task) }
                    Button("Run Now") { store.runNow(task) }
                }
            }
            Row(icon: "plus", shortcut: "n", action: { onOpen(.draft(folder: store.tasks.first?.folder ?? NSHomeDirectory())) }) { _ in
                Text("New task")
                Spacer()
                Hint(text: "⌘N")
            }
            Separator()
            ServerList()
            Separator()
            Row(icon: "gearshape", shortcut: ",", action: openSetup) { _ in
                Text("Services…")
                Spacer()
                Hint(text: "⌘,")
            }
            Row(icon: store.paused ? "play.fill" : "pause.fill", action: { store.setPaused(!store.paused) }) { _ in
                Text(store.paused ? "Resume" : "Pause")
                Spacer()
            }
            Row(icon: "power", shortcut: "q", action: { NSApp.terminate(nil) }) { _ in
                Text("Quit Agent Scheduler")
                Spacer()
                Hint(text: "⌘Q")
            }
        }
        .onAppear { store.check() }
    }

    private func openSetup() {
        NSApp.activate()
        openWindow(id: "setup")
    }
}

struct StatusLine: View {
    @Environment(Store.self) private var store
    let openSetup: () -> Void

    var body: some View {
        if let home = store.home, !home.signedIn {
            Row(action: openSetup) { _ in
                StatusDot(on: false)
                Text("Sign in to Claude to run tasks").lineLimit(1)
                Spacer()
            }
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 8) {
                StatusDot(on: !store.paused)
                Text(text).lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }

    private var text: String {
        if store.paused { return "Agent Scheduler is paused" }
        let running = store.tasks.filter { store.running.contains($0.id) }.map(\.name)
        return running.isEmpty ? "Agent Scheduler is on" : "Running \(running.joined(separator: ", "))"
    }
}

struct ServerList: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.centralServers.isEmpty {
            Row(action: store.connectCentralOS) { _ in
                StatusDot(on: false, size: 7)
                Text("centralOS")
                Spacer()
                Hint(text: store.home == nil ? "Checking…" : "Connect")
            }
        }
        ForEach(store.centralServers) { server in
            Row(action: { action(server) }) { hovering in
                StatusDot(on: server.status == .connected, size: 7)
                Text(server.name).lineLimit(1)
                Spacer()
                Hint(text: hint(server, hovering: hovering))
            }
        }
    }

    private func action(_ server: MCPServer) {
        if server.status == .needsSignIn { Shell.openTerminal(Claude.mcp) } else { store.readd(server) }
    }

    private func hint(_ server: MCPServer, hovering: Bool) -> String {
        if server.status == .needsSignIn { return "Sign in" }
        if hovering { return "Re-add" }
        switch server.status {
        case .connected: return "Connected"
        case .failing: return "Not connecting"
        case .off, .needsSignIn: return "Off"
        }
    }
}
