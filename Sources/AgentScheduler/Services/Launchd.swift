import Foundation

enum Launchd {
    static let prefix = "au.centralsoftware.agent-scheduler."
    private static let launchctl = "/bin/launchctl"
    private static var domain: String { "gui/\(getuid())" }

    static func jobs() -> [String: Bool] {
        var jobs: [String: Bool] = [:]
        for line in Shell.run(launchctl, ["list"]).output.split(separator: "\n") {
            let columns = line.split(separator: "\t")
            guard columns.count == 3, columns[2].hasPrefix(prefix) else { continue }
            jobs[String(columns[2].dropFirst(prefix.count))] = columns[0] != "-"
        }
        return jobs
    }

    static func disabled() -> Set<String> {
        Set(Shell.run(launchctl, ["print-disabled", domain]).output.split(separator: "\n")
            .filter { $0.hasSuffix("=> disabled") }
            .compactMap { $0.split(separator: "\"").dropFirst().first }
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) })
    }

    static func sync(_ task: ClaudeTask, running: Bool?) {
        guard running != true, let data = plist(task) else { return }
        let url = plistURL(task.id)
        if running != nil, (try? Data(contentsOf: url)) == data { return }
        Shell.run(launchctl, ["bootout", target(task.id)])
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        for _ in 0..<10 {
            if Shell.run(launchctl, ["bootstrap", domain, url.path]).status == 0 { return }
            usleep(100_000)
        }
    }

    static func start(_ id: String) {
        Shell.run(launchctl, ["kickstart", target(id)])
    }

    static func setDisabled(_ disabled: Bool, _ ids: [String]) {
        for id in ids {
            Shell.run(launchctl, [disabled ? "disable" : "enable", target(id)])
            if disabled { Shell.run(launchctl, ["bootout", target(id)]) }
        }
    }

    static func remove(_ id: String) {
        Shell.run(launchctl, ["bootout", target(id)])
        Shell.run(launchctl, ["enable", target(id)])
        try? FileManager.default.removeItem(at: plistURL(id))
    }

    private static func target(_ id: String) -> String { "\(domain)/\(prefix)\(id)" }

    private static func plistURL(_ id: String) -> URL {
        URL.homeDirectory.appending(path: "Library/LaunchAgents/\(prefix)\(id).plist")
    }

    private static func plist(_ task: ClaudeTask) -> Data? {
        var plist: [String: Any] = [
            "Label": prefix + task.id,
            "ProgramArguments": ["/bin/zsh", "-l", Storage.runner.path, task.id],
            "StandardOutPath": Storage.log.path,
            "StandardErrorPath": Storage.log.path,
        ]
        let time = ["Hour": task.minute / 60, "Minute": task.minute % 60]
        switch task.repeats {
        case .daily: plist["StartCalendarInterval"] = time
        case .weekly where !task.weekdays.isEmpty: plist["StartCalendarInterval"] = task.weekdays.sorted().map { time.merging(["Weekday": $0]) { $1 } }
        case .monthly: plist["StartCalendarInterval"] = time.merging(["Day": task.day]) { $1 }
        case .off, .weekly: break
        }
        return try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }
}
