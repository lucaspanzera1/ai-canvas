import SwiftUI
import PDFKit
import UIKit

// MARK: - PDFAnnotationTool

enum PDFAnnotationTool: String, CaseIterable {
    case select
    case draw
    case note
    case erase

    var label: String {
        switch self {
        case .select: return "Selecionar"
        case .draw:   return "Caneta"
        case .note:   return "Nota"
        case .erase:  return "Borracha"
        }
    }

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .draw:   return "pencil.tip"
        case .note:   return "note.text"
        case .erase:  return "eraser"
        }
    }
}

// MARK: - PDFPenStyle

enum PDFPenStyle: String, CaseIterable {
    case pen     = "Caneta"
    case pencil  = "Lápis"
    case marker  = "Marcador"

    var icon: String {
        switch self {
        case .pen:    return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        }
    }

    /// Opacity applied to the PDF ink annotation.
    var annotationOpacity: CGFloat {
        switch self {
        case .pen, .pencil: return 1.0
        case .marker:       return 0.45
        }
    }

    /// Marker uses a wider, flatter stroke visually.
    var lineWidthMultiplier: CGFloat {
        switch self {
        case .pen:    return 1.0
        case .pencil: return 1.0
        case .marker: return 2.5
        }
    }
}

// MARK: - PDFEditorController

final class PDFEditorController: ObservableObject {
    @Published var selectedTool: PDFAnnotationTool = .select
    @Published var inkColor: Color = .black
    @Published var lineWidth: CGFloat = 4
    @Published var penStyle: PDFPenStyle = .pen

    weak var pdfView: PDFView?
    var saveHandler: (() -> Void)?

    private var pendingSave: DispatchWorkItem?

    func applyHighlightToSelection() {
        guard let pdfView,
              let selection = pdfView.currentSelection else { return }

        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = UIColor.systemYellow.withAlphaComponent(0.35)
                page.addAnnotation(annotation)
            }
        }
        pdfView.clearSelection()
        scheduleSave()
    }

    func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveHandler?() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func flushSave() {
        pendingSave?.cancel()
        saveHandler?()
    }
}

// MARK: - PDFNotebookView

struct PDFNotebookView: View {
    let notebook: Notebook
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    @Binding var showSidebar: Bool

    @StateObject private var controller = PDFEditorController()
    @StateObject private var aiConfig: AIConfiguration
    @StateObject private var chatViewModel: ChatViewModel

    @State private var showAIPanel = false
    @State private var showOnboarding: Bool
    @State private var urlToExport: URL?

    init(notebook: Notebook, store: NotebookStore, selectedNotebook: Binding<Notebook?>, showSidebar: Binding<Bool>) {
        self.notebook = notebook
        self.store = store
        self._selectedNotebook = selectedNotebook
        self._showSidebar = showSidebar

        let config = AIConfiguration()
        _aiConfig = StateObject(wrappedValue: config)
        let loadedMessages = store.loadChatHistory(for: notebook)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(aiConfig: config, initialMessages: loadedMessages))
        _showOnboarding = State(initialValue: !KeychainManager.shared.hasAnyAPIKey)
    }

    private var pdfURL: URL? { store.pdfDocumentURL(for: notebook) }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                PDFCanvasToolbar(
                    notebook: notebook,
                    showAIPanel: $showAIPanel,
                    showSidebar: $showSidebar,
                    onBack: {
                        controller.flushSave()
                        store.persistMetadata()
                        selectedNotebook = nil
                    },
                    onExport: {
                        if let url = pdfURL { urlToExport = url }
                    }
                )

                if let pdfURL {
                    ZStack(alignment: .bottom) {
                        PDFEditorRepresentable(
                            documentURL: pdfURL,
                            controller: controller
                        ) { data in
                            store.savePDFDocument(data, for: notebook)
                        }
                        .ignoresSafeArea(edges: .bottom)

                        PDFDrawingToolkit(controller: controller)
                            .padding(.bottom, 24)
                            .padding(.leading, 24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                        Text("PDF não encontrado")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Este caderno não possui um arquivo PDF válido.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
                }
            }

            if showAIPanel {
                AIChatPanelView(viewModel: chatViewModel, aiConfig: aiConfig, isVisible: $showAIPanel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showAIPanel)
        .background(AppTheme.background)
        .onDisappear { controller.flushSave() }
        .fullScreenCover(isPresented: $showOnboarding) {
            MultiProviderOnboardingView(isPresented: $showOnboarding, aiConfig: aiConfig)
        }
        .sheet(item: Binding(
            get: { urlToExport.map { ExportableItem(item: $0) } },
            set: { if $0 == nil { urlToExport = nil } }
        )) { exportable in
            ShareSheet(activityItems: [exportable.item])
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyDidChange)) { _ in
            showOnboarding = true
            showAIPanel = false
            aiConfig.updateAvailableModels()
        }
        .onChange(of: chatViewModel.messages) { _, newMessages in
            store.saveChatHistory(newMessages, for: notebook)
        }
    }
}

