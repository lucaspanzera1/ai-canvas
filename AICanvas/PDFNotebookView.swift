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

// MARK: - PDFEditorController

final class PDFEditorController: ObservableObject {
    @Published var selectedTool: PDFAnnotationTool = .select
    @Published var inkColor: Color = .black
    @Published var lineWidth: CGFloat = 4

    weak var pdfView: PDFView?
    var saveHandler: (() -> Void)?

    private var pendingSave: DispatchWorkItem?

    func applyHighlightToSelection() {
        guard let pdfView = pdfView,
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
        let work = DispatchWorkItem { [weak self] in
            self?.saveHandler?()
        }
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

    private var pdfURL: URL? {
        store.pdfDocumentURL(for: notebook)
    }

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
                        if let url = pdfURL {
                            urlToExport = url
                        }
                    }
                )

                if let pdfURL {
                    ZStack(alignment: .bottom) {
                        PDFEditorRepresentable(documentURL: pdfURL, controller: controller) { data in
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
                AIChatPanelView(
                    viewModel: chatViewModel,
                    aiConfig: aiConfig,
                    isVisible: $showAIPanel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showAIPanel)
        .background(AppTheme.background)
        .onDisappear {
            controller.flushSave()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            MultiProviderOnboardingView(
                isPresented: $showOnboarding,
                aiConfig: aiConfig
            )
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showSidebar = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Cadernos")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(notebook.emoji)
                    .font(.system(size: 16))

                Text(notebook.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            ToolButtonSimple(
                icon: "square.and.arrow.up",
                isDisabled: false,
                color: AppTheme.action,
                action: onExport
            )

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 20)
                .padding(.horizontal, 8)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showAIPanel.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAIPanel ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                        .font(.system(size: 14, weight: .medium))
                    Text(showAIPanel ? "Fechar IA" : "Abrir IA")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(showAIPanel ? .white : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(showAIPanel ? AppTheme.accent : AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(showAIPanel ? Color.clear : AppTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    enum ActivePanel: Equatable {
        case color, width, tools
    }

    private var isDrawActive: Bool { controller.selectedTool == .draw }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                Group {
                    if activePanel == .tools {
                        pdfToolsPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if activePanel == .color {
                        pdfColorPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if activePanel == .width {
                        pdfWidthPanel
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
    }

    // MARK: - Main Bar

    private var mainBar: some View {
        HStack(spacing: 0) {
            // Collapse
            barButton(icon: "chevron.down", tint: AppTheme.textMuted) {
                withAnimation(.spring(response: 0.3)) { expanded = false }
            }

            pdfDivider

            // Highlight button (action, not a mode)
            Button {
                controller.applyHighlightToSelection()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.yellow)
                        .frame(height: 18)
                    Text("Grifar")
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            pdfDivider

            // Tool selector
            Button {
                togglePanel(.tools)
            } label: {
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

            pdfDivider

            // Color swatch (only when drawing)
            if isDrawActive {
                Button {
                    togglePanel(.color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(controller.inkColor)
                            .frame(width: 28, height: 28)
                            .shadow(color: controller.inkColor.opacity(0.6),
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

                // Width preview
                Button {
                    togglePanel(.width)
                } label: {
                    pdfWidthPreviewButton
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
            }
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
            if activePanel == .tools {
                // Close tools panel after selection
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? (colorScheme == .dark
                                 ? Color.white.opacity(0.06)
                                 : Color.black.opacity(0.04))
                              : Color.clear)

                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isSelected
                                         ? (tool == .draw ? controller.inkColor : AppTheme.accent)
                                         : AppTheme.textMuted)
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

    // MARK: - Color Panel

    private var pdfColorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COR")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(toolkitColors, id: \.1) { entry in
                    pdfColorSwatch(entry)
                }
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
                  let ui2 = UIColor(controller.inkColor).cgColor.components
            else { return false }
            let threshold: CGFloat = 0.05
            return abs((ui1[safe: 0] ?? 0) - (ui2[safe: 0] ?? 0)) < threshold &&
                   abs((ui1[safe: 1] ?? 0) - (ui2[safe: 1] ?? 0)) < threshold &&
                   abs((ui1[safe: 2] ?? 0) - (ui2[safe: 2] ?? 0)) < threshold
        }()

        return Button {
            controller.inkColor = entry.0
        } label: {
            ZStack {
                if isWhite {
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

    // MARK: - Width Panel

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
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.background)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )

                HorizontalLine()
                    .stroke(
                        controller.inkColor,
                        style: StrokeStyle(
                            lineWidth: min(controller.lineWidth, 20),
                            lineCap: .round
                        )
                    )
                    .frame(height: min(controller.lineWidth, 20))
                    .padding(.horizontal, 20)
            }

            GeometryReader { geo in
                let minW: CGFloat = 1
                let maxW: CGFloat = 12
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.background)
                        .frame(height: 8)
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))

                    let fraction = (controller.lineWidth - minW) / (maxW - minW)
                    let trackWidth = min(max(fraction * geo.size.width, 0), geo.size.width)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [controller.inkColor.opacity(0.6), controller.inkColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: trackWidth, height: 8)

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
                                    controller.lineWidth = minW + clamped * (maxW - minW)
                                }
                        )
                }
            }
            .frame(height: 24)

            HStack(spacing: 8) {
                ForEach([1, 3, 6, 10, 12] as [CGFloat], id: \.self) { w in
                    let isSel = abs(controller.lineWidth - w) < 0.5
                    Button {
                        controller.lineWidth = w
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(isSel ? controller.inkColor : AppTheme.textMuted)
                                .frame(
                                    width: min(max(w / 12 * 22, 3), 22),
                                    height: min(max(w / 12 * 22, 3), 22)
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

    // MARK: - Width preview button

    private var pdfWidthPreviewButton: some View {
        let w = controller.lineWidth
        let dotSize = min(max(w / 12 * 22, 3), 22)

        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(activePanel == .width ? AppTheme.background : AppTheme.surfaceElevated)
                .frame(width: 38, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(activePanel == .width ? AppTheme.borderHover : AppTheme.border, lineWidth: 1)
                )

            Circle()
                .fill(controller.inkColor)
                .frame(width: dotSize, height: dotSize)
        }
    }

    // MARK: - Collapsed Pill

    private var collapsedPill: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { expanded = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: controller.selectedTool.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDrawActive ? controller.inkColor : AppTheme.textSecondary)

                if isDrawActive {
                    Circle()
                        .fill(controller.inkColor)
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

    // MARK: - Helpers

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.borderHover, lineWidth: 1)
            )
    }

    private var pdfDivider: some View {
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

    private func togglePanel(_ panel: ActivePanel) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activePanel = activePanel == panel ? nil : panel
        }
    }
}

// MARK: - PDFEditorRepresentable

struct PDFEditorRepresentable: UIViewRepresentable {
    let documentURL: URL
    @ObservedObject var controller: PDFEditorController
    let onDocumentChanged: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView(frame: .zero)
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .secondarySystemBackground

        if let document = PDFDocument(url: documentURL) {
            pdfView.document = document
        }

        controller.pdfView = pdfView
        controller.saveHandler = { [weak pdfView] in
            guard let data = pdfView?.document?.dataRepresentation() else { return }
            onDocumentChanged(data)
        }

        context.coordinator.configureGestures(for: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.updateTool(controller.selectedTool)
        context.coordinator.updateInk(color: UIColor(controller.inkColor), width: controller.lineWidth)
    }

    final class Coordinator: NSObject {
        private let controller: PDFEditorController

        private weak var pdfView: PDFView?
        private var currentTool: PDFAnnotationTool = .select
        private var inkColor: UIColor = .systemYellow
        private var lineWidth: CGFloat = 4

        private let drawPanRecognizer = UIPanGestureRecognizer()
        private let tapRecognizer = UITapGestureRecognizer()

        private var activePath: UIBezierPath?
        private var activeViewPath: UIBezierPath?
        private weak var activePage: PDFPage?
        private var liveStrokeLayer: CAShapeLayer?
        private var lastViewPoint: CGPoint?

        init(controller: PDFEditorController) {
            self.controller = controller
            super.init()
            drawPanRecognizer.addTarget(self, action: #selector(handleDrawPan(_:)))
            drawPanRecognizer.maximumNumberOfTouches = 1
            tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        }

        func configureGestures(for pdfView: PDFView) {
            self.pdfView = pdfView
            drawPanRecognizer.delegate = self
            tapRecognizer.delegate = self
            pdfView.addGestureRecognizer(drawPanRecognizer)
            pdfView.addGestureRecognizer(tapRecognizer)
        }

        func updateTool(_ tool: PDFAnnotationTool) {
            currentTool = tool
            drawPanRecognizer.isEnabled = (tool == .draw)
            tapRecognizer.isEnabled = (tool == .note || tool == .erase)
            setNavigationEnabled(tool != .draw)
            if tool != .draw {
                clearLiveStrokeLayer()
            }
        }

        func updateInk(color: UIColor, width: CGFloat) {
            inkColor = color
            lineWidth = width
        }

        private func setNavigationEnabled(_ isEnabled: Bool) {
            guard let pdfView else { return }
            allScrollViews(in: pdfView).forEach { $0.isScrollEnabled = isEnabled }
        }

        private func allScrollViews(in root: UIView) -> [UIScrollView] {
            var result: [UIScrollView] = []
            for child in root.subviews {
                if let scroll = child as? UIScrollView {
                    result.append(scroll)
                }
                result.append(contentsOf: allScrollViews(in: child))
            }
            return result
        }

        @objc private func handleDrawPan(_ gesture: UIPanGestureRecognizer) {
            guard currentTool == .draw,
                  let pdfView = pdfView else { return }

            let viewPoint = gesture.location(in: pdfView)

            switch gesture.state {
            case .began:
                guard let page = pdfView.page(for: viewPoint, nearest: true) else { return }
                activePage = page
                let pagePoint = pdfView.convert(viewPoint, to: page)
                let path = UIBezierPath()
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: pagePoint)
                activePath = path

                let viewPath = UIBezierPath()
                viewPath.lineCapStyle = .round
                viewPath.lineJoinStyle = .round
                viewPath.move(to: viewPoint)
                activeViewPath = viewPath
                lastViewPoint = viewPoint
                startLiveStrokeLayer(in: pdfView)
                updateLiveStrokeLayerPath()

            case .changed:
                guard let page = activePage,
                      let path = activePath,
                      let viewPath = activeViewPath else { return }

                if let lastPoint = lastViewPoint {
                    let dx = viewPoint.x - lastPoint.x
                    let dy = viewPoint.y - lastPoint.y
                    if (dx * dx + dy * dy) < 0.25 {
                        return
                    }
                }

                let pagePoint = pdfView.convert(viewPoint, to: page)
                path.addLine(to: pagePoint)
                viewPath.addLine(to: viewPoint)
                lastViewPoint = viewPoint
                updateLiveStrokeLayerPath()

            case .ended, .cancelled:
                guard let page = activePage,
                      let path = activePath else {
                    activePath = nil
                    activeViewPath = nil
                    activePage = nil
                    lastViewPoint = nil
                    clearLiveStrokeLayer()
                    return
                }

                let bounds = path.bounds.insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2)
                let inkAnnotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
                inkAnnotation.color = inkColor
                inkAnnotation.border = PDFBorder()
                inkAnnotation.border?.lineWidth = lineWidth

                let localPath = path.copy() as? UIBezierPath ?? path
                localPath.apply(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
                inkAnnotation.add(localPath)
                page.addAnnotation(inkAnnotation)

                controller.scheduleSave()
                activePath = nil
                activeViewPath = nil
                activePage = nil
                lastViewPoint = nil
                clearLiveStrokeLayer()

            default:
                break
            }
        }

        private func startLiveStrokeLayer(in pdfView: PDFView) {
            if let existing = liveStrokeLayer {
                existing.removeFromSuperlayer()
            }

            let layer = CAShapeLayer()
            layer.frame = pdfView.bounds
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = inkColor.cgColor
            layer.lineWidth = lineWidth
            layer.lineCap = .round
            layer.lineJoin = .round
            layer.zPosition = 999
            pdfView.layer.addSublayer(layer)
            liveStrokeLayer = layer
        }

        private func updateLiveStrokeLayerPath() {
            liveStrokeLayer?.strokeColor = inkColor.cgColor
            liveStrokeLayer?.lineWidth = lineWidth
            liveStrokeLayer?.path = activeViewPath?.cgPath
        }

        private func clearLiveStrokeLayer() {
            liveStrokeLayer?.removeFromSuperlayer()
            liveStrokeLayer = nil
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView,
                  let page = pdfView.page(for: gesture.location(in: pdfView), nearest: true) else { return }

            let pointInView = gesture.location(in: pdfView)
            let pointInPage = pdfView.convert(pointInView, to: page)

            switch currentTool {
            case .note:
                let noteBounds = CGRect(x: pointInPage.x, y: pointInPage.y, width: 28, height: 28)
                let note = PDFAnnotation(bounds: noteBounds, forType: .text, withProperties: nil)
                note.contents = "Nova nota"
                note.color = UIColor.systemYellow.withAlphaComponent(0.9)
                page.addAnnotation(note)
                controller.scheduleSave()

            case .erase:
                if let annotation = page.annotations.reversed().first(where: { annotation in
                    annotation.bounds.insetBy(dx: -8, dy: -8).contains(pointInPage)
                }) {
                    page.removeAnnotation(annotation)
                    controller.scheduleSave()
                }

            default:
                break
            }
        }
    }
}

extension PDFEditorRepresentable.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == drawPanRecognizer || otherGestureRecognizer == drawPanRecognizer {
            return false
        }
        return true
    }
}
