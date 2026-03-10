import SwiftUI
import PencilKit

// MARK: - Palette de cores

private let drawingColors: [(Color, String)] = [
    (Color.black, "Preto"),
    (Color(uiColor: .darkGray), "Cinza Escuro"),
    (Color.gray, "Cinza"),
    (Color(uiColor: .lightGray), "Cinza Claro"),
    (.white, "Branco"),
    
    (Color.red, "Vermelho"),
    (Color.orange, "Laranja"),
    (Color.yellow, "Amarelo"),
    (Color.green, "Verde"),
    (Color.mint, "Menta"),
    
    (Color.cyan, "Ciano"),
    (Color.blue, "Azul"),
    (Color.indigo, "Índigo"),
    (Color.purple, "Roxo"),
    (Color.pink, "Rosa")
]

// MARK: - Drawing Toolbar

/// Toolbar de ferramentas de desenho com estética minimalista.
/// Flutua sobre o canvas no canto inferior, substituindo o PKToolPicker nativo.
struct DrawingToolbar: View {
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            toolbarDivider

            // Selection toggle
            Button {
                showColorPicker = false
                showWidthPicker = false
                withAnimation { canvasManager.isSelectionMode.toggle() }
            } label: {
                Image(systemName: "viewfinder")
                    .font(.system(size: 15, weight: canvasManager.isSelectionMode ? .semibold : .regular))
                    .foregroundStyle(canvasManager.isSelectionMode ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 34, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(canvasManager.isSelectionMode ? AppTheme.background : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(canvasManager.isSelectionMode ? AppTheme.borderHover : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)

            toolbarDivider

            // Drawing tools
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DrawingToolType.allCases, id: \.self) { tool in
                        ToolButton(
                            tool: tool,
                            isSelected: !canvasManager.isSelectionMode && canvasManager.toolConfig.type == tool,
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
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 240)

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
                    // A simple width indicator dot whose size reflects current width
                    let dotSize = min(max(canvasManager.toolConfig.width / 18 * 22, 4), 22)
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.background)
                            .frame(width: 34, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.borderHover, lineWidth: 1)
                            )
                        Circle()
                            .fill(canvasManager.toolConfig.color)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.borderHover, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    // MARK: - Color Picker Panel

    private var colorPickerPanel: some View {
        VStack(spacing: 8) {
            Text("COR")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 8), count: 5), spacing: 8) {
                ForEach(drawingColors, id: \.1) { colorEntry in
                    let isSelected = canvasManager.toolConfig.color == colorEntry.0
                    Button {
                        canvasManager.setColor(colorEntry.0)
                    } label: {
                        ZStack {
                            // Checkered background for white
                            if colorEntry.1 == "Branco" {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: 0.95))
                                    .frame(width: 30, height: 30)
                            }

                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorEntry.0)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            isSelected ? AppTheme.accent : AppTheme.borderHover.opacity(0.3),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                )

                            if isSelected {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(colorEntry.1 == "Preto" ? .white : AppTheme.textPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.25), value: isSelected)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.borderHover, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 2)
    }

    // MARK: - Width Picker Panel

    private var widthPickerPanel: some View {
        VStack(spacing: 10) {
            Text("ESPESSURA")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ForEach([2.0, 5.0, 10.0, 18.0], id: \.self) { width in
                    let isSelected = abs(canvasManager.toolConfig.width - width) < 0.5
                    Button {
                        canvasManager.setWidth(width)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? AppTheme.background : AppTheme.surfaceElevated)
                                .frame(width: 44, height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            isSelected ? AppTheme.accent : AppTheme.border,
                                            lineWidth: 1
                                        )
                                )

                            let dotSize = min(max(width / 18 * 22, 4), 22)
                            Circle()
                                .fill(isSelected ? canvasManager.toolConfig.color : AppTheme.textMuted)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25), value: isSelected)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.borderHover, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 2)
    }

    // MARK: - Collapsed Button

    private var collapsedButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { expanded = true }
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surface)
                        .frame(width: 24, height: 24)
                    Image(systemName: canvasManager.isSelectionMode ? "viewfinder" : toolIcon(canvasManager.toolConfig.type))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.surface)
                    .overlay(Capsule().stroke(AppTheme.borderHover, lineWidth: 1))
            )
            .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var toolbarDivider: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }

    private func toolIcon(_ type: DrawingToolType) -> String {
        switch type {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .monoline: return "pencil.line"
        case .fountainPen: return "nib"
        case .watercolor: return "drop.fill"
        case .crayon: return "pencil.and.outline"
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
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                        ? AppTheme.accent
                        : AppTheme.textSecondary
                    )
                    .frame(width: 34, height: 30)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                        ? AppTheme.background
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected
                        ? AppTheme.borderHover
                        : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var toolIconName: String {
        switch tool {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .monoline: return "pencil.line"
        case .fountainPen: return "nib"
        case .watercolor: return "drop.fill"
        case .crayon: return "pencil.and.outline"
        case .eraser: return "eraser"
        }
    }
}
