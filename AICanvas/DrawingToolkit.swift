import SwiftUI
import PencilKit

// MARK: - Palette de cores premium

let toolkitColors: [(Color, String)] = [
    // Pretos / Cinzas
    (.black,                                    "Preto"),
    (Color(red: 0.20, green: 0.20, blue: 0.22),"Grafite"),
    (.gray,                                     "Cinza"),
    (Color(red: 0.75, green: 0.75, blue: 0.78),"Prata"),

    // Vermelhos / Laranjas / Amarelos
    (Color(red: 0.90, green: 0.15, blue: 0.15),"Vermelho"),
    (Color(red: 0.95, green: 0.42, blue: 0.10),"Laranja"),
    (Color(red: 0.98, green: 0.80, blue: 0.10),"Amarelo"),
    (Color(red: 0.20, green: 0.65, blue: 0.25),"Verde"),

    // Azuis / Roxos
    (Color(red: 0.12, green: 0.55, blue: 0.98),"Azul Céu"),
    (Color(red: 0.10, green: 0.25, blue: 0.85),"Azul Royal"),
    (Color(red: 0.35, green: 0.10, blue: 0.80),"Roxo"),
    (Color(red: 0.88, green: 0.22, blue: 0.65),"Rosa"),

    // Extras
    (Color(red: 0.00, green: 0.75, blue: 0.72),"Turquesa"),
    (Color(red: 0.55, green: 0.35, blue: 0.20),"Marrom"),
    (.white,                                    "Branco"),
]

// MARK: - DrawingToolType extension

extension DrawingToolType {
    var label: String {
        switch self {
        case .pen:         return "Caneta"
        case .pencil:      return "Lápis"
        case .marker:      return "Marcador"
        case .monoline:    return "Monoline"
        case .fountainPen: return "Pena"
        case .watercolor:  return "Aquarela"
        case .crayon:      return "Giz de cera"
        case .eraser:      return "Borracha"
        }
    }

    var icon: String {
        switch self {
        case .pen:         return "pencil.tip"
        case .pencil:      return "pencil"
        case .marker:      return "highlighter"
        case .monoline:    return "pencil.line"
        case .fountainPen: return "nib"
        case .watercolor:  return "drop"
        case .crayon:      return "scribble"
        case .eraser:      return "eraser"
        }
    }

    // Amostra de traço para preview visual
    var samplePath: Path {
        switch self {
        case .pen, .monoline, .fountainPen:
            var p = Path()
            p.move(to: CGPoint(x: 4, y: 20))
            p.addCurve(to: CGPoint(x: 46, y: 20),
                       control1: CGPoint(x: 16, y: 6),
                       control2: CGPoint(x: 34, y: 34))
            return p
        case .pencil, .crayon:
            var p = Path()
            p.move(to: CGPoint(x: 4, y: 24))
            p.addLine(to: CGPoint(x: 46, y: 16))
            return p
        case .marker, .watercolor:
            var p = Path()
            p.move(to: CGPoint(x: 4, y: 22))
            p.addCurve(to: CGPoint(x: 46, y: 18),
                       control1: CGPoint(x: 20, y: 10),
                       control2: CGPoint(x: 32, y: 30))
            return p
        case .eraser:
            var p = Path()
            p.move(to: CGPoint(x: 10, y: 20))
            p.addLine(to: CGPoint(x: 40, y: 20))
            return p
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .marker, .watercolor: return 10
        case .crayon:              return 8
        case .eraser:              return 8
        default:                   return 3.5
        }
    }
}

// MARK: - CanvasManager ruler extension

extension CanvasManager {
    func enableRuler() {
        guard let canvasView else { return }
        canvasView.isRulerActive = true
    }

    func disableRuler() {
        guard let canvasView else { return }
        canvasView.isRulerActive = false
    }

    func toggleRuler() {
        guard let canvasView else { return }
        canvasView.isRulerActive.toggle()
    }

    var isRulerActive: Bool {
        canvasView?.isRulerActive ?? false
    }

    // Lasso tool nativo do PencilKit
    func enableLasso() {
        canvasView?.tool = PKLassoTool()
        isSelectionMode = true
    }
}



// MARK: - Main Toolkit View

/// Substitui DrawingToolbar com todas as funcionalidades do PencilKit
struct DrawingToolkit: View {
    @ObservedObject var canvasManager: CanvasManager

    // Callbacks for image insertion (wired from ContentView)
    var onInsertImageFromLibrary: (() -> Void)? = nil
    var onInsertImageFromCamera: (() -> Void)? = nil
    var onPasteImage: (() -> Void)? = nil