// MARK: - PDFCanvasToolbar

struct PDFCanvasToolbar: View {
    let notebook: Notebook
    @Binding var showAIPanel: Bool
    @Binding var showSidebar: Bool
    let onBack: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if !showSidebar {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showSidebar = true }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("Cadernos").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(notebook.emoji).font(.system(size: 16))
                Text(notebook.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            ToolButtonSimple(icon: "square.and.arrow.up", isDisabled: false, color: AppTheme.action, action: onExport)

            Rectangle().fill(AppTheme.border).frame(width: 1, height: 20).padding(.horizontal, 8)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showAIPanel.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAIPanel ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                        .font(.system(size: 14, weight: .medium))
                    Text(showAIPanel ? "Fechar IA" : "Abrir IA")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(showAIPanel ? .white : AppTheme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(showAIPanel ? AppTheme.accent : AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(showAIPanel ? Color.clear : AppTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(AppTheme.surface.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)
        .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
    }
}

// MARK: - PDFDrawingToolkit

struct PDFDrawingToolkit: View {
    @ObservedObject var controller: PDFEditorController

    @State private var expanded = true
    @State private var activePanel: ActivePanel? = nil

    @Environment(\.colorScheme) private var colorScheme

    enum ActivePanel: Equatable { case color, width, tools }

    private var isDrawActive: Bool { controller.selectedTool == .draw }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                Group {
                    if activePanel == .tools {
                        pdfToolsPanel.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if activePanel == .color {
                        pdfColorPanel.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if activePanel == .width {
                        pdfWidthPanel.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.82), value: activePanel)

                mainBar.transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                collapsedPill
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expanded)
    }

    // MARK: Main Bar

    private var mainBar: some View {
        HStack(spacing: 0) {
            barButton(icon: "chevron.down", tint: AppTheme.textMuted) {
                withAnimation(.spring(response: 0.3)) { expanded = false }
            }

            pdfDivider

            Button { controller.applyHighlightToSelection() } label: {
                VStack(spacing: 2) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.10))
                        .frame(height: 18)
                    Text("Grifar")
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            pdfDivider

            Button { togglePanel(.tools) } label: {
                HStack(spacing: 6) {
                    Image(systemName: controller.selectedTool.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDrawActive ? controller.inkColor : AppTheme.textSecondary)
                    Text(controller.selectedTool.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(activePanel == .tools ? AppTheme.background : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(activePanel == .tools ? AppTheme.borderHover : Color.clear, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            if isDrawActive {
                pdfDivider

                HStack(spacing: 2) {
                    ForEach(PDFPenStyle.allCases, id: \.self) { style in
                        penStyleButton(style)
                    }
                }
                .padding(.horizontal, 4)
            }

            pdfDivider

            if isDrawActive {
                Button { togglePanel(.color) } label: {
                    ZStack {
                        Circle()
                            .fill(controller.inkColor)
                            .frame(width: 28, height: 28)
                            .shadow(color: controller.inkColor.opacity(0.6),
                                    radius: activePanel == .color ? 8 : 3)
                        if activePanel == .color {
                            Circle().stroke(Color.white, lineWidth: 2).frame(width: 28, height: 28)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Button { togglePanel(.width) } label: { pdfWidthPreviewButton }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 4).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.borderHover, lineWidth: 1))
        )
        .shadow(color: AppTheme.shadowColor, radius: 12, x: 0, y: 5)
    }

    private func penStyleButton(_ style: PDFPenStyle) -> some View {
        let isSelected = controller.penStyle == style
        return Button { controller.penStyle = style } label: {
            VStack(spacing: 2) {
                Image(systemName: style.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? controller.inkColor : AppTheme.textSecondary)
                    .frame(height: 18)
                Text(style.rawValue)
                    .font(.system(size: 7, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textMuted)
            }
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected
                          ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                          : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? AppTheme.borderHover : Color.clear, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Tools Panel

    private var pdfToolsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FERRAMENTAS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.horizontal, 2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(PDFAnnotationTool.allCases, id: \.self) { tool in
                    pdfToolCard(tool)
                }
            }
        }
        .padding(14)
        .background(panelBackground)
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    private func pdfToolCard(_ tool: PDFAnnotationTool) -> some View {
        let isSelected = controller.selectedTool == tool
        return Button {
            controller.selectedTool = tool
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { activePanel = nil }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                              : Color.clear)
                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isSelected
                                         ? (tool == .draw ? controller.inkColor : AppTheme.accent)
                                         : AppTheme.textMuted)
                }
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? AppTheme.borderHover : Color.clear, lineWidth: 1.5))

                Text(tool.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .padding(.vertical, 6).padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Color Panel

    private var pdfColorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COR")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(toolkitColors, id: \.1) { entry in pdfColorSwatch(entry) }
            }
        }
        .padding(14)
        .background(panelBackground)
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    private func pdfColorSwatch(_ entry: (Color, String)) -> some View {
        let isWhite = entry.1 == "Branco"
        let isSelected: Bool = {
            guard let ui1 = UIColor(entry.0).cgColor.components,
                  let ui2 = UIColor(controller.inkColor).cgColor.components else { return false }
            let t: CGFloat = 0.05
            return abs((ui1[safe: 0] ?? 0) - (ui2[safe: 0] ?? 0)) < t &&
                   abs((ui1[safe: 1] ?? 0) - (ui2[safe: 1] ?? 0)) < t &&
                   abs((ui1[safe: 2] ?? 0) - (ui2[safe: 2] ?? 0)) < t
        }()

        return Button { controller.inkColor = entry.0 } label: {
            ZStack {
                if isWhite {
                    CheckerboardView().clipShape(RoundedRectangle(cornerRadius: 7)).frame(width: 32, height: 32)
                }
                RoundedRectangle(cornerRadius: 7)
                    .fill(entry.0).frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? Color.blue : AppTheme.border.opacity(0.4),
                                lineWidth: isSelected ? 2.5 : 1))
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

    // MARK: Width Panel

    private var pdfWidthPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ESPESSURA")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Text(String(format: "%.0f pt", controller.lineWidth))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(AppTheme.background).frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                HorizontalLine()
                    .stroke(controller.inkColor,
                            style: StrokeStyle(lineWidth: min(controller.lineWidth, 20), lineCap: .round))
                    .frame(height: min(controller.lineWidth, 20))
                    .padding(.horizontal, 20)
            }

            GeometryReader { geo in
                let minW: CGFloat = 1, maxW: CGFloat = 20
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.background).frame(height: 8)
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                    let fraction = (controller.lineWidth - minW) / (maxW - minW)
                    let trackW = min(max(fraction * geo.size.width, 0), geo.size.width)
                    Capsule()
                        .fill(LinearGradient(colors: [controller.inkColor.opacity(0.6), controller.inkColor],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: trackW, height: 8)
                    let thumbX = fraction * (geo.size.width - 24) + 12
                    Circle().fill(Color.white).frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                        .offset(x: thumbX - 12)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let raw = (value.location.x - 12) / (geo.size.width - 24)
                            controller.lineWidth = minW + min(max(raw, 0), 1) * (maxW - minW)
                        })
                }
            }
            .frame(height: 24)

            HStack(spacing: 8) {
                ForEach([1, 3, 6, 10, 16, 20] as [CGFloat], id: \.self) { w in
                    let isSel = abs(controller.lineWidth - w) < 0.5
                    Button { controller.lineWidth = w } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(isSel ? controller.inkColor : AppTheme.textMuted)
                                .frame(width: min(max(w / 20 * 22, 3), 22),
                                       height: min(max(w / 20 * 22, 3), 22))
                                .frame(height: 22)
                            Text(String(format: "%.0f", w))
                                .font(.system(size: 9, weight: isSel ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(isSel ? AppTheme.textPrimary : AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(isSel ? AppTheme.background : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(isSel ? AppTheme.borderHover : Color.clear, lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(panelBackground)
        .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 4)
    }

    private var pdfWidthPreviewButton: some View {
        let w = controller.lineWidth
        let dotSize = min(max(w / 20 * 22, 3), 22)
        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(activePanel == .width ? AppTheme.background : AppTheme.surfaceElevated)
                .frame(width: 38, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(activePanel == .width ? AppTheme.borderHover : AppTheme.border, lineWidth: 1))
            Circle().fill(controller.inkColor).frame(width: dotSize, height: dotSize)
        }
    }

    private var collapsedPill: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { expanded = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isDrawActive ? controller.penStyle.icon : controller.selectedTool.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDrawActive ? controller.inkColor : AppTheme.textSecondary)
                if isDrawActive {
                    Circle().fill(controller.inkColor).frame(width: 8, height: 8)
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(AppTheme.surface).overlay(Capsule().stroke(AppTheme.borderHover, lineWidth: 1)))
            .shadow(color: AppTheme.shadowColor, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.borderHover, lineWidth: 1))
    }

    private var pdfDivider: some View {
        Rectangle().fill(AppTheme.border).frame(width: 1, height: 22).padding(.horizontal, 6)
    }

    private func barButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private func togglePanel(_ panel: ActivePanel) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activePanel = activePanel == panel ? nil : panel
        }
    }
}

// MARK: - PDFDrawingOverlayView
//
// UIView subclass that handles drawing directly via touch events.
// Advantages over UIPanGestureRecognizer:
//   - Access to coalesced touches (event.coalescedTouches) — fills in all touch samples
//     between frames, so fast strokes don't skip points.
//   - Access to predicted touches (event.predictedTouches) — shown in the live CAShapeLayer
//     preview so the stroke visually "leads" the finger for zero-perceived-latency.
//   - preciseLocation(in:) — sub-pixel accuracy for Apple Pencil.
//
// The live preview is a CAShapeLayer on this view. On touch end, the accurate path
// (coalesced only, no predictions) is committed as a PDF ink annotation using
// pdfView.convert(_:to:) — the same coordinate transform used in the original working code.

final class PDFDrawingOverlayView: UIView {
    weak var pdfView: PDFView?
    var inkColor: UIColor = .black
    var lineWidth: CGFloat = 4
    var penStyle: PDFPenStyle = .pen
    var onAnnotationAdded: (() -> Void)?

    // Accurate path in PDF page coordinates — committed to PDF on touch end
    private var pdfPath: UIBezierPath?
    // View-space path for the live CAShapeLayer preview
    private var previewPath: UIBezierPath?
    private var activePage: PDFPage?
    private var activeTouch: UITouch?
    private var liveLayer: CAShapeLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let pdfView else { return }
        activeTouch = touch

        // Locate the PDF page at the touch point
        let viewPt = touch.preciseLocation(in: pdfView)
        guard let page = pdfView.page(for: viewPt, nearest: true) else { return }
        activePage = page

        let pagePt = pdfView.convert(viewPt, to: page)

        // Start PDF path (page coordinates)
        let path = UIBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: pagePt)
        pdfPath = path

        // Start preview path (view/screen coordinates)
        let preview = UIBezierPath()
        preview.lineCapStyle = .round
        preview.lineJoinStyle = .round
        preview.move(to: touch.preciseLocation(in: self))
        previewPath = preview

        startLiveLayer()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              touch === activeTouch,
              let pdfView,
              let page = activePage,
              let event else { return }

        // Coalesced touches: all touch samples between the last frame and this one.
        // Using them prevents skipped points on fast strokes — this is the main
        // reason the previous approach felt "lerdo".
        let coalesced = event.coalescedTouches(for: touch) ?? [touch]
        for t in coalesced {
            let viewPt = t.preciseLocation(in: pdfView)
            pdfPath?.addLine(to: pdfView.convert(viewPt, to: page))
            previewPath?.addLine(to: t.preciseLocation(in: self))
        }

        // Predicted touches: future positions estimated by the OS — only for the visual
        // preview so the stroke appears ahead of the finger. NOT added to pdfPath.
        var displayPath = previewPath?.copy() as? UIBezierPath ?? UIBezierPath()
        if let predicted = event.predictedTouches(for: touch) {
            for t in predicted {
                displayPath.addLine(to: t.preciseLocation(in: self))
            }
        }

        updateLiveLayer(path: displayPath)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch === activeTouch else { return }
        commitStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearLiveLayer()
        resetState()
    }

