import Foundation
import Testing
@testable import AgentScheduler

final class RunnerTests {
    let sandbox = Sandbox()
    var storage: Storage { sandbox.storage }
    var calls: URL { sandbox.url.appending(path: "calls", directoryHint: .isDirectory) }
    var claudeRan: Bool { FileManager.default.fileExists(atPath: calls.appending(path: "args").path) }

    init() throws {
        storage.prepare()
        try FileManager.default.createDirectory(at: calls, withIntermediateDirectories: true)
        let claude = try sandbox.folder("bin").appending(path: "claude")
        try """
        #!/bin/sh
        printf '%s\\n' "$@" > "$CALLS/args"
        pwd > "$CALLS/pwd"
        cat > "$CALLS/stdin"
        echo "claude warning" >&2
        printf '{"type":"result","is_error":false,"result":"Done","session_id":"5f0c2e1a"}'
        exit "$CLAUDE_EXIT"
        """.write(to: claude, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: claude.path)
    }

    @Test(arguments: [0, 2] as [Int32])
    func runsClaudeInTheTaskFolderAndRecordsTheRun(_ code: Int32) throws {
        let folder = try sandbox.folder("Client's Work/Q4 plans")
        var task = ClaudeTask.draft(folder: folder.path)
        task.instructions = "- Email \"Sam\" about $HOME and `the invoice` — 50% off\n\t\\n stays literal ☕️"
        storage.write(task)

        #expect(try launch(task.id, claudeExit: code) == code)
        #expect(try read("args") == "-p\n--permission-mode\nauto\n--output-format\njson\n")
        #expect(try read("stdin") == task.instructions + "\n")
        #expect(URL(filePath: try read("pwd").trimmingCharacters(in: .newlines)).resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)

        let run = try #require(storage.lastRun(task.id, reusing: nil))
        #expect(run.exitCode == Int(code))
        #expect(run.succeeded == (code == 0))
        #expect(run.sessionID == "5f0c2e1a")
        #expect(run.result == "Done")
        #expect(abs(run.started.timeIntervalSinceNow) < 60)
        #expect(try String(contentsOf: storage.errorLog(task.id, run), encoding: .utf8) == "claude warning\n")
    }

    @Test func stopsWhenTheTaskFolderIsGone() throws {
        var task = ClaudeTask.draft(folder: sandbox.url.appending(path: "Deleted folder").path)
        task.instructions = "Tidy up"
        storage.write(task)

        #expect(try launch(task.id) == 1)
        #expect(!claudeRan)
        let run = try #require(storage.lastRun(task.id, reusing: nil))
        #expect(run.exitCode == 1)
        #expect(run.sessionID == nil)
        #expect(try !String(contentsOf: storage.errorLog(task.id, run), encoding: .utf8).isEmpty)
    }

    @Test(arguments: ["", " \n\t "])
    func skipsTasksWithNothingToRun(_ instructions: String) throws {
        var task = ClaudeTask.draft(folder: sandbox.url.path)
        task.instructions = instructions
        storage.write(task)
        #expect(task.isEmpty)

        #expect(try launch(task.id) == 0)
        #expect(try launch("0deleted") == 0)
        #expect(!claudeRan)
        #expect(storage.lastRun(task.id, reusing: nil) == nil)
        #expect(storage.lastRun("0deleted", reusing: nil) == nil)
    }

    private func launch(_ id: String, claudeExit: Int32 = 0) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = [storage.runner.path, id]
        process.environment = [
            "HOME": sandbox.url.path,
            "PATH": "\(sandbox.url.path)/bin:/usr/bin:/bin",
            "CALLS": calls.path,
            "CLAUDE_EXIT": "\(claudeExit)",
        ]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private func read(_ name: String) throws -> String {
        try String(contentsOf: calls.appending(path: name), encoding: .utf8)
    }
}
