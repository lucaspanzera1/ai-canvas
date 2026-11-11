import SwiftUI

/// Floating, always-on-top Pomodoro widget. Collapses to a small square tile
/// and expands into a full control card without leaving the current screen.
struct PomodoroWidgetView: View {
    @ObservedObject var manager: PomodoroManager
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var isExpanded = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
                    .transition(.opacity.combined(with: .offset(y: 8)))
            } else {
                collapsedTile
                    .transition(.opacity)
            }
        }
        .padding(20)
        .animation(AppTheme.motion, value: isExpanded)
    }

    // MARK: Collapsed

    private var collapsedTile: some View {
        Button {
            withAnimation(AppTheme.motion) { isExpanded = true }
        } label: {
            VStack(spacing: 0) {
                Group {
                    if manager.isRunning {
                        Text(manager.formattedRemaining)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    } else {
                        Image(systemName: "timer")
                            .font(.system(size: 15, weight: .light))
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                progressBar(height: 2)
            }
            .frame(width: 56, height: 56)
            .background(AppTheme.surface)
            .hairline(AppTheme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: Expanded

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(manager.isRunning ? AppTheme.accent : AppTheme.textMuted)
                    .frame(width: 6, height: 6)
                Text(manager.mode.label.localized.uppercased())
                    .font(AppTheme.label(11))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings) {
                    PomodoroSettingsView(manager: manager)
                }

                Button {
                    withAnimation(AppTheme.motion) { isExpanded = false }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Time
            VStack(alignment: .leading, spacing: 14) {
                Text(manager.formattedRemaining)
                    .font(.system(size: 52, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .tracking(-2)
                    .foregroundStyle(AppTheme.textPrimary)
                    .contentTransition(.numericText())

                progressBar(height: 2)

                HStack {
                    Text(String(format: "%@ %02d", "Sessão".localized.uppercased(), manager.completedWorkSessions + 1))
                        .font(AppTheme.label())
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    sessionMarks
                }
            }
            .padding(16)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Controls — three joined cells
            HStack(spacing: 0) {
                controlCell(icon: "arrow.counterclockwise") { manager.reset() }
                Rectangle().fill(AppTheme.border).frame(width: 1)
                Button {
                    manager.toggle()
                } label: {
                    Image(systemName: manager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.accent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(AppTheme.border).frame(width: 1)
                controlCell(icon: "forward.end") { manager.skip() }
            }
            .frame(height: 48)
        }
        .frame(width: 248)
        .background(AppTheme.surface)
        .hairline(AppTheme.accent)
    }

    private func progressBar(height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(AppTheme.border)
                Rectangle()
                    .fill(AppTheme.accent)
                    .frame(width: geo.size.width * manager.progress)
                    .animation(.linear(duration: 1), value: manager.progress)
            }
        }
        .frame(height: height)
    }

    private var sessionMarks: some View {
        HStack(spacing: 3) {
            ForEach(0..<manager.sessionsUntilLongBreak, id: \.self) { index in
                Rectangle()
                    .fill(index < manager.sessionsCompletedInCycle ? AppTheme.accent : Color.clear)
                    .frame(width: 8, height: 8)
                    .hairline(AppTheme.accent)
            }
        }
    }

    private func controlCell(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings

struct PomodoroSettingsView: View {
    @ObservedObject var manager: PomodoroManager
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Configurações do Pomodoro", color: AppTheme.textPrimary)
                .padding(16)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(spacing: 14) {
                settingRow(title: "Foco (min)", value: $manager.workMinutes, range: 5...60)
                settingRow(title: "Pausa curta (min)", value: $manager.shortBreakMinutes, range: 1...30)
                settingRow(title: "Pausa longa (min)", value: $manager.longBreakMinutes, range: 5...45)
                settingRow(title: "Sessões até pausa longa", value: $manager.sessionsUntilLongBreak, range: 2...8)
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(AppTheme.surface)
    }

    private func settingRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title.localized)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            HStack(spacing: -1) {
                stepButton("minus", enabled: value.wrappedValue > range.lowerBound) {
                    value.wrappedValue -= 1
                }
                Text(String(format: "%02d", value.wrappedValue))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 28)
                    .hairline()
                stepButton("plus", enabled: value.wrappedValue < range.upperBound) {
                    value.wrappedValue += 1
                }
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textMuted)
                .frame(width: 28, height: 28)
                .hairline()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
