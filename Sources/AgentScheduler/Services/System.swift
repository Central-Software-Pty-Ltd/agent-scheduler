import AppKit
import ServiceManagement
import UserNotifications

enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func set(_ on: Bool) {
        if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        if status == .requiresApproval { approve() }
    }

    static func approve() { SMAppService.openSystemSettingsLoginItems() }
}

enum Notifications {
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=au.centralsoftware.agent-scheduler") else { return }
        NSWorkspace.shared.open(url)
    }

    static func post(_ task: ClaudeTask, _ run: TaskRun) {
        let content = UNMutableNotificationContent()
        content.title = task.name
        content.body = run.succeeded ? String((run.result ?? "Finished").prefix(180)) : "Didn't finish"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "\(task.id)/\(run.stamp)", content: content, trigger: nil))
    }
}
