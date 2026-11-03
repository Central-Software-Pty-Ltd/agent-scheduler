import Foundation

enum Claude {
    static let login = "claude auth login"
    static let mcp = "claude /mcp"

    static func resume(_ session: String) -> String { "exec claude --resume \(session)" }

    static func health(in folder: String) -> Health {
        .parse(auth: Shell.zsh("claude auth status --json", in: folder), servers: Shell.zsh("claude mcp list", in: folder))
    }

    static func readd(_ name: String) {
        for command in readdCommands(name, details: Shell.zsh("claude mcp get \(Shell.quote(name))")) {
            Shell.zsh(command)
        }
    }

    static func readdCommands(_ name: String, details: String) -> [String] {
        let lines = details.split(separator: "\n")
        let field = { (key: String) in
            lines.first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }
                .map { $0.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)[1].trimmingCharacters(in: .whitespaces) }
        }
        guard let type = field("Type"), ["http", "sse"].contains(type), let url = field("URL"), field("Headers") == nil, field("OAuth") == nil else { return [] }
        let scope = field("Scope")?.split(separator: " ").first?.lowercased() ?? "user"
        return [
            "claude mcp remove \(Shell.quote(name)) -s \(scope)",
            "claude mcp add --transport \(type) -s \(scope) \(Shell.quote(name)) \(Shell.quote(url))",
        ]
    }

    static func addCentralOS() {
        Shell.zsh("claude mcp add --transport http -s user centralos https://centralos.au/api/mcp")
    }
}
