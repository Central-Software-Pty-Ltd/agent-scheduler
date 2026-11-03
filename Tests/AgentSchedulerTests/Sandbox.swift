import Foundation
@testable import AgentScheduler

final class Sandbox {
    let url = FileManager.default.temporaryDirectory.appending(path: "AgentSchedulerTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    var storage: Storage {
        Storage(root: url.appending(path: "Library/Application Support/AgentScheduler", directoryHint: .isDirectory))
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func folder(_ path: String) throws -> URL {
        let folder = url.appending(path: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
