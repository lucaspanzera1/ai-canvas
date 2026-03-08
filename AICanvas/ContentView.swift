import SwiftUI
import PencilKit

struct ContentView: View {
    @StateObject private var canvasManager = CanvasManager()
    @State private var showToolPicker = true

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                CanvasToolbar(canvasManager: canvasManager)

                // Canvas
                CanvasRepresentable(
                    canvasManager: canvasManager,
                    showToolPicker: $showToolPicker
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .statusBarHidden(false)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Toolbar

struct CanvasToolbar: View {
    @ObservedObject var canvasManager: CanvasManager

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
