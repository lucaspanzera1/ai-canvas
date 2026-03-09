import SwiftUI
import PencilKit

/// UIViewRepresentable wrapper for PKCanvasView — sem PKToolPicker nativo.
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

        // Registrar canvas no manager e aplicar desenho inicial + ferramenta
        canvasManager.canvasView = canvasView

        DispatchQueue.main.async {
            canvasManager.setup()
        }

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Tool updates são gerenciadas pelo CanvasManager via applyCurrentTool()
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
            // Propaga para auto-save
            canvasManager.onDrawingChange?(canvasView.drawing)
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            canvasManager.updateUndoState()
        }
    }
}
