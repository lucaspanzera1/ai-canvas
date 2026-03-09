import SwiftUI
import PencilKit

/// UIViewRepresentable wrapper for PKCanvasView — sem PKToolPicker nativo.
/// As ferramentas são controladas manualmente pela GameDrawingToolbar em SwiftUI.
struct CanvasRepresentable: UIViewRepresentable {
    @ObservedObject var canvasManager: CanvasManager
    @Binding var showToolPicker: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()

        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        canvasView.allowsFingerDrawing = true
        canvasView.isScrollEnabled = false
        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 5.0
        canvasView.bouncesZoom = true
        canvasView.delegate = context.coordinator

        // Registrar canvas no manager (sem PKToolPicker)
        canvasManager.canvasView = canvasView

        // Configurar ferramenta inicial via manager
        DispatchQueue.main.async {
            canvasManager.applyCurrentTool()
        }

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Tool updates são gerenciadas pelo CanvasManager
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(canvasManager: canvasManager)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let canvasManager: CanvasManager

        init(canvasManager: CanvasManager) {
            self.canvasManager = canvasManager
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            canvasManager.updateUndoState()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            canvasManager.updateUndoState()
        }
    }
}