    // Internal panel state
    @State private var expanded = true
    @State private var activePanel: ActivePanel? = nil

    // Local opacity separated from color
    @State private var opacity: Double = 1.0
    @State private var rulerActive: Bool = false

    // Computed: is lasso active?
    private var isLassoActive: Bool {
        canvasManager.isSelectionMode && canvasManager.canvasView?.tool is PKLassoTool
    }

    enum ActivePanel: Equatable {
        case color, width, tools
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sub-panels above the main bar
            if expanded {
                Group {
                    if activePanel == .tools {
                        toolsPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if activePanel == .color {
                        colorPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if activePanel == .width {
                        widthPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.82), value: activePanel)

                mainBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                collapsedPill
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expanded)
        .onReceive(canvasManager.$toolConfig) { _ in
            // reset lasso state when tool changes externally
        }
    }

    // MARK: - Main Bar

    private var mainBar: some View {
        HStack(spacing: 0) {
            // Collapse
            barButton(icon: "chevron.down", tint: AppTheme.textMuted) {
                withAnimation(.spring(response: 0.3)) { expanded = false }
            }

            tkDivider

            // Lasso (native PencilKit)
            barToggleButton(
                icon: "lasso",
                label: "Lasso",
                isOn: isLassoActive,
                tint: isLassoActive ? .blue : AppTheme.textSecondary
            ) {
                toggleLasso()
            }

            // Ruler
            barToggleButton(
                icon: "ruler",
                label: "Régua",
                isOn: rulerActive,
                tint: rulerActive ? .orange : AppTheme.textSecondary
            ) {
                rulerActive.toggle()
                if rulerActive {
                    canvasManager.enableRuler()
                } else {
                    canvasManager.disableRuler()
                }
            }

            tkDivider

            // Image Insert Button
            Menu {
                Button {
                    onPasteImage?()
                } label: {
                    Label("Colar Imagem", systemImage: "doc.on.clipboard")
                }

                Button {
                    onInsertImageFromLibrary?()
                } label: {
                    Label("Fotos", systemImage: "photo.on.rectangle")
                }

                Button {
                    onInsertImageFromCamera?()
                } label: {
                    Label("Câmera", systemImage: "camera")
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(height: 18)
                    Text("Imagem")
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            tkDivider

            Button {
                togglePanel(.tools)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: canvasManager.toolConfig.type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canvasManager.toolConfig.type == .eraser
                                         ? AppTheme.textSecondary
                                         : canvasManager.toolConfig.color)

                    Text(canvasManager.toolConfig.type.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(activePanel == .tools ? AppTheme.background : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(activePanel == .tools ? AppTheme.borderHover : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            tkDivider

            // Color swatch
            if canvasManager.toolConfig.type != .eraser {
                Button {
                    togglePanel(.color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(canvasManager.toolConfig.color)
                            .frame(width: 28, height: 28)
                            .shadow(color: canvasManager.toolConfig.color.opacity(0.6),
                                    radius: activePanel == .color ? 8 : 3)

                        if activePanel == .color {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            // Width & opacity preview button
            Button {
                togglePanel(.width)
            } label: {
                widthPreviewButton
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.borderHover, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadowColor, radius: 12, x: 0, y: 5)
    }

    // MARK: - Tools Panel

    private var toolsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FERRAMENTAS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.horizontal, 2)

            // Two-column grid
            let tools = DrawingToolType.allCases
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(tools, id: \.self) { tool in
                    toolCard(tool)
                }
            }
        }
        .padding(14)
        .background(panelBackground)
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    private func toolCard(_ tool: DrawingToolType) -> some View {
        let isSelected = canvasManager.toolConfig.type == tool && !isLassoActive

        return Button {
            canvasManager.selectTool(tool)
            rulerActive = false
            canvasManager.disableRuler()
            // keep tools panel open, can close by tapping chip again
        } label: {
            VStack(spacing: 8) {
                // Stroke preview canvas
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? (colorScheme == .dark
                                 ? Color.white.opacity(0.06)
                                 : Color.black.opacity(0.04))
                              : Color.clear)

                    if tool == .eraser {
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textMuted)
                    } else {
                        // Stroke preview
                        tool.samplePath
                            .stroke(
                                isSelected ? canvasManager.toolConfig.color : AppTheme.textMuted,
                                style: StrokeStyle(
                                    lineWidth: tool.strokeWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .frame(width: 50, height: 40)
                            .clipped()
                    }
                }
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? AppTheme.borderHover : Color.clear, lineWidth: 1.5)
                )

                Text(tool.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Color Panel

    private var colorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COR")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)

            // Color grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(toolkitColors, id: \.1) { entry in
                    colorSwatch(entry)
                }
            }

            Divider().padding(.vertical, 2)

            // Opacity slider
            VStack(spacing: 6) {
                HStack {
                    Text("OPACIDADE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                    Text("\(Int(opacity * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                opacitySlider
            }
        }
        .padding(14)
        .background(panelBackground)
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    private func colorSwatch(_ entry: (Color, String)) -> some View {
        let isWhite = entry.1 == "Branco"

        // Compare base hues (ignore opacity for selection check)
        let isSelected: Bool = {
            // Quick check by name match stored in a separate state is complex,
            // so we approximate by checking UIColor components
            guard let ui1 = UIColor(entry.0).cgColor.components,
                  let ui2 = UIColor(canvasManager.toolConfig.color).cgColor.components
            else { return false }
            let threshold: CGFloat = 0.05
            return abs((ui1[safe: 0] ?? 0) - (ui2[safe: 0] ?? 0)) < threshold &&
                   abs((ui1[safe: 1] ?? 0) - (ui2[safe: 1] ?? 0)) < threshold &&
                   abs((ui1[safe: 2] ?? 0) - (ui2[safe: 2] ?? 0)) < threshold
        }()

        return Button {
            let finalColor = entry.0.opacity(opacity)
            canvasManager.setColor(finalColor)
        } label: {
            ZStack {
                if isWhite {
                    // Checkered for white
                    CheckerboardView()
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .frame(width: 32, height: 32)
                }
                RoundedRectangle(cornerRadius: 7)
                    .fill(entry.0)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(
                                isSelected ? Color.blue : AppTheme.border.opacity(0.4),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isWhite ? .gray : .white)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }

    private var opacitySlider: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Checkerboard background (shows through for transparency)
                CheckerboardView()
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Current color gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        canvasManager.toolConfig.color.opacity(0),
                        canvasManager.toolConfig.color.opacity(1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Thumb
                let thumbX = CGFloat(opacity) * (geo.size.width - 20) + 10
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                    .offset(x: thumbX - 11)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let new = min(max((value.location.x - 10) / (geo.size.width - 20), 0), 1)
                                opacity = new
                                applyOpacity()
                            }
                    )
            }
        }
        .frame(height: 26)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in } // handled by thumb
        )
    }

    // MARK: - Width Panel

    private var widthPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(canvasManager.toolConfig.type == .eraser ? "TAMANHO" : "ESPESSURA")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Text(String(format: "%.0f pt", canvasManager.toolConfig.width))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            // Preview stroke
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.background)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )

                if canvasManager.toolConfig.type == .eraser {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.textMuted.opacity(0.3))
                        .frame(
                            width: min(max(canvasManager.toolConfig.width * 2.5, 8), 260),
                            height: min(max(canvasManager.toolConfig.width, 8), 28)
                        )
                } else {
                    HorizontalLine()
                        .stroke(
                            canvasManager.toolConfig.color,
                            style: StrokeStyle(
                                lineWidth: min(canvasManager.toolConfig.width, 20),
                                lineCap: .round
                            )
                        )
                        .frame(height: min(canvasManager.toolConfig.width, 20))
                        .padding(.horizontal, 20)
                }
            }

            // Width slider
            GeometryReader { geo in
                let minW: CGFloat = 1
                let maxW: CGFloat = 36
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.background)
                        .frame(height: 8)
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))

