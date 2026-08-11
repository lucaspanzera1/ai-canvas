import WidgetKit
import SwiftUI

struct PomodoroEntry: TimelineEntry {
    let date: Date
    let state: WidgetPomodoroSnapshot?
}

struct PomodoroProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroEntry {
        PomodoroEntry(date: .now, state: Self.sampleState)
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> PomodoroEntry {
        let state = AICanvasAppGroup.load(WidgetPomodoroSnapshot.self, forKey: AICanvasAppGroup.pomodoroStateKey)
        return PomodoroEntry(date: .now, state: state)
    }

    static let sampleState = WidgetPomodoroSnapshot(
        modeLabel: "Foco",
        modeRaw: "work",
        isRunning: true,
        startDate: .now,
        endDate: .now.addingTimeInterval(18 * 60),
        remainingSeconds: 18 * 60,
        totalSeconds: 25 * 60
    )
}

private func modeColor(_ modeRaw: String) -> Color {
    switch modeRaw {
    case "work": return .orange
    case "longBreak": return .blue
    default: return .green
    }
}

struct PomodoroStatusWidgetView: View {
    let entry: PomodoroEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let state = entry.state {
                Label(state.modeLabel, systemImage: state.isRunning ? "timer" : "pause.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(modeColor(state.modeRaw))

                Spacer(minLength: 0)

                if state.isRunning, let start = state.startDate, let end = state.endDate, start <= end {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)

                    ProgressView(timerInterval: start...end, countsDown: false)
                        .tint(modeColor(state.modeRaw))
                } else {
                    Text(formatted(state.remainingSeconds))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    ProgressView(value: progress(state))
                        .tint(modeColor(state.modeRaw))
                }
            } else {
                Label("Pomodoro", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Toque para iniciar um foco.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .widget)
        .widgetURL(AICanvasDeepLink.pomodoroURL)
    }

    private func progress(_ state: WidgetPomodoroSnapshot) -> Double {
        guard state.totalSeconds > 0 else { return 0 }
        return 1 - (Double(state.remainingSeconds) / Double(state.totalSeconds))
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct PomodoroStatusWidget: Widget {
    let kind = "PomodoroStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroProvider()) { entry in
            PomodoroStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Pomodoro")
        .description("Acompanhe sua sessão de foco em andamento.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    PomodoroStatusWidget()
} timeline: {
    PomodoroEntry(date: .now, state: PomodoroProvider.sampleState)
}
