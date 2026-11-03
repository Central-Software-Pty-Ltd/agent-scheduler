import Foundation
import Testing
@testable import AgentScheduler

struct ScheduleTests {
    @Test(arguments: [(1, "1st"), (2, "2nd"), (3, "3rd"), (4, "4th"), (11, "11th"), (12, "12th"), (13, "13th"), (21, "21st"), (22, "22nd"), (23, "23rd"), (28, "28th")])
    func ordinals(_ number: Int, _ expected: String) {
        #expect(ordinal(number) == expected)
    }

    @Test func summaries() {
        let days = Calendar.current.shortWeekdaySymbols
        #expect(summary(.off, weekdays: [1, 2]) == "Off")
        #expect(summary(.daily, minute: 0) == "Daily 00:00")
        #expect(summary(.monthly, minute: 1425, day: 22) == "Monthly 22nd 23:45")
        #expect(summary(.weekly, weekdays: []) == "Off")
        #expect(summary(.weekly, weekdays: [6, 0, 1, 2, 3, 4, 5]) == "Daily 09:00")
        #expect(summary(.weekly, weekdays: [5, 4, 3, 2, 1]) == "Weekdays 09:00")
        #expect(summary(.weekly, weekdays: [6, 0]) == "Weekends 09:00")
        #expect(summary(.weekly, minute: 7 * 60 + 5, weekdays: [0, 3, 1]) == "\(days[1]) \(days[3]) \(days[0]) 07:05")
    }

    private func summary(_ repeats: Repeat, minute: Int = 9 * 60, weekdays: [Int] = [1, 2, 3, 4, 5], day: Int = 1) -> String {
        var task = ClaudeTask.draft(folder: "/")
        task.repeats = repeats
        task.minute = minute
        task.weekdays = weekdays
        task.day = day
        return task.summary
    }
}

struct MCPServerTests {
    static let list = """
    Checking MCP server health…

    claude.ai Claude Docs: https://api.anthropic.com/v1/pages/mcp - ✔ Connected
    plugin:stripe:stripe: https://mcp.stripe.com (HTTP) - ! Needs authentication
    centralos-dev: https://dev.centralos.au/api/mcp (HTTP) - ✔ Connected
    centralos-prod: https://centralos.au/api/mcp (HTTP) - ✔ Connected
    claude.ai centralOS: https://centralos.au/api/mcp - ✔ Connected
    centralos: https://centralos.au/api/mcp (HTTP) - ! Connected · tools fetch failed — MCP error -32603: Internal error
    centralOS_staging: https://staging.centralos.au/api/mcp (SSE) - ✘ Failed to connect — SSE error: Non-200 status code (401): authentication required
    files: npx -y files-server --label a - b - ✔ Connected
    lookalike: https://notcentralos.au/api/mcp (HTTP) - ✔ Connected
    legacy: https://legacy.example.com/mcp (HTTP) - - Not configured
    team: https://team.example.com/mcp (HTTP) - ⏸ Pending approval (run `claude` to approve)
    old: https://old.example.com/mcp (HTTP) - ⊘ Disabled for this project (re-enable via /mcp)
    """

    @Test func parsesEveryStatusClaudeMcpListPrints() {
        #expect(MCPServer.parse(Self.list) == [
            MCPServer(id: "claude.ai Claude Docs", status: .connected, host: "api.anthropic.com"),
            MCPServer(id: "plugin:stripe:stripe", status: .needsSignIn, host: "mcp.stripe.com"),
            MCPServer(id: "centralos-dev", status: .connected, host: "dev.centralos.au"),
            MCPServer(id: "centralos-prod", status: .connected, host: "centralos.au"),
            MCPServer(id: "claude.ai centralOS", status: .connected, host: "centralos.au"),
            MCPServer(id: "centralos", status: .failing, host: "centralos.au"),
            MCPServer(id: "centralOS_staging", status: .failing, host: "staging.centralos.au"),
            MCPServer(id: "files", status: .connected),
            MCPServer(id: "lookalike", status: .connected, host: "notcentralos.au"),
            MCPServer(id: "legacy", status: .failing, host: "legacy.example.com"),
            MCPServer(id: "team", status: .failing, host: "team.example.com"),
            MCPServer(id: "old", status: .off, host: "old.example.com"),
        ])
    }

    @Test(arguments: [
        ("centralos", nil, "centralOS"),
        ("centralos-dev", "dev.centralos.au", "centralOS dev"),
        ("centralOS_staging", nil, "centralOS staging"),
        ("plugin:central:centralos-prod", nil, "centralOS prod"),
        ("claude.ai centralOS", "centralos.au", "claude.ai centralOS"),
        ("plugin:stripe:stripe", "mcp.stripe.com", "stripe"),
    ] as [(String, String?, String)])
    func titles(_ id: String, _ host: String?, _ title: String) {
        #expect(MCPServer(id: id, status: .connected, host: host).title == title)
    }
}

struct HealthTests {
    static let signedIn = """
    {
      "loggedIn": true,
      "authMethod": "claude.ai",
      "apiProvider": "firstParty",
      "analyticsDisabled": false,
      "email": "someone@example.com"
    }
    """

    @Test func readsClaudeAuthAndServers() {
        let health = Health.parse(auth: Self.signedIn, servers: MCPServerTests.list)
        #expect(health.signedIn)
        #expect(health.centralOS.map(\.id) == ["centralos-dev", "centralos-prod", "claude.ai centralOS", "centralos", "centralOS_staging"])
        #expect(health.ready)
        #expect(health.needsSignIn == ["stripe"])
        #expect(health.failing == ["centralos", "centralOS_staging", "legacy", "team"])
    }

    @Test func readyNeedsClaudeAndAConnectedCentralOS() {
        #expect(!Health.parse(auth: #"{"loggedIn": false, "authMethod": "none"}"#, servers: MCPServerTests.list).ready)
        #expect(!Health.parse(auth: Self.signedIn, servers: "centralos: https://centralos.au/api/mcp (HTTP) - ! Needs authentication").ready)
        #expect(!Health.parse(auth: Self.signedIn, servers: "claude.ai Claude Docs: https://api.anthropic.com/v1/pages/mcp - ✔ Connected").ready)
        #expect(Health.parse(auth: Self.signedIn, servers: "claude.ai centralOS: https://centralos.au/api/mcp - ✔ Connected").ready)
    }

    @Test func missingClaudeReadsAsSignedOut() {
        let missing = "zsh:1: command not found: claude\n"
        let health = Health.parse(auth: missing, servers: missing)
        #expect(!health.signedIn)
        #expect(health.servers.isEmpty)
    }
}
