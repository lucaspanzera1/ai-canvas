import SwiftUI
import PencilKit

// MARK: - App Theme

/// Monochrome, square-cornered design system. Every surface is flat, every edge is a
/// 1pt hairline, and hierarchy comes from contrast and type — never from color or depth.
struct AppTheme {
    static let background = Color(light: 0xFAFAFA, dark: 0x0A0A0A)
    static let surface = Color(light: 0xFFFFFF, dark: 0x000000)
    static let surfaceElevated = Color(light: 0xF2F2F2, dark: 0x141414)
    static let accent = Color(light: 0x0A0A0A, dark: 0xFAFAFA)
    /// Foreground drawn on top of `accent` (inverted fills).
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x000000)
    static let action = accent
    static let danger = accent

    static let textPrimary = Color(light: 0x0A0A0A, dark: 0xFAFAFA)
    static let textSecondary = Color(light: 0x6B6B6B, dark: 0x9A9A9A)
    static let textMuted = Color(light: 0xA3A3A3, dark: 0x5C5C5C)

    static let border = Color(light: 0xE3E3E3, dark: 0x262626)
    static let borderHover = Color(light: 0xA3A3A3, dark: 0x525252)
    static let borderActive = accent

    static let shadowColor = Color.clear
    static let link = accent

    static let hairline: CGFloat = 1
    static let motion = Animation.easeOut(duration: 0.18)

    /// Small uppercase monospaced caption used for section headers and metadata.
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
}

extension View {
    @ViewBuilder
    func colorInvert(_ active: Bool) -> some View {
        if active { colorInvert() } else { self }
    }

    /// Square 1pt outline — the base edge treatment for every container.
    func hairline(_ color: Color = AppTheme.border, width: CGFloat = AppTheme.hairline) -> some View {
        overlay(Rectangle().strokeBorder(color, lineWidth: width))
    }
}

/// `TRACKED MONO` caption.
struct SectionLabel: View {
    let text: String
    var color: Color = AppTheme.textMuted
    @ObservedObject private var localization = LocalizationManager.shared

    init(_ text: String, color: Color = AppTheme.textMuted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.localized.uppercased())
            .font(AppTheme.label())
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Flat, square button. `.primary` is an inverted solid block; `.secondary` is outlined;
/// `.ghost` has no chrome until pressed. Pressing inverts briefly instead of scaling.
struct MonoButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .secondary
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        MonoButtonBody(configuration: configuration, kind: kind, fullWidth: fullWidth)
    }

    private struct MonoButtonBody: View {
        let configuration: Configuration
        let kind: Kind
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .foregroundStyle(foreground(pressed))
                .background(background(pressed))
                .hairline(kind == .ghost && !pressed ? .clear : (isEnabled ? AppTheme.accent : AppTheme.border))
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.5)
        }

        private func foreground(_ pressed: Bool) -> Color {
            guard isEnabled else { return AppTheme.textMuted }
            switch kind {
            case .primary: return pressed ? AppTheme.textPrimary : AppTheme.onAccent
            case .secondary, .ghost: return pressed ? AppTheme.onAccent : AppTheme.textPrimary
            }
        }

        private func background(_ pressed: Bool) -> Color {
            guard isEnabled else { return .clear }
            switch kind {
            case .primary: return pressed ? AppTheme.surface : AppTheme.accent
            case .secondary, .ghost: return pressed ? AppTheme.accent : .clear
            }
        }
    }
}

/// 32×32 square icon button used in toolbars and headers.
struct SquareIconButton: View {
    let icon: String
    var isActive = false
    var isDisabled = false
    var size: CGFloat = 32
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isDisabled ? AppTheme.textMuted : (isActive ? AppTheme.onAccent : AppTheme.textPrimary))
                .frame(width: size, height: size)
                .background(isActive ? AppTheme.accent : (isHovered && !isDisabled ? AppTheme.surfaceElevated : AppTheme.surface))
                .hairline(isActive || (isHovered && !isDisabled) ? AppTheme.accent : AppTheme.border)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Content View (Canvas for a specific notebook)

struct ContentView: View {
    let notebook: Notebook
    @ObservedObject var store: NotebookStore
    @ObservedObject var syncManager: SyncManager
    @Binding var selectedNotebook: Notebook?
    @Binding var showSidebar: Bool

