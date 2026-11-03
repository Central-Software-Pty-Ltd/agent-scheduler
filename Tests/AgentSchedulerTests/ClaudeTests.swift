import Testing
@testable import AgentScheduler

struct ReaddTests {
    @Test(arguments: [
        ("User config (available in all your projects)", "http", "user"),
        ("Local config (private to you in this project)", "sse", "local"),
        ("Project config (shared via .mcp.json)", "http", "project"),
    ])
    func readdsAtTheSameScopeAndTransport(_ scope: String, _ type: String, _ flag: String) {
        let details = """
        centralos-dev:
          Scope: \(scope)
          Status: ✘ Failed to connect
          Issue: HTTP 502 - Bad Gateway
          Type: \(type)
          URL: https://dev.centralos.au/api/mcp

        To remove this server, run: claude mcp remove centralos-dev -s \(flag)
        """
        #expect(Claude.readdCommands("centralos-dev", details: details) == [
            "claude mcp remove 'centralos-dev' -s \(flag)",
            "claude mcp add --transport \(type) -s \(flag) 'centralos-dev' 'https://dev.centralos.au/api/mcp'",
        ])
    }

    @Test(arguments: [
        """
        centralos:
          Scope: User config (available in all your projects)
          Status: ✔ Connected
          Type: http
          URL: https://centralos.au/api/mcp
          Headers:
            Authorization: Bearer abc
        """,
        """
        centralos:
          Scope: User config (available in all your projects)
          Status: ! Needs authentication
          Type: http
          URL: https://centralos.au/api/mcp
          OAuth: client_id configured, callback_port 8080
        """,
        """
        claude.ai centralOS:
          Scope: claude.ai config
          Status: ✔ Connected
        """,
        """
        centralos:
          Scope: User config (available in all your projects)
          Status: ✔ Connected
          Type: stdio
          Command: npx
          Args: -y centralos-mcp
        """,
        """
        No MCP server named "centralos". Configured servers: centralos-dev
        """,
    ])
    func leavesServersItCannotRecreateExactly(_ details: String) {
        #expect(Claude.readdCommands("centralos", details: details).isEmpty)
    }
}
