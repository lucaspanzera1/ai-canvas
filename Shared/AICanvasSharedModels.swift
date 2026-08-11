import Foundation

/// Shared between the AICanvas app and the AICanvasWidgetExtension target.
/// Keep this file Foundation-only so it compiles cleanly in both targets.

enum AICanvasAppGroup {
    static let suiteID = "group.com.panzera.AICanvas"
    static let recentNotebooksKey = "widget.recentNotebooks"
    static let pomodoroStateKey = "widget.pomodoroState"
    static let maxRecentNotebooks = 8

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteID) ?? .standard
    }

    static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct WidgetNotebookSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var lastModified: Date
}

struct WidgetPomodoroSnapshot: Codable, Equatable {
    var modeLabel: String
    var modeRaw: String
    var isRunning: Bool
    var startDate: Date?
    var endDate: Date?
    var remainingSeconds: Int
    var totalSeconds: Int
}

enum AICanvasDeepLink {
    static let scheme = "aicanvas"

    static func notebookURL(id: UUID) -> URL {
        URL(string: "\(scheme)://notebook?id=\(id.uuidString)")!
    }

    static let newNotebookURL = URL(string: "\(scheme)://new")!
    static let pomodoroURL = URL(string: "\(scheme)://pomodoro")!
}
