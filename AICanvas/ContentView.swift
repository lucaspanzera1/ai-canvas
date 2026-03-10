import SwiftUI
import PencilKit

// MARK: - App Theme

struct AppTheme {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let surface = Color.white
    static let surfaceElevated = Color.white
    static let accent = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let action = Color(red: 0.2, green: 0.4, blue: 0.9)
    static let danger = Color(red: 0.9, green: 0.3, blue: 0.3)
    
    static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.4)
    static let textMuted = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    static let border = Color(red: 0.88, green: 0.88, blue: 0.88)
    static let borderHover = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let borderActive = Color(red: 0.1, green: 0.1, blue: 0.1)
    
    static let shadowColor = Color.black.opacity(0.04)
    static let link = Color(red: 0.2, green: 0.4, blue: 0.9)
}

// MARK: - Content View (Canvas for a specific notebook)

struct ContentView: View {
    let notebook: Notebook
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    @Binding var showSidebar: Bool

    @StateObject private var aiConfig = AIConfiguration()
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var canvasManager: CanvasManager

    @State private var showAIPanel = false
    @State private var showOnboarding: Bool
    @State private var backgroundPattern: BackgroundPattern

    init(notebook: Notebook, store: NotebookStore, selectedNotebook: Binding<Notebook?>, showSidebar: Binding<Bool>) {
        self.notebook = notebook
        self.store = store
        self._selectedNotebook = selectedNotebook
        self._showSidebar = showSidebar

        let config = AIConfiguration()
        _aiConfig = StateObject(wrappedValue: config)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(aiConfig: config))
        _showOnboarding = State(initialValue: !KeychainManager.shared.hasAnyAPIKey)
        _backgroundPattern = State(initialValue: notebook.backgroundPattern ?? .none)

        // Carrega o desenho salvo do caderno
        let drawing = store.loadDrawing(for: notebook)
        _canvasManager = StateObject(wrappedValue: CanvasManager(initialDrawing: drawing))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            HStack(spacing: 0) {
                // Canvas area
                VStack(spacing: 0) {
                    CanvasToolbar(
                        notebook: notebook,
                        canvasManager: canvasManager,
                        showAIPanel: $showAIPanel,
                        showSidebar: $showSidebar,
                        backgroundPattern: $backgroundPattern,
                        onPatternChange: { pattern in
                            backgroundPattern = pattern
                            store.updateNotebookPattern(notebook, to: pattern)
                        },
                        onBack: {
                            // Salva metadados ao sair
                            store.persistMetadata()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selectedNotebook = nil
                            }
                        }
                    )

                    ZStack(alignment: .bottom) {
                        CanvasRepresentable(
                            canvasManager: canvasManager,
                            showToolPicker: .constant(false),
                            pattern: $backgroundPattern
                        )
                        .ignoresSafeArea(edges: .bottom)

                        // Minimalist drawing toolbar
                        DrawingToolbar(canvasManager: canvasManager)
                            .padding(.bottom, 24)
                            .padding(.leading, 24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // AI Chat panel
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
        }
        .onAppear {
            // Conecta o auto-save ao store
            canvasManager.onDrawingChange = { [weak store] drawing in
                store?.saveDrawing(drawing, for: notebook)
            }
            // Conecta o canvasManager ao viewModel para captura de visão
            chatViewModel.canvasManager = canvasManager
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            MultiProviderOnboardingView(
                isPresented: $showOnboarding,
                aiConfig: aiConfig
            )
        }
        .sheet(item: Binding(
            get: { canvasManager.imageToExport.map { ExportableImage(image: $0) } },
            set: { if $0 == nil { canvasManager.imageToExport = nil } }
        )) { exportable in
            ShareSheet(image: exportable.image)
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyDidChange)) { _ in
            showOnboarding = true
            showAIPanel = false
            aiConfig.updateAvailableModels()
        }
        .statusBarHidden(false)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Top Toolbar

struct CanvasToolbar: View {
    let notebook: Notebook
    @ObservedObject var canvasManager: CanvasManager
    @Binding var showAIPanel: Bool
    @Binding var showSidebar: Bool
    @Binding var backgroundPattern: BackgroundPattern
    let onPatternChange: (BackgroundPattern) -> Void
    let onBack: () -> Void

    private var accentColor: Color { notebookSwiftColor(at: notebook.colorIndex) }

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
            
            // Back button
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

            // Notebook title
            HStack(spacing: 8) {
                Text(notebook.emoji)
                    .font(.system(size: 16))

                Text(notebook.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                ToolButtonSimple(
                    icon: "arrow.uturn.backward",
                    isDisabled: !canvasManager.canUndo,
                    color: AppTheme.textPrimary
                ) {
                    canvasManager.undo()
                }

                ToolButtonSimple(
                    icon: "arrow.uturn.forward",
                    isDisabled: !canvasManager.canRedo,
                    color: AppTheme.textPrimary
                ) {
                    canvasManager.redo()
                }

                ToolButtonSimple(
                    icon: "trash",
                    isDisabled: false,
                    color: AppTheme.danger
                ) {
                    canvasManager.clearCanvas()
                }

                // Linhas e grades Menu
                Menu {
                    ForEach(BackgroundPattern.allCases, id: \.self) { pattern in
                        Button {
                            onPatternChange(pattern)
                        } label: {
                            HStack {
                                Text(pattern.rawValue)
                                if backgroundPattern == pattern {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }

                ToolButtonSimple(
                    icon: "square.and.arrow.up",
                    isDisabled: false,
                    color: AppTheme.action
                ) {
                    canvasManager.exportDrawing()
                }
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 20)
                .padding(.horizontal, 8)

            // AI Panel Toggle
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

// MARK: - Tool Button Simple

struct ToolButtonSimple: View {
    let icon: String
    let isDisabled: Bool
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isDisabled ? AppTheme.textMuted : (isHovered ? color : AppTheme.textSecondary))
                .frame(width: 32, height: 32)
                .background(isHovered && !isDisabled ? AppTheme.background : AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered && !isDisabled ? AppTheme.borderHover : AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hover }
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView(
        notebook: Notebook(name: "Preview", emoji: "✏️", colorIndex: 0),
        store: NotebookStore(),
        selectedNotebook: .constant(nil),
        showSidebar: .constant(true)
    )
}
