import SwiftUI
import PencilKit
import Combine

// MARK: - Tool Models

enum DrawingToolType: CaseIterable, Equatable {
    case pen
    case pencil
    case marker
    case eraser
}

struct DrawingToolConfig: Equatable {
    var type: DrawingToolType = .pen
    var color: Color = .black
    var width: CGFloat = 3.0
}

/// Manages canvas state, tools, undo/redo, and export.
final class CanvasManager: ObservableObject {
    @Published var canUndo = false
    @Published var canRedo = false

    // Tool state
    @Published var toolConfig = DrawingToolConfig()

    weak var canvasView: PKCanvasView?

    /// Called every time the drawing changes — used for auto-save.
    var onDrawingChange: ((PKDrawing) -> Void)?

    private let initialDrawing: PKDrawing

    init(initialDrawing: PKDrawing = PKDrawing()) {
        self.initialDrawing = initialDrawing
    }

    // MARK: - Setup

    /// Called from CanvasRepresentable after canvasView is assigned.
    func setup() {
        canvasView?.drawing = initialDrawing
        applyCurrentTool()
    }

    // MARK: - Tool Application

    func applyCurrentTool() {
        guard let canvasView else { return }
        let uiColor = UIColor(toolConfig.color)
        let width = toolConfig.width

        switch toolConfig.type {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: width)
        case .pencil:
            canvasView.tool = PKInkingTool(.pencil, color: uiColor, width: width)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: uiColor, width: width * 3)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
    }

    func selectTool(_ type: DrawingToolType) {
        toolConfig.type = type
        applyCurrentTool()
    }

    func setColor(_ color: Color) {
        toolConfig.color = color
        applyCurrentTool()
    }

    func setWidth(_ width: CGFloat) {
        toolConfig.width = width
        applyCurrentTool()
    }

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

    func getCurrentDrawing() -> PKDrawing {
        canvasView?.drawing ?? PKDrawing()
    }

    func exportDrawing() {
        guard let canvasView else { return }
        let image = canvasView.drawing.image(
            from: canvasView.drawing.bounds,
            scale: UIScreen.main.scale
        )

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
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
