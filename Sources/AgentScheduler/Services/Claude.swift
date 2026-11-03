import Foundation

enum Claude {
    static let login = "claude auth login"
    static let mcp = "claude /mcp"

    static func resume(_ session: String) -> String { "exec claude --resume \(session)" }

    static func health(in folder: String) -> Health {
        let auth = (try? JSONSerialization.jsonObject(with: Data(Shell.zsh("claude auth status --json", in: folder).utf8))) as? [String: Any]
        return Health(
            signedIn: auth?["loggedIn"] as? Bool ?? false,
            servers: MCPServer.parse(Shell.zsh("claude mcp list", in: folder))
        )
    }

    static func readd(_ name: String) {
        let details = Shell.zsh("claude mcp get \(Shell.quote(name))").split(separator: "\n")
        let field = { (key: String) in
            details.first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }
                .map { $0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }
        }
        guard let type = field("Type"), ["http", "sse"].contains(type), let url = field("URL"), field("Headers") == nil else { return }
        let scope = field("Scope")?.split(separator: " ").first?.lowercased() ?? "user"
        Shell.zsh("claude mcp remove \(Shell.quote(name)) -s \(scope)")
        Shell.zsh("claude mcp add --transport \(type) -s \(scope) \(Shell.quote(name)) \(Shell.quote(url))")
    }

    static func addCentralOS() {
        Shell.zsh("claude mcp add --transport http -s user centralos https://centralos.au/api/mcp")
    }
}
