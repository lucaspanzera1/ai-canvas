import SwiftUI

private extension PomodoroMode {
    var color: Color {
        switch self {
        case .work: return Color(red: 0.95, green: 0.36, blue: 0.29)
        case .shortBreak: return Color(red: 0.22, green: 0.74, blue: 0.55)
        case .longBreak: return Color(red: 0.30, green: 0.56, blue: 0.95)
        }
    }
    var icon: String {
        switch self {
        case .work: return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
}

/// Floating, always-on-top Pomodoro widget. Collapses to a small progress bubble
/// and expands into a full control card without leaving the current screen.
struct PomodoroWidgetView: View {
    @ObservedObject var manager: PomodoroManager
    @State private var isExpanded = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity)
                    ))
            } else {
                collapsedBubble
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: Collapsed

    private var collapsedBubble: some View {
        Button {
            withAnimation { isExpanded = true }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .shadow(color: manager.mode.color.opacity(0.35), radius: 10, y: 4)

                Circle()
                    .stroke(manager.mode.color.opacity(0.15), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: manager.progress)
                    .stroke(manager.mode.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: manager.progress)

                if manager.isRunning {
                    Text(manager.formattedRemaining)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    Image(systemName: manager.mode.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(manager.mode.color)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Expanded

    private var expandedCard: some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(manager.mode.color).frame(width: 7, height: 7)
                    Text(manager.mode.label.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(0.5)
                }

                Spacer()

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings) {
                    PomodoroSettingsView(manager: manager)
                }

                Button {
                    withAnimation { isExpanded = false }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            ZStack {
                Circle()
                    .stroke(manager.mode.color.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: manager.progress)
                    .stroke(
                        AngularGradient(colors: [manager.mode.color.opacity(0.5), manager.mode.color], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: manager.progress)

                VStack(spacing: 4) {
                    Text(manager.formattedRemaining)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Sessão \(manager.completedWorkSessions + 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .frame(width: 150, height: 150)

            sessionDots

            HStack(spacing: 20) {
                controlButton(icon: "arrow.counterclockwise", size: 16) { manager.reset() }

                Button {
                    manager.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(manager.mode.color)
                            .frame(width: 56, height: 56)
                            .shadow(color: manager.mode.color.opacity(0.4), radius: 8, y: 3)
                        Image(systemName: manager.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: manager.isRunning ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)

                controlButton(icon: "forward.end.fill", size: 15) { manager.skip() }
            }
        }
        .padding(20)
        .frame(width: 230)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadowColor, radius: 20, y: 8)
    }

    private var sessionDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<manager.sessionsUntilLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < manager.sessionsCompletedInCycle ? manager.mode.color : manager.mode.color.opacity(0.15))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func controlButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 40, height: 40)
                .background(AppTheme.surfaceElevated)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings

struct PomodoroSettingsView: View {
    @ObservedObject var manager: PomodoroManager
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurações do Pomodoro")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            settingRow(title: "Foco (min)", value: $manager.workMinutes, range: 5...60)
            settingRow(title: "Pausa curta (min)", value: $manager.shortBreakMinutes, range: 1...30)
            settingRow(title: "Pausa longa (min)", value: $manager.longBreakMinutes, range: 5...45)
            settingRow(title: "Sessões até pausa longa", value: $manager.sessionsUntilLongBreak, range: 2...8)
        }
        .padding(20)
        .frame(width: 260)
    }

    private func settingRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title.localized)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Stepper("\(value.wrappedValue)", value: value, in: range)
                .fixedSize()
                .font(.system(size: 13, weight: .medium))
        }
    }
}
