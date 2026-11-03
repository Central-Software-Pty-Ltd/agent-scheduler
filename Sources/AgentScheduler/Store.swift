import AppKit
import Observation

@MainActor
@Observable
final class Store {
    private(set) var tasks: [ClaudeTask] = []
    private(set) var runs: [String: TaskRun] = [:]
    private(set) var running: Set<String> = []
    private(set) var paused = false
    private(set) var health: [String: Health] = [:]
    private(set) var checking: Set<String> = []

    var home: Health? { health[NSHomeDirectory()] }
    var centralServers: [MCPServer] { home?.centralOS ?? [] }

    init() {
        Storage.standard.prepare()
        refresh(notify: false)
        Task {
            while true {
                try? await Task.sleep(for: .seconds(3))
                refresh()
            }
        }
    }

    func refresh(notify: Bool = true) {
        let loaded = Storage.standard.loadTasks()
        let jobs = Launchd.jobs()
        let isPaused = !Launchd.disabled().isDisjoint(with: loaded.map(\.id))
        var latest: [String: TaskRun] = [:]
        for task in loaded {
            if !isPaused { Launchd.sync(task, running: jobs[task.id]) }
            guard let run = Storage.standard.lastRun(task.id, reusing: runs[task.id]) else { continue }
            if notify, run.exitCode != nil, run != runs[task.id] { Notifications.post(task, run) }
            latest[task.id] = run
        }
        let nowRunning = Set(jobs.filter(\.value).keys)
        if loaded != tasks { tasks = loaded }
        if latest != runs { runs = latest }
        if nowRunning != running { running = nowRunning }
        if isPaused != paused { paused = isPaused }
    }

    func save(_ task: ClaudeTask) {
        Storage.standard.write(task)
        refresh()
    }

    func delete(_ task: ClaudeTask) {
        Launchd.remove(task.id)
        Storage.standard.trash(task.id)
        refresh()
    }

    func runNow(_ task: ClaudeTask) {
        save(task)
        Launchd.start(task.id)
        refresh()
    }

    func setPaused(_ value: Bool) {
        Launchd.setDisabled(value, tasks.map(\.id))
        refresh()
    }

    func openRun(_ task: ClaudeTask) {
        guard let run = runs[task.id] else { return }
        if let session = run.sessionID {
            Shell.openTerminal(Claude.resume(session), in: task.folder)
        } else {
            NSWorkspace.shared.open(Storage.standard.errorLog(task.id, run))
        }
    }

    func check(_ folder: String = NSHomeDirectory(), force: Bool = false) {
        guard force || (health[folder]?.checkedAt.timeIntervalSinceNow ?? -.infinity) < -30 else { return }
        recheck(folder)
    }

    func readd(_ server: MCPServer) {
        recheck { Claude.readd(server.id) }
    }

    func connectCentralOS() {
        guard centralServers.isEmpty else { return Shell.openTerminal(Claude.mcp) }
        recheck(after: Claude.addCentralOS) { Shell.openTerminal(Claude.mcp) }
    }

    private func recheck(
        _ folder: String = NSHomeDirectory(),
        after work: @escaping @Sendable () -> Void = {},
        then done: @escaping @MainActor () -> Void = {}
    ) {
        guard checking.insert(folder).inserted else { return }
        Task.detached {
            work()
            let result = Claude.health(in: folder)
            await MainActor.run {
                self.health[folder] = result
                self.checking.remove(folder)
                done()
            }
        }
    }
}
