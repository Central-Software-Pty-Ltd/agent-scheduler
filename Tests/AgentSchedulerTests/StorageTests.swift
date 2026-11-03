import Foundation
import Testing
@testable import AgentScheduler

final class StorageTests {
    let sandbox = Sandbox()
    var storage: Storage { sandbox.storage }

    init() {
        storage.prepare()
    }

    @Test func savedTasksLoadBackSortedByName() {
        var weekly = ClaudeTask.draft(folder: "/Users/someone/Client's Work")
        weekly.name = "Task 10"
        weekly.instructions = "Send the \"weekly\" summary — café ☕️"
        weekly.repeats = .weekly
        weekly.weekdays = [6, 0]
        weekly.minute = 1425
        var monthly = ClaudeTask.draft(folder: "/")
        monthly.name = "task 2"
        monthly.repeats = .monthly
        monthly.day = 28
        var daily = ClaudeTask.draft(folder: "/")
        daily.name = "Alpha"
        daily.repeats = .daily
        for task in [weekly, monthly, daily] { storage.write(task) }
        #expect(storage.loadTasks() == [daily, monthly, weekly])
    }

    @Test func loadsTasksSavedBy100AndSkipsOtherFiles() throws {
        try write("tasks/1d986630.json", """
        {
          "day" : 1,
          "folder" : "\\/Users\\/someone\\/central",
          "id" : "1d986630",
          "instructions" : "Update the changelog",
          "minute" : 960,
          "name" : "Changelog tracking",
          "repeats" : "daily",
          "weekdays" : [
            5,
            1,
            2
          ]
        }
        """)
        try write("tasks/broken.json", "{")
        try write("tasks/notes.txt", "notes")
        #expect(storage.loadTasks() == [
            ClaudeTask(id: "1d986630", name: "Changelog tracking", instructions: "Update the changelog", folder: "/Users/someone/central", repeats: .daily, minute: 960, weekdays: [5, 1, 2], day: 1),
        ])
    }

    @Test func lastRunIsNilBeforeTheFirstRun() {
        #expect(storage.lastRun("1d986630", reusing: nil) == nil)
    }

    @Test func lastRunFollowsTheNewestRunFromStartToFinish() throws {
        try write("runs/1d986630/2026-11-03T09-58-27.json", #"{"result":"Old","session_id":"old"}"#)
        try write("runs/1d986630/2026-11-03T09-58-27.exit", "0\n")
        try write("runs/1d986630/2026-11-03T10-08-07.json", "")
        let started = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 10, minute: 8, second: 7)))

        let running = try #require(storage.lastRun("1d986630", reusing: nil))
        #expect(running == TaskRun(stamp: "2026-11-03T10-08-07", started: started, exitCode: nil, sessionID: nil, result: nil))
        #expect(!running.succeeded)

        try write("runs/1d986630/2026-11-03T10-08-07.json", #"{"type":"result","subtype":"success","is_error":false,"result":"Changelog updated","session_id":"8c1f2d3e","num_turns":4}"#)
        try write("runs/1d986630/2026-11-03T10-08-07.exit", "0\n")
        let finished = try #require(storage.lastRun("1d986630", reusing: running))
        #expect(finished == TaskRun(stamp: "2026-11-03T10-08-07", started: started, exitCode: 0, sessionID: "8c1f2d3e", result: "Changelog updated"))
        #expect(finished.succeeded)
    }

    private func write(_ path: String, _ text: String) throws {
        let file = storage.root.appending(path: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }
}
