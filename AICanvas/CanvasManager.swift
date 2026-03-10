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
    @Published var imageToExport: UIImage? = nil  // SwiftUI observes this to show share sheet

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

    /// Returns a UIImage representation of the current canvas for AI vision analysis.
    func captureCanvasImage() -> UIImage? {
        guard let canvasView else { return nil }
        let drawing = canvasView.drawing

        // Use at least a min size so blank canvases still send something
        let bounds = drawing.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 800, height: 600)
            : drawing.bounds.insetBy(dx: -20, dy: -20)

        let scale = UIScreen.main.scale
        let image = drawing.image(from: bounds, scale: scale)

        // Composite onto white background so the image makes sense for the AI
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            image.draw(in: CGRect(origin: .zero, size: bounds.size))
        }
    }

    /// Renders the canvas to a UIImage and publishes it so SwiftUI can present the share sheet.
    func exportDrawing() {
        guard let canvasView else { return }

        let drawing = canvasView.drawing
        let bounds = drawing.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 800, height: 600)
            : drawing.bounds.insetBy(dx: -20, dy: -20)

        let scale = UIScreen.main.scale
        let rawImage = drawing.image(from: bounds, scale: scale)

        // Composite onto white background
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let finalImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            rawImage.draw(in: CGRect(origin: .zero, size: bounds.size))
        }

        imageToExport = finalImage
    }
}