    private func commitStroke() {
        defer { clearLiveLayer(); resetState() }

        guard let page = activePage, let path = pdfPath else { return }

        // A single tap produces a path with only a move and no lines — add a tiny segment
        // so the bounds are non-zero and the dot is visible as an annotation.
        if path.isEmpty {
            let current = path.currentPoint
            guard current != .zero else { return }
            path.addLine(to: CGPoint(x: current.x + 0.01, y: current.y + 0.01))
        }

        let rawBounds = path.bounds
        guard rawBounds != .null else { return }

        let effectiveWidth = lineWidth * penStyle.lineWidthMultiplier
        let bounds = rawBounds.insetBy(dx: -(effectiveWidth * 2 + 2), dy: -(effectiveWidth * 2 + 2))
        guard bounds.width > 0, bounds.height > 0 else { return }

        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = inkColor.withAlphaComponent(penStyle.annotationOpacity)
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = effectiveWidth

        // Translate path to annotation-local coordinates (origin = bounds.origin in page space)
        let local = path.copy() as! UIBezierPath
        local.apply(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
        annotation.add(local)
        page.addAnnotation(annotation)

        onAnnotationAdded?()
    }

    private func startLiveLayer() {
        liveLayer?.removeFromSuperlayer()
        let l = CAShapeLayer()
        l.frame = bounds
        l.fillColor = UIColor.clear.cgColor
        l.strokeColor = inkColor.withAlphaComponent(penStyle.annotationOpacity).cgColor
        l.lineWidth = lineWidth * penStyle.lineWidthMultiplier
        l.lineCap = .round
        l.lineJoin = .round
        l.zPosition = 999
        layer.addSublayer(l)
        liveLayer = l
    }

    private func updateLiveLayer(path: UIBezierPath) {
        liveLayer?.strokeColor = inkColor.withAlphaComponent(penStyle.annotationOpacity).cgColor
        liveLayer?.lineWidth = lineWidth * penStyle.lineWidthMultiplier
        liveLayer?.path = path.cgPath
    }

    private func clearLiveLayer() {
        liveLayer?.removeFromSuperlayer()
        liveLayer = nil
    }

    private func resetState() {
        pdfPath = nil
        previewPath = nil
        activePage = nil
        activeTouch = nil
    }
}

// MARK: - PDFEditorRepresentable

struct PDFEditorRepresentable: UIViewRepresentable {
    let documentURL: URL
    @ObservedObject var controller: PDFEditorController
    let onDocumentChanged: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        // PDF view
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        if let doc = PDFDocument(url: documentURL) { pdfView.document = doc }

