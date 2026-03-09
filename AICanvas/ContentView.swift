import SwiftUI
import PencilKit

// MARK: - Game Theme

struct GameTheme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.12)
    static let surface = Color(red: 0.08, green: 0.08, blue: 0.18)
    static let surfaceElevated = Color(red: 0.11, green: 0.11, blue: 0.22)
    static let neonPurple = Color(red: 0.58, green: 0.22, blue: 1.0)
    static let neonCyan = Color(red: 0.0, green: 0.85, blue: 1.0)
    static let neonGreen = Color(red: 0.18, green: 1.0, blue: 0.58)
    static let neonPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    static let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textMuted = Color(white: 0.4)
    static let border = Color(white: 1.0, opacity: 0.08)
    static let borderGlow = Color(red: 0.58, green: 0.22, blue: 1.0).opacity(0.5)

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [neonPurple, neonCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [neonPurple.opacity(0.8), neonPink.opacity(0.6), neonCyan.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ContentView: View {
    @StateObject private var canvasManager = CanvasManager()
    @StateObject private var aiConfig = AIConfiguration()
    @StateObject private var chatViewModel: ChatViewModel
    @State private var showAIPanel = false
    @State private var showOnboarding: Bool

    init() {
        let config = AIConfiguration()
        _aiConfig = StateObject(wrappedValue: config)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(aiConfig: config))
        _showOnboarding = State(initialValue: !KeychainManager.shared.hasAnyAPIKey)
    }

    var body: some View {
        ZStack {
            GameTheme.background
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Canvas area
                VStack(spacing: 0) {
                    CanvasToolbar(
                        canvasManager: canvasManager,
                        showAIPanel: $showAIPanel
                    )

                    ZStack(alignment: .bottom) {
                        CanvasRepresentable(
                            canvasManager: canvasManager,
                            showToolPicker: .constant(false)
                        )
                        .ignoresSafeArea(edges: .bottom)

                        // Gamified drawing toolbar (flutua sobre o canvas)
                        GameDrawingToolbar(canvasManager: canvasManager)
                            .padding(.bottom, 28)
                            .padding(.leading, 20)
                            .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
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
        .fullScreenCover(isPresented: $showOnboarding) {
            MultiProviderOnboardingView(
                isPresented: $showOnboarding,
                aiConfig: aiConfig
            )
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
    @ObservedObject var canvasManager: CanvasManager
    @Binding var showAIPanel: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Logo
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(GameTheme.primaryGradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("AI Canvas")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 4) {
                GameToolButton(
                    icon: "arrow.uturn.backward",
                    isDisabled: !canvasManager.canUndo,
                    color: GameTheme.neonCyan
                ) {
                    canvasManager.undo()
                }

                GameToolButton(
                    icon: "arrow.uturn.forward",
                    isDisabled: !canvasManager.canRedo,
                    color: GameTheme.neonCyan
                ) {
                    canvasManager.redo()
                }

                GameToolButton(
                    icon: "trash",
                    isDisabled: false,
                    color: GameTheme.neonPink
                ) {
                    canvasManager.clearCanvas()
                }

                GameToolButton(
                    icon: "square.and.arrow.up",
                    isDisabled: false,
                    color: GameTheme.neonGreen
                ) {
                    canvasManager.exportDrawing()
                }
            }

            Rectangle()
                .fill(GameTheme.border)
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            // AI Panel Toggle
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showAIPanel.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAIPanel ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                        .font(.system(size: 14, weight: .semibold))
                    Text(showAIPanel ? "Fechar IA" : "Abrir IA")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(showAIPanel ? GameTheme.background : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if showAIPanel {
                            AnyView(GameTheme.primaryGradient)
                        } else {
                            AnyView(GameTheme.surfaceElevated)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            showAIPanel ? Color.clear : GameTheme.neonPurple.opacity(0.5),
                            lineWidth: 1
                        )
                )
                .shadow(color: showAIPanel ? GameTheme.neonPurple.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            GameTheme.surface
                .ignoresSafeArea(edges: .top)
        )
        .overlay(
            Rectangle()
                .fill(GameTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Game Tool Button

struct GameToolButton: View {
    let icon: String
    let isDisabled: Bool
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { isPressed = false }
            }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isDisabled ? GameTheme.textMuted : color)
                .frame(width: 36, height: 36)
                .background(
                    isPressed
                    ? color.opacity(0.2)
                    : GameTheme.surfaceElevated
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isPressed ? color.opacity(0.5) : GameTheme.border, lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    ContentView()
}
