import AppKit

enum Shell {
    @discardableResult
    static func run(_ path: String, _ arguments: [String], in folder: String? = nil) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = arguments
        if let folder { process.currentDirectoryURL = URL(filePath: folder) }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    @discardableResult
    static func zsh(_ command: String, in folder: String = NSHomeDirectory()) -> String {
        run("/bin/zsh", ["-l", "-c", "source ~/.zshrc >/dev/null 2>&1; \(command)"], in: folder).output
    }

    static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @MainActor
    static func openTerminal(_ command: String, in folder: String = NSHomeDirectory()) {
        let script = "#!/bin/zsh -l\nsource ~/.zshrc >/dev/null 2>&1\ncd \(quote(folder))\n\(command)\n"
        let url = FileManager.default.temporaryDirectory.appending(path: "agent-scheduler-\(UUID().uuidString.prefix(8)).command")
        try? script.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        NSWorkspace.shared.open(url)
    }
}
