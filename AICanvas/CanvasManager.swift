import SwiftUI
import PencilKit
import Combine

/// Manages the canvas state, undo/redo, and export functionality.
final class CanvasManager: ObservableObject {
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var showExportSheet = false
    @Published var exportedImage: UIImage?

    weak var canvasView: PKCanvasView?

    // MARK: - Actions

    func undo() {
        canvasView?.undoManager?.undo()
        updateUndoState()
    }

    func redo() {
        canvasView?.undoManager?.redo()
        updateUndoState()
    }

    func clearCanvas() {
        canvasView?.drawing = PKDrawing()
        updateUndoState()
    }

    func updateUndoState() {
        canUndo = canvasView?.undoManager?.canUndo ?? false
        canRedo = canvasView?.undoManager?.canRedo ?? false
    }

    func exportDrawing() {
        guard let canvasView else { return }
        let image = canvasView.drawing.image(
            from: canvasView.drawing.bounds,
            scale: UIScreen.main.scale
        )
        exportedImage = image

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // For iPad popover presentation
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}
