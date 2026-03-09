import SwiftUI
import PencilKit

// MARK: - Palette de cores

private let drawingColors: [(Color, String)] = [
    (Color(red: 0.06, green: 0.06, blue: 0.14), "Preto"),
    (.white, "Branco"),
    (Color(red: 0.58, green: 0.22, blue: 1.0), "Roxo"),
    (Color(red: 0.0, green: 0.85, blue: 1.0), "Cyan"),
    (Color(red: 0.18, green: 1.0, blue: 0.58), "Verde"),
    (Color(red: 1.0, green: 0.2, blue: 0.6), "Rosa"),
    (Color(red: 1.0, green: 0.6, blue: 0.0), "Laranja"),
    (Color(red: 1.0, green: 0.9, blue: 0.0), "Amarelo"),
    (Color(red: 0.3, green: 0.6, blue: 1.0), "Azul"),
    (Color(red: 1.0, green: 0.35, blue: 0.25), "Vermelho"),
]

// MARK: - Drawing Toolbar

/// Toolbar de ferramentas de desenho com estética gamificada.
/// Flutua sobre o canvas no canto inferior, substituindo o PKToolPicker nativo.
struct GameDrawingToolbar: View {
    @ObservedObject var canvasManager: CanvasManager
    @State private var showColorPicker = false
    @State private var showWidthPicker = false
    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                // Sub-pickers
                if showColorPicker {
                    colorPickerPanel
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                if showWidthPicker && !showColorPicker {
                    widthPickerPanel
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                // Main toolbar
                mainToolbar
            } else {
                // Collapsed toggle button
                collapsedButton
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showColorPicker)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showWidthPicker)
    }

    // MARK: - Main Toolbar

    private var mainToolbar: some View {
        HStack(spacing: 6) {
            // Collapse button
            Button {
                withAnimation(.spring(response: 0.3)) { expanded = false }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(GameTheme.textMuted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            toolbarDivider

            // Drawing tools
            ForEach(DrawingToolType.allCases, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: canvasManager.toolConfig.type == tool,
                    selectedColor: canvasManager.toolConfig.color
                ) {
                    if canvasManager.toolConfig.type == tool && tool != .eraser {
                        // Mesma tool: toggle width picker
                        showColorPicker = false
                        withAnimation { showWidthPicker.toggle() }
                    } else {
                        showColorPicker = false
                        showWidthPicker = false
                        canvasManager.selectTool(tool)
                    }
                }
            }

            toolbarDivider

            // Color swatch button (só mostra se não for borracha)
            if canvasManager.toolConfig.type != .eraser {
                Button {
                    showWidthPicker = false
                    withAnimation { showColorPicker.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(canvasManager.toolConfig.color)
                            .frame(width: 26, height: 26)
                            .shadow(color: canvasManager.toolConfig.color.opacity(0.8), radius: showColorPicker ? 8 : 4)

                        Circle()
                            .stroke(
                                showColorPicker
                                ? Color.white
                                : Color.white.opacity(0.4),
                                lineWidth: showColorPicker ? 2 : 1
                            )
                            .frame(width: 26, height: 26)
                    }
                }
                .buttonStyle(.plain)
            }

            // Width indicator
            if canvasManager.toolConfig.type != .eraser {
                Button {
                    showColorPicker = false
                    withAnimation { showWidthPicker.toggle() }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showWidthPicker ? GameTheme.neonPurple.opacity(0.2) : GameTheme.surfaceElevated)
                            .frame(width: 36, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(showWidthPicker ? GameTheme.neonPurple.opacity(0.6) : GameTheme.border, lineWidth: 1)
                            )

                        let diameter = min(max(canvasManager.toolConfig.width / 20 * 18, 3), 18)
                        Circle()
                            .fill(canvasManager.toolConfig.color)
                            .frame(width: diameter, height: diameter)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GameTheme.surface.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(GameTheme.border, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
        .shadow(color: GameTheme.neonPurple.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    // MARK: - Color Picker Panel

    private var colorPickerPanel: some View {
        VStack(spacing: 8) {
            Text("COR")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(GameTheme.textMuted)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 8), count: 5), spacing: 8) {
                ForEach(drawingColors, id: \.1) { colorEntry in
                    let isSelected = canvasManager.toolConfig.color == colorEntry.0
                    Button {
                        canvasManager.setColor(colorEntry.0)
                    } label: {
                        ZStack {
                            // Checkered background for white
                            if colorEntry.1 == "Branco" {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(white: 0.85))
                                    .frame(width: 34, height: 34)
                            }

                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorEntry.0)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            isSelected ? Color.white : Color.white.opacity(0.1),
                                            lineWidth: isSelected ? 2.5 : 1
                                        )
                                )
                                .shadow(
                                    color: isSelected ? colorEntry.0.opacity(0.9) : .clear,
                                    radius: 8
                                )

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(colorEntry.1 == "Preto" || colorEntry.1 == "Roxo" ? .white : .black.opacity(0.7))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25), value: isSelected)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GameTheme.surface.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GameTheme.border, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: -4)
    }

    // MARK: - Width Picker Panel

    private var widthPickerPanel: some View {
        VStack(spacing: 10) {
            Text("ESPESSURA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(GameTheme.textMuted)
                .tracking(2)

            HStack(spacing: 12) {
                ForEach([2.0, 5.0, 10.0, 18.0], id: \.self) { width in
                    let isSelected = abs(canvasManager.toolConfig.width - width) < 0.5
                    Button {
                        canvasManager.setWidth(width)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? GameTheme.neonPurple.opacity(0.15) : GameTheme.surfaceElevated)
                                .frame(width: 52, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isSelected ? GameTheme.neonPurple.opacity(0.7) : GameTheme.border,
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: isSelected ? GameTheme.neonPurple.opacity(0.4) : .clear, radius: 6)

                            let dotSize = min(max(width / 18 * 26, 4), 26)
                            Circle()
                                .fill(isSelected ? canvasManager.toolConfig.color : GameTheme.textSecondary)
                                .frame(width: dotSize, height: dotSize)
                                .shadow(color: isSelected ? canvasManager.toolConfig.color.opacity(0.8) : .clear, radius: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.25), value: isSelected)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GameTheme.surface.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GameTheme.border, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: -4)
    }

    // MARK: - Collapsed Button

    private var collapsedButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { expanded = true }
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(GameTheme.primaryGradient)
                        .frame(width: 24, height: 24)
                        .shadow(color: GameTheme.neonPurple.opacity(0.7), radius: 6)
                    Image(systemName: toolIcon(canvasManager.toolConfig.type))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(GameTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(GameTheme.surface.opacity(0.95))
                    .overlay(Capsule().stroke(GameTheme.border, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var toolbarDivider: some View {
        Rectangle()
            .fill(GameTheme.border)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 2)
    }

    private func toolIcon(_ type: DrawingToolType) -> String {
        switch type {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: DrawingToolType
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { pressed = false }
            }
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: toolIconName)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isSelected
                        ? (tool == .eraser ? GameTheme.neonPink : selectedColor)
                        : GameTheme.textSecondary
                    )
                    .shadow(
                        color: isSelected
                        ? (tool == .eraser ? GameTheme.neonPink.opacity(0.9) : selectedColor.opacity(0.9))
                        : .clear,
                        radius: 6
                    )
                    .frame(width: 38, height: 32)

                // Active indicator dot
                Circle()
                    .fill(isSelected
                          ? (tool == .eraser ? GameTheme.neonPink : GameTheme.neonPurple)
                          : Color.clear)
                    .frame(width: 4, height: 4)
                    .shadow(color: isSelected ? GameTheme.neonPurple.opacity(0.9) : .clear, radius: 3)
            }
            .padding(.horizontal, 2)
            .padding(.top, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                        ? (tool == .eraser
                           ? GameTheme.neonPink.opacity(0.12)
                           : GameTheme.neonPurple.opacity(0.12))
                        : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                ? (tool == .eraser
                                   ? GameTheme.neonPink.opacity(0.4)
                                   : GameTheme.neonPurple.opacity(0.4))
                                : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.9 : 1.0)
    }

    private var toolIconName: String {
        switch tool {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .eraser: return "eraser.fill"
        }
    }
}
