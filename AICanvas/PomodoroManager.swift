import Foundation
import Combine
import UserNotifications
import UIKit
import WidgetKit

enum PomodoroMode: String, Codable {
    case work
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .work: return "Foco"
        case .shortBreak: return "Pausa Curta"
        case .longBreak: return "Pausa Longa"
        }
    }
}

/// Drives a Pomodoro focus/break cycle: countdown, session tracking, and local notifications.
final class PomodoroManager: ObservableObject {
    private enum Keys {
        static let work = "pomodoro_work_minutes"
        static let shortBreak = "pomodoro_short_break_minutes"
        static let longBreak = "pomodoro_long_break_minutes"
        static let sessionsUntilLongBreak = "pomodoro_sessions_until_long_break"
    }

    @Published var workMinutes: Int {
        didSet {
            UserDefaults.standard.set(workMinutes, forKey: Keys.work)
            if mode == .work { resetRemainingIfIdle() }
        }
    }
    @Published var shortBreakMinutes: Int {
        didSet {
            UserDefaults.standard.set(shortBreakMinutes, forKey: Keys.shortBreak)
            if mode == .shortBreak { resetRemainingIfIdle() }
        }
    }
    @Published var longBreakMinutes: Int {
        didSet {
            UserDefaults.standard.set(longBreakMinutes, forKey: Keys.longBreak)
            if mode == .longBreak { resetRemainingIfIdle() }
        }
    }
    @Published var sessionsUntilLongBreak: Int {
        didSet { UserDefaults.standard.set(sessionsUntilLongBreak, forKey: Keys.sessionsUntilLongBreak) }
    }

    @Published private(set) var mode: PomodoroMode = .work
    @Published private(set) var isRunning = false
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var completedWorkSessions: Int = 0

    private var timer: Timer?
    private var notificationScheduled = false

    var totalSeconds: Int { Self.duration(for: mode, work: workMinutes, shortBreak: shortBreakMinutes, longBreak: longBreakMinutes) * 60 }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var formattedRemaining: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Number of work sessions completed in the current cycle, for the dot indicator.
    var sessionsCompletedInCycle: Int {
        if mode == .longBreak { return sessionsUntilLongBreak }
        return completedWorkSessions % sessionsUntilLongBreak
    }

    init() {
        let defaults = UserDefaults.standard
        let work = defaults.object(forKey: Keys.work) as? Int ?? 25
        let short = defaults.object(forKey: Keys.shortBreak) as? Int ?? 5
        let long = defaults.object(forKey: Keys.longBreak) as? Int ?? 15
        let sessions = defaults.object(forKey: Keys.sessionsUntilLongBreak) as? Int ?? 4
        workMinutes = work
        shortBreakMinutes = short
        longBreakMinutes = long
        sessionsUntilLongBreak = sessions
        remainingSeconds = work * 60
        syncWidgetSnapshot()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        requestNotificationPermissionIfNeeded()
        scheduleCompletionNotification()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        syncWidgetSnapshot()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        cancelPendingNotification()
        syncWidgetSnapshot()
    }

    func reset() {
        pause()
        remainingSeconds = totalSeconds
        syncWidgetSnapshot()
    }

    /// Manually advances to the next mode without waiting for the countdown.
    func skip() {
        pause()
        advanceMode()
    }

    private func resetRemainingIfIdle() {
        guard !isRunning else { return }
        remainingSeconds = totalSeconds
        syncWidgetSnapshot()
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            completeSession()
            return
        }
        remainingSeconds -= 1
    }

    private func completeSession() {
        pause()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        advanceMode()
    }

    private func advanceMode() {
        switch mode {
        case .work:
            completedWorkSessions += 1
            mode = (completedWorkSessions % sessionsUntilLongBreak == 0) ? .longBreak : .shortBreak
        case .shortBreak:
            mode = .work
        case .longBreak:
            mode = .work
            completedWorkSessions = 0
        }
        remainingSeconds = totalSeconds
        syncWidgetSnapshot()
    }

    // MARK: - Widget Sync

    private func syncWidgetSnapshot() {
        let snapshot = WidgetPomodoroSnapshot(
            modeLabel: mode.label,
            modeRaw: mode.rawValue,
            isRunning: isRunning,
            startDate: isRunning ? Date() : nil,
            endDate: isRunning ? Date().addingTimeInterval(TimeInterval(remainingSeconds)) : nil,
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds
        )
        AICanvasAppGroup.save(snapshot, forKey: AICanvasAppGroup.pomodoroStateKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "PomodoroStatusWidget")
    }

    private static func duration(for mode: PomodoroMode, work: Int, shortBreak: Int, longBreak: Int) -> Int {
        switch mode {
        case .work: return work
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    private func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        switch mode {
        case .work:
            content.title = "Foco concluído! 🍅".localized
            content.body = "Hora de fazer uma pausa.".localized
        case .shortBreak, .longBreak:
            content.title = "Pausa concluída".localized
            content.body = "Hora de voltar ao foco.".localized
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, TimeInterval(remainingSeconds)), repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro_session_end", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        notificationScheduled = true
    }

    private func cancelPendingNotification() {
        guard notificationScheduled else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro_session_end"])
        notificationScheduled = false
    }
}
