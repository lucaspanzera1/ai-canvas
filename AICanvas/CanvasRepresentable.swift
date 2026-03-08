import SwiftUI
import PencilKit

/// UIViewRepresentable wrapper for PKCanvasView, optimized for Apple Pencil input.
struct CanvasRepresentable: UIViewRepresentable {
    @ObservedObject var canvasManager: CanvasManager
    @Binding var showToolPicker: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()

        // Drawing configuration
        // .default = Pencil draws, finger scrolls. When no Pencil is paired, finger draws.
        // .anyInput = Any input draws (finger, mouse, trackpad, Pencil). Best for testing.
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        canvasView.isOpaque = true

        // Default tool: fine black pen for writing
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 2)

        // Allow finger drawing for devices without Apple Pencil / simulator
        canvasView.allowsFingerDrawing = true
        canvasView.isScrollEnabled = false
        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 5.0
        canvasView.bouncesZoom = true

        // Delegate
        canvasView.delegate = context.coordinator

        // Register canvas with manager
        canvasManager.canvasView = canvasView

        // Defer tool picker setup to next run loop to let PencilKit
        // finish internal initialization and reduce console warnings.
        DispatchQueue.main.async {
            let toolPicker = PKToolPicker()
            context.coordinator.toolPicker = toolPicker
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Update tool picker visibility
        if let toolPicker = context.coordinator.toolPicker {
            toolPicker.setVisible(showToolPicker, forFirstResponder: canvasView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(canvasManager: canvasManager)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let canvasManager: CanvasManager
        var toolPicker: PKToolPicker?

        init(canvasManager: CanvasManager) {
            self.canvasManager = canvasManager
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            canvasManager.updateUndoState()
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Could be used to hide UI during drawing
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            canvasManager.updateUndoState()
        }
    }
}
