import Foundation

enum Repeat: String, Codable, CaseIterable {
    case off, daily, weekly, monthly

    var label: String { rawValue.capitalized }
}

struct ClaudeTask: Codable, Identifiable, Equatable {
    static let weekdayOrder = [1, 2, 3, 4, 5, 6, 0]

    var id: String
    var name: String
    var instructions: String
    var folder: String
    var repeats: Repeat
    var minute: Int
    var weekdays: [Int]
    var day: Int

    static func draft(folder: String) -> ClaudeTask {
        ClaudeTask(
            id: String(UUID().uuidString.prefix(8)).lowercased(),
            name: "New task",
            instructions: "",
            folder: folder,
            repeats: .off,
            minute: 9 * 60,
            weekdays: [1, 2, 3, 4, 5],
            day: 1
        )
    }

    var isEmpty: Bool { instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var time: String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    var summary: String {
        let days = Set(weekdays)
        switch repeats {
        case .off: return "Off"
        case .daily: return "Daily \(time)"
        case .monthly: return "Monthly \(ordinal(day)) \(time)"
        case .weekly where days.isEmpty: return "Off"
        case .weekly where days.count == 7: return "Daily \(time)"
        case .weekly where days == [1, 2, 3, 4, 5]: return "Weekdays \(time)"
        case .weekly where days == [0, 6]: return "Weekends \(time)"
        case .weekly:
            let names = Self.weekdayOrder.filter(days.contains).map { Calendar.current.shortWeekdaySymbols[$0] }
            return "\(names.joined(separator: " ")) \(time)"
        }
    }
}

func ordinal(_ number: Int) -> String {
    let suffixes = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"]
    return "\(number)\((11...13).contains(number % 100) ? "th" : suffixes[number % 10])"
}

struct TaskRun: Equatable {
    var stamp: String
    var started: Date
    var exitCode: Int?
    var sessionID: String?
    var result: String?

    var succeeded: Bool { exitCode == 0 }
}

struct MCPServer: Equatable, Identifiable {
    enum Status { case connected, needsSignIn, failing, off }

    var id: String
    var status: Status
    var host: String?

    var name: String { String(id.split(separator: ":").last ?? "") }
    var isCentralOS: Bool { name.lowercased().hasPrefix("centralos") || host.map { $0 == "centralos.au" || $0.hasSuffix(".centralos.au") } == true }

    var title: String {
        guard name.lowercased().hasPrefix("centralos") else { return name }
        let suffix = name.dropFirst("centralos".count).trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
        return suffix.isEmpty ? "centralOS" : "centralOS \(suffix)"
    }

    static func parse(_ list: String) -> [MCPServer] {
        list.split(separator: "\n").compactMap { line in
            let entry = line.components(separatedBy: " — ")[0]
            guard let colon = entry.range(of: ": "), let dash = entry.range(of: " - ", options: .backwards) else { return nil }
            let text = entry[dash.upperBound...]
            let status: Status = text.hasSuffix(" Connected") ? .connected
                : text.contains("Needs authentication") ? .needsSignIn
                : text.contains("Disabled") ? .off
                : .failing
            let target = entry[colon.upperBound...].split(separator: " ").first.flatMap { URL(string: String($0)) }
            return MCPServer(id: String(entry[..<colon.lowerBound]), status: status, host: target?.host()?.lowercased())
        }
    }
}

struct Health: Equatable {
    var signedIn = false
    var servers: [MCPServer] = []
    var checkedAt = Date.now

    static func parse(auth: String, servers: String) -> Health {
        let status = (try? JSONSerialization.jsonObject(with: Data(auth.utf8))) as? [String: Any]
        return Health(signedIn: status?["loggedIn"] as? Bool ?? false, servers: MCPServer.parse(servers))
    }

    var centralOS: [MCPServer] { servers.filter(\.isCentralOS) }
    var centralOSConnected: Bool { centralOS.contains { $0.status == .connected } }
    var ready: Bool { signedIn && centralOSConnected }
    var needsSignIn: [String] { servers.filter { $0.status == .needsSignIn }.map(\.name) }
    var failing: [String] { servers.filter { $0.status == .failing }.map(\.name) }
}
