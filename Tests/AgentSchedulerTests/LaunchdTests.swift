import Foundation
import Testing
@testable import AgentScheduler

struct LaunchdTests {
    @Test func jobsReadsOurLabelsFromLaunchctlList() {
        let list = """
        PID\tStatus\tLabel
        -\t0\tcom.apple.SafariHistoryServiceAgent
        -\t0\tau.centralsoftware.agent-scheduler.1d986630
        4159\t0\tapplication.au.centralsoftware.agent-scheduler.28598358.28598363
        812\t0\tau.centralsoftware.agent-scheduler.9f3c2a10
        -\t-15\tau.centralsoftware.agent-scheduler.77aa00bb
        """
        #expect(Launchd.jobs(list) == ["1d986630": false, "9f3c2a10": true, "77aa00bb": false])
    }

    @Test func disabledReadsOurLabelsFromPrintDisabled() {
        let output = """
        \tdisabled services = {
        \t\t"com.docker.helper" => enabled
        \t\t"au.centralsoftware.agent-scheduler.1d986630" => disabled
        \t\t"au.centralsoftware.agent-scheduler.9f3c2a10" => enabled
        \t\t"com.apple.ManagedClientAgent.enrollagent" => disabled
        \t}

        """
        #expect(Launchd.disabled(output) == ["1d986630"])
    }

    @Test func plistRunsTheRunnerUnderALabelLaunchctlReportsBack() throws {
        var task = ClaudeTask.draft(folder: "/")
        task.id = "1d986630"
        let plist = try Self.plist(task)
        let label = try #require(plist["Label"] as? String)
        #expect(plist["ProgramArguments"] as? [String] == ["/bin/zsh", "-l", Storage.standard.runner.path, "1d986630"])
        #expect(Launchd.jobs("812\t0\t\(label)") == ["1d986630": true])
        #expect(Launchd.disabled("\t\t\"\(label)\" => disabled") == ["1d986630"])
    }

    @Test func schedules() throws {
        #expect(try interval(.daily, minute: 7 * 60 + 30) as? [String: Int] == ["Hour": 7, "Minute": 30])
        #expect(try interval(.monthly, minute: 0, day: 28) as? [String: Int] == ["Day": 28, "Hour": 0, "Minute": 0])
        #expect(try interval(.weekly, minute: 1425, weekdays: [5, 0, 3]) as? [[String: Int]] == [
            ["Hour": 23, "Minute": 45, "Weekday": 0],
            ["Hour": 23, "Minute": 45, "Weekday": 3],
            ["Hour": 23, "Minute": 45, "Weekday": 5],
        ])
        #expect(try interval(.weekly, minute: 9 * 60, weekdays: []) == nil)
        #expect(try interval(.off, minute: 9 * 60) == nil)
    }

    private func interval(_ repeats: Repeat, minute: Int, weekdays: [Int] = [1, 2, 3, 4, 5], day: Int = 1) throws -> Any? {
        var task = ClaudeTask.draft(folder: "/")
        task.repeats = repeats
        task.minute = minute
        task.weekdays = weekdays
        task.day = day
        return try Self.plist(task)["StartCalendarInterval"]
    }

    private static func plist(_ task: ClaudeTask) throws -> [String: Any] {
        let data = try #require(Launchd.plist(task))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }
}
