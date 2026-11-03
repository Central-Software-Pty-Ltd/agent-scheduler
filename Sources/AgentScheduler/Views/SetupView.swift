import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

struct SetupView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var notifications = UNAuthorizationStatus.notDetermined
    @State private var login = LoginItem.status

    var body: some View {
        let home = store.home
        VStack(spacing: 0) {
            Header()
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Needed")
                Card {
                    ServiceRow(tile: Tile(image: "MenuIcon"), title: "centralOS", detail: "Gives your agent your contacts, projects, notes and calendar.") {
                        if home?.centralOSConnected == true {
                            Done(title: "Connected")
                        } else {
                            Pill(title: store.centralServers.isEmpty ? "Connect" : "Sign in", busy: home == nil, action: store.connectCentralOS)
                        }
                    }
                    ServiceRow(tile: Tile(symbol: "person.crop.circle"), title: "Claude account", detail: "Your agent runs on Claude Code. Sign in once so it can work while you're away.") {
                        if home?.signedIn == true {
                            Done(title: "Signed in")
                        } else {
                            Pill(title: "Sign in", busy: home == nil) { Shell.openTerminal(Claude.login) }
                        }
                    }
                }
                SectionLabel(title: "Recommended").padding(.top, 12)
                Card {
                    ServiceRow(tile: Tile(symbol: "bell"), title: "Notifications", detail: "A silent banner with the result when a task finishes.") {
                        switch notifications {
                        case .authorized, .provisional, .ephemeral: Done(title: "On")
                        case .denied: Pill(title: "Open Settings") { Notifications.openSettings() }
                        default: Pill(title: "Allow") { Task { await Notifications.request(); await refresh() } }
                        }
                    }
                    ServiceRow(tile: Tile(symbol: "power"), title: "Open at login", detail: "Keep the menu bar icon after a restart. Tasks run either way.") {
                        if login == .requiresApproval {
                            Pill(title: "Approve", action: LoginItem.approve)
                        } else {
                            Toggle("Open at login", isOn: Binding(get: { login == .enabled }, set: { LoginItem.set($0); login = LoginItem.status }))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            VStack(spacing: 12) {
                Button("Get started") { dismissWindow(id: "setup") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(home?.ready != true)
                HStack(spacing: 6) {
                    Image("MenuIcon")
                    Text("You'll find it in the menu bar.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 26)
        }
        .frame(width: 520)
        .background {
            LinearGradient(colors: [Color.primary.opacity(0.06), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45))
                .background(Color(nsColor: .windowBackgroundColor))
                .ignoresSafeArea()
        }
        .task {
            NSApp.activate()
            await refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        store.check(force: true)
        login = LoginItem.status
        notifications = await Notifications.status()
    }
}

struct Header: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                .padding(.bottom, 18)
            Text("Agent Scheduler")
                .font(.system(size: 28, weight: .semibold))
                .padding(.bottom, 8)
            Text("Connect your centralOS account, then give your agent jobs to do on this Mac. Each one runs on its schedule in the background, even when this app is closed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 390)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}