                    // Filled track
                    let fraction = (canvasManager.toolConfig.width - minW) / (maxW - minW)
                    let trackWidth = min(max(fraction * geo.size.width, 0), geo.size.width)
                    Capsule()
                        .fill(
                            canvasManager.toolConfig.type == .eraser
                            ? AnyShapeStyle(AppTheme.textMuted)
                            : AnyShapeStyle(LinearGradient(
                                colors: [canvasManager.toolConfig.color.opacity(0.6), canvasManager.toolConfig.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        )
                        .frame(width: trackWidth, height: 8)

                    // Thumb
                    let thumbX = fraction * (geo.size.width - 24) + 12
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                        .offset(x: thumbX - 12)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let raw = (value.location.x - 12) / (geo.size.width - 24)
                                    let clamped = min(max(raw, 0), 1)
                                    let newWidth = minW + clamped * (maxW - minW)
                                    canvasManager.setWidth(newWidth)
                                }
                        )
                }
            }
            .frame(height: 24)

            // Quick presets
            HStack(spacing: 8) {
                ForEach(quickWidths, id: \.self) { w in
                    let isSel = abs(canvasManager.toolConfig.width - w) < 0.5
                    Button {
                        canvasManager.setWidth(w)
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(canvasManager.toolConfig.type == .eraser
                                      ? AppTheme.textMuted
                                      : (isSel ? canvasManager.toolConfig.color : AppTheme.textMuted))
                                .frame(
                                    width: min(max(w / 36 * 22, 3), 22),
                                    height: min(max(w / 36 * 22, 3), 22)
                                )
                                .frame(height: 22)

                            Text(String(format: "%.0f", w))
                                .font(.system(size: 9, weight: isSel ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(isSel ? AppTheme.textPrimary : AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSel ? AppTheme.background : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSel ? AppTheme.borderHover : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(panelBackground)
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    private var quickWidths: [CGFloat] {
        canvasManager.toolConfig.type == .eraser
        ? [4, 10, 20, 36]
        : [1, 3, 7, 14, 24]
    }

    // MARK: - Width preview button in main bar

    private var widthPreviewButton: some View {
        let w = canvasManager.toolConfig.width
        let dotSize = min(max(w / 36 * 22, 3), 22)

        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(activePanel == .width ? AppTheme.background : AppTheme.surfaceElevated)
                .frame(width: 38, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(activePanel == .width ? AppTheme.borderHover : AppTheme.border, lineWidth: 1)
                )

            if canvasManager.toolConfig.type == .eraser {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.textMuted.opacity(0.5))
                    .frame(width: dotSize, height: dotSize * 0.6)
            } else {
                Circle()
                    .fill(canvasManager.toolConfig.color)
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }

    // MARK: - Collapsed Pill

    private var collapsedPill: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { expanded = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLassoActive ? "lasso" : canvasManager.toolConfig.type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isLassoActive ? .blue :
                        (canvasManager.toolConfig.type == .eraser ? AppTheme.textSecondary : canvasManager.toolConfig.color)
                    )

                if !isLassoActive && canvasManager.toolConfig.type != .eraser {
                    Circle()
                        .fill(canvasManager.toolConfig.color)
                        .frame(width: 8, height: 8)
                }

                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AppTheme.surface)
                    .overlay(Capsule().stroke(AppTheme.borderHover, lineWidth: 1))
            )
            .shadow(color: AppTheme.shadowColor, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared UI helpers

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.borderHover, lineWidth: 1)
            )
    }

    private var tkDivider: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: 22)
            .padding(.horizontal, 6)
    }

