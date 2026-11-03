import Foundation

enum Storage {
    static let root = URL.applicationSupportDirectory.appending(path: "AgentScheduler", directoryHint: .isDirectory)
    static let tasks = root.appending(path: "tasks", directoryHint: .isDirectory)
    static let runs = root.appending(path: "runs", directoryHint: .isDirectory)
    static let runner = root.appending(path: "run.sh")
    static let log = root.appending(path: "launchd.log")

    static func prepare() {
        for dir in [tasks, runs] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try? runnerScript.write(to: runner, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runner.path)
    }

    static func loadTasks() -> [ClaudeTask] {
        ((try? FileManager.default.contentsOfDirectory(at: tasks, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(ClaudeTask.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func write(_ task: ClaudeTask) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(task).write(to: tasks.appending(path: "\(task.id).json"), options: .atomic)
    }

    static func trash(_ id: String) {
        for url in [tasks.appending(path: "\(id).json"), runs.appending(path: id)] {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    static func errorLog(_ id: String, _ run: TaskRun) -> URL {
        runs.appending(path: "\(id)/\(run.stamp).err")
    }

    static func lastRun(_ id: String, reusing previous: TaskRun?) -> TaskRun? {
        let dir = runs.appending(path: id, directoryHint: .isDirectory)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        guard let stamp = names.filter({ $0.hasSuffix(".json") }).map({ String($0.dropLast(5)) }).max() else { return nil }
        if let previous, previous.stamp == stamp, previous.exitCode != nil { return previous }
        let exitText = try? String(contentsOf: dir.appending(path: "\(stamp).exit"), encoding: .utf8)
        let exitCode = exitText.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let output = exitCode == nil ? nil : (try? JSONSerialization.jsonObject(with: Data(contentsOf: dir.appending(path: "\(stamp).json")))) as? [String: Any]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        return TaskRun(
            stamp: stamp,
            started: formatter.date(from: stamp) ?? .distantPast,
            exitCode: exitCode,
            sessionID: output?["session_id"] as? String,
            result: output?["result"] as? String
        )
    }

    private static let runnerScript = """
    #!/bin/zsh -l
    source ~/.zshrc >/dev/null 2>&1
    root=${0:A:h}
    task=$root/tasks/$1.json
    field() { plutil -extract $1 raw -o - $task 2>/dev/null }
    instructions=$(field instructions)
    [[ -z $instructions ]] && exit 0
    runs=$root/runs/$1
    mkdir -p $runs
    out=$runs/$(date +%Y-%m-%dT%H-%M-%S)
    : > $out.json
    cd "$(field folder)" 2> $out.err || { print 1 > $out.exit; exit 1 }
    print -r -- $instructions | claude -p --permission-mode auto --output-format json > $out.json 2>> $out.err
    code=$?
    print $code > $out.exit
    exit $code

    """
}
