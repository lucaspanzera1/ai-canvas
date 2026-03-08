import SwiftUI
import PencilKit

struct ContentView: View {
    @StateObject private var canvasManager = CanvasManager()
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var showToolPicker = true
    @State private var showAIPanel = false
    @State private var showOnboarding: Bool

    init() {
        _showOnboarding = State(initialValue: !KeychainManager.shared.hasAPIKey)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Main canvas area
                VStack(spacing: 0) {
                    CanvasToolbar(
                        canvasManager: canvasManager,
                        showAIPanel: $showAIPanel
                    )

                    CanvasRepresentable(
                        canvasManager: canvasManager,
                        showToolPicker: $showToolPicker
                    )
                    .ignoresSafeArea(edges: .bottom)
                }

                // AI Chat panel (slides in from right)
                if showAIPanel {
                    Divider()

                    AIChatPanelView(
                        viewModel: chatViewModel,
                        isVisible: $showAIPanel
                    )
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showAIPanel)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            APIKeyOnboardingView(isPresented: $showOnboarding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyDidChange)) { _ in
            showOnboarding = true
            showAIPanel = false
        }
        .statusBarHidden(false)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Toolbar

struct CanvasToolbar: View {
    @ObservedObject var canvasManager: CanvasManager
    @Binding var showAIPanel: Bool

    var body: some View {
        HStack(spacing: 20) {
            Text("AI Canvas")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                canvasManager.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .disabled(!canvasManager.canUndo)

            Button {
                canvasManager.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title3)
            }
            .disabled(!canvasManager.canRedo)

            Button {
                canvasManager.clearCanvas()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
            }

            Button {
                canvasManager.exportDrawing()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }

            Divider()
                .frame(height: 24)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAIPanel.toggle()
                }
            } label: {
                Image(systemName: showAIPanel ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                    .font(.title3)
                    .foregroundStyle(showAIPanel ? Color.accentColor : Color.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