    private func barButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private func barToggleButton(icon: String, label: String, isOn: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(tint)
                    .frame(height: 18)
                Text(label)
                    .font(.system(size: 8, weight: isOn ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(tint.opacity(0.85))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn
                          ? tint.opacity(colorScheme == .dark ? 0.15 : 0.08)
                          : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isOn ? tint.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func togglePanel(_ panel: ActivePanel) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activePanel = activePanel == panel ? nil : panel
        }
    }

    private func toggleLasso() {
        if isLassoActive {
            // Switch back to previous drawing tool
            canvasManager.isSelectionMode = false
            canvasManager.applyCurrentTool()
        } else {
            canvasManager.enableLasso()
        }
    }

    private func applyOpacity() {
        // Find the pure base color from toolkitColors that best matches current
        guard let bestEntry = toolkitColors.min(by: { a, b in
            colorDistance(a.0, canvasManager.toolConfig.color) < colorDistance(b.0, canvasManager.toolConfig.color)
        }) else { return }
        canvasManager.setColor(bestEntry.0.opacity(opacity))
    }

    private func colorDistance(_ a: Color, _ b: Color) -> CGFloat {
        guard let ca = UIColor(a).cgColor.components,
              let cb = UIColor(b).cgColor.components else { return 999 }
        let dr = (ca[safe: 0] ?? 0) - (cb[safe: 0] ?? 0)
        let dg = (ca[safe: 1] ?? 0) - (cb[safe: 1] ?? 0)
        let db = (ca[safe: 2] ?? 0) - (cb[safe: 2] ?? 0)
        return sqrt(dr*dr + dg*dg + db*db)
    }
}

// MARK: - Support Shapes

struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

struct CheckerboardView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(patternImage: checkerImage())
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func checkerImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        UIColor(white: 0.82, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 5, height: 5))
        ctx.fill(CGRect(x: 5, y: 5, width: 5, height: 5))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK: - Collection safe subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