    @StateObject private var aiConfig = AIConfiguration()
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var canvasManager: CanvasManager

    @State private var showAIPanel = false
    @State private var showOnboarding: Bool
    @State private var backgroundPattern: BackgroundPattern
    @State private var showImageSourceMenu = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showResizeDialog = false
    @State private var imageToResize: DraggableImageView?
    @State private var imageResizeSize: CGSize = .zero
    @State private var showClearCanvasAlert = false

    init(notebook: Notebook, store: NotebookStore, syncManager: SyncManager, selectedNotebook: Binding<Notebook?>, showSidebar: Binding<Bool>) {
        self.notebook = notebook
        self.store = store
        self.syncManager = syncManager
        self._selectedNotebook = selectedNotebook
        self._showSidebar = showSidebar

        let config = AIConfiguration()
        _aiConfig = StateObject(wrappedValue: config)
        let loadedMessages = store.loadChatHistory(for: notebook)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(aiConfig: config, initialMessages: loadedMessages))
        _showOnboarding = State(initialValue: !KeychainManager.shared.hasAnyAPIKey)
        _backgroundPattern = State(initialValue: notebook.backgroundPattern ?? .none)

        // Carrega o desenho salvo do caderno
        let drawing = store.loadDrawing(for: notebook)
        _canvasManager = StateObject(wrappedValue: CanvasManager(initialDrawing: drawing))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if notebook.type == .pdf {
                PDFNotebookView(
                    notebook: notebook,
                    store: store,
                    selectedNotebook: $selectedNotebook,
                    showSidebar: $showSidebar
                )
            } else {
                HStack(spacing: 0) {
                    // Canvas area
                    VStack(spacing: 0) {
                        CanvasToolbar(
                            notebook: notebook,
                            canvasManager: canvasManager,
                            syncManager: syncManager,
                            showAIPanel: $showAIPanel,
                            showSidebar: $showSidebar,
                            backgroundPattern: $backgroundPattern,
                            onPatternChange: { pattern in
                                backgroundPattern = pattern
                                store.updateNotebookPattern(notebook, to: pattern)
                            },
                            onBack: {
                                store.persistMetadata()
                                withAnimation(AppTheme.motion) {
                                    selectedNotebook = nil
                                }
                            },
                            showClearCanvasAlert: $showClearCanvasAlert
                        )

                        ZStack(alignment: .bottom) {
                            CanvasRepresentable(
                                canvasManager: canvasManager,
                                showToolPicker: .constant(false),
                                pattern: $backgroundPattern,
                                notebookType: notebook.type
                            )
                            .ignoresSafeArea(edges: .bottom)

                            // Full-featured drawing toolkit (ruler, lasso, opacity, all PencilKit tools)
                            DrawingToolkit(
                                canvasManager: canvasManager,
                                onInsertImageFromLibrary: { showPhotoPicker = true },
                                onInsertImageFromCamera: { showCamera = true },
                                onPasteImage: { canvasManager.pasteImageFromClipboard() }
                            )
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
                .animation(AppTheme.motion, value: showAIPanel)
            }
        }
        .onAppear {
            guard notebook.type != .pdf else { return }
            // Conecta o auto-save ao store
            canvasManager.onDrawingChange = { [weak store] drawing in
                store?.saveDrawing(drawing, for: notebook)
            }
            // Conecta o canvasManager ao viewModel para captura de visão
            chatViewModel.canvasManager = canvasManager
            // Conecta o callback de redimensionamento de imagem
            canvasManager.onImageShowResizeDialog = { imageView, size in
                self.imageToResize = imageView
                self.imageResizeSize = size
                self.showResizeDialog = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            MultiProviderOnboardingView(
                isPresented: $showOnboarding,
                aiConfig: aiConfig
            )
        }
        .sheet(item: Binding(
            get: { canvasManager.urlToExport.map { ExportableItem(item: $0) } },
            set: { if $0 == nil { canvasManager.urlToExport = nil } }
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
        .sheet(isPresented: $showPhotoPicker) {
            CanvasPhotoPickerView { image in
                canvasManager.insertImage(image)
            }
        }
        .sheet(isPresented: $showCamera) {
            CanvasCameraView { image in
                canvasManager.insertImage(image)
            }
        }
        .sheet(isPresented: $showResizeDialog) {
            if let imageView = imageToResize {
                ImageResizeDialogView(
                    initialSize: imageResizeSize,
                    onResize: { newSize in
                        imageView.applyNewSize(newSize)
                    },
                    onCancel: {}
                )
            }
        }
        .alert("Limpar Canvas", isPresented: $showClearCanvasAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Apagar Tudo", role: .destructive) {
                canvasManager.clearCanvas()
            }
        } message: {
            Text("Tem certeza que deseja apagar todo o conteúdo do canvas? Esta ação não pode ser desfeita.")
        }
        .statusBarHidden(false)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Top Toolbar

struct CanvasToolbar: View {
    let notebook: Notebook
    @ObservedObject var canvasManager: CanvasManager
    @ObservedObject var syncManager: SyncManager
    @Binding var showAIPanel: Bool
    @Binding var showSidebar: Bool
    @Binding var backgroundPattern: BackgroundPattern
    let onPatternChange: (BackgroundPattern) -> Void
    let onBack: () -> Void
    @Binding var showClearCanvasAlert: Bool

    private var isWhiteboard: Bool { notebook.type == .whiteboard }

    var body: some View {
        HStack(spacing: 0) {
            if !showSidebar {
                SquareIconButton(icon: "sidebar.left") {
                    withAnimation(AppTheme.motion) { showSidebar = true }
                }
                .padding(.trailing, 8)
            }

            // Back + breadcrumb
            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .regular))
                    Text(isWhiteboard ? "Quadros" : "Cadernos")
                        .font(.system(size: 13, weight: .regular))
                }
                .foregroundStyle(AppTheme.textSecondary)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("/")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.horizontal, 10)

            HStack(spacing: 8) {
                NoteIcon(icon: notebook.emoji, size: 14)
                Text(notebook.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons — joined into a single segmented strip
            HStack(spacing: -1) {
                SquareIconButton(icon: "arrow.uturn.backward", isDisabled: !canvasManager.canUndo) {
                    canvasManager.undo()
                }
                SquareIconButton(icon: "arrow.uturn.forward", isDisabled: !canvasManager.canRedo) {
                    canvasManager.redo()
                }
                SquareIconButton(icon: "trash") {
                    showClearCanvasAlert = true
                }

                if !isWhiteboard {
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
                        Image(systemName: "number")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surface)
                            .hairline()
                    }
                }

                SquareIconButton(icon: "square.and.arrow.up") {
                    canvasManager.exportDrawing(pattern: backgroundPattern)
                }
            }

            // Sync button (shows when notebook has changes or is syncing)
            let isSyncingThis = syncManager.syncingNotebooks.contains(notebook.id)
            let hasChanges = syncManager.notebookHasChanges(notebook)
            if SyncSettings.load().isConfigured && (hasChanges || isSyncingThis) {
                Button {
                    Task { await syncManager.syncNotebook(notebook) }
                } label: {
                    HStack(spacing: 6) {
                        if isSyncingThis {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Rectangle()
                                .fill(AppTheme.accent)
                                .frame(width: 5, height: 5)
                        }
                        Text("SYNC")
                            .font(AppTheme.label(11))
                            .tracking(1)
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .hairline()
                }
                .buttonStyle(.plain)
                .disabled(isSyncingThis)
                .padding(.leading, 8)
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 20)
                .padding(.horizontal, 12)

            // AI Panel Toggle
            Button {
                withAnimation(AppTheme.motion) { showAIPanel.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .regular))
                    Text(showAIPanel ? "Fechar IA" : "Abrir IA")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(showAIPanel ? AppTheme.onAccent : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(showAIPanel ? AppTheme.accent : AppTheme.surface)
                .hairline(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - Tool Button Simple

struct ToolButtonSimple: View {
    let icon: String
    let isDisabled: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        SquareIconButton(icon: icon, isDisabled: isDisabled, action: action)
    }
}

// MARK: - Previews

#Preview {
    let store = NotebookStore()
    ContentView(
        notebook: Notebook(name: "Preview", emoji: "✏️", colorIndex: 0),
        store: store,
        syncManager: SyncManager(store: store),
        selectedNotebook: .constant(nil),
        showSidebar: .constant(true)
    )
}