        // Drawing overlay — handles touches directly for smooth drawing with coalesced/predicted touches
        let drawView = PDFDrawingOverlayView()
        drawView.backgroundColor = .clear
        drawView.isUserInteractionEnabled = false
        drawView.translatesAutoresizingMaskIntoConstraints = false
        drawView.pdfView = pdfView
        drawView.onAnnotationAdded = { [weak controller] in
            controller?.scheduleSave()
        }

        container.addSubview(pdfView)
        container.addSubview(drawView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            drawView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            drawView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            drawView.topAnchor.constraint(equalTo: container.topAnchor),
            drawView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        controller.pdfView = pdfView
        controller.saveHandler = { [weak pdfView] in
            guard let data = pdfView?.document?.dataRepresentation() else { return }
            onDocumentChanged(data)
        }

        let coord = context.coordinator
        coord.pdfView = pdfView
        coord.drawingOverlay = drawView

        // Tap for note/erase
        let tap = UITapGestureRecognizer(target: coord, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = coord
        pdfView.addGestureRecognizer(tap)
        coord.tapRecognizer = tap

        // Pan for continuous erase
        let erasePan = UIPanGestureRecognizer(target: coord, action: #selector(Coordinator.handleErasePan(_:)))
        erasePan.delegate = coord
        pdfView.addGestureRecognizer(erasePan)
        coord.erasePanRecognizer = erasePan

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        context.coordinator.syncTool(
            tool: controller.selectedTool,
            penStyle: controller.penStyle,
            color: UIColor(controller.inkColor),
            lineWidth: controller.lineWidth
        )
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let controller: PDFEditorController
        weak var pdfView: PDFView?
        weak var drawingOverlay: PDFDrawingOverlayView?
        var tapRecognizer: UITapGestureRecognizer?
        var erasePanRecognizer: UIPanGestureRecognizer?

        private var currentTool: PDFAnnotationTool = .select

        init(controller: PDFEditorController) { self.controller = controller }

        func syncTool(tool: PDFAnnotationTool, penStyle: PDFPenStyle, color: UIColor, lineWidth: CGFloat) {
            currentTool = tool
            let isDrawing = tool == .draw
            drawingOverlay?.isUserInteractionEnabled = isDrawing
            drawingOverlay?.inkColor = color
            drawingOverlay?.lineWidth = lineWidth
            drawingOverlay?.penStyle = penStyle

            tapRecognizer?.isEnabled = (tool == .note || tool == .erase)
            erasePanRecognizer?.isEnabled = (tool == .erase)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView,
                  let page = pdfView.page(for: gesture.location(in: pdfView), nearest: true) else { return }
            let pt = pdfView.convert(gesture.location(in: pdfView), to: page)

            switch currentTool {
            case .note:
                let note = PDFAnnotation(
                    bounds: CGRect(x: pt.x, y: pt.y, width: 28, height: 28),
                    forType: .text, withProperties: nil
                )
                note.contents = "Nova nota"
                note.color = UIColor.systemYellow.withAlphaComponent(0.9)
                page.addAnnotation(note)
                controller.scheduleSave()
            case .erase:
                removeAnnotation(at: pt, on: page)
            default:
                break
            }
        }

        @objc func handleErasePan(_ gesture: UIPanGestureRecognizer) {
            guard currentTool == .erase, let pdfView else { return }
            let viewPt = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: viewPt, nearest: true) else { return }
            removeAnnotation(at: pdfView.convert(viewPt, to: page), on: page)
        }

        private func removeAnnotation(at point: CGPoint, on page: PDFPage) {
            if let ann = page.annotations.reversed().first(where: {
                $0.bounds.insetBy(dx: -10, dy: -10).contains(point)
            }) {
                page.removeAnnotation(ann)
                controller.scheduleSave()
            }
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            if gr == erasePanRecognizer || other == erasePanRecognizer { return false }
            return true
        }
    }
}
