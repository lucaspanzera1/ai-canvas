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

        let canvasSize = bounds.size
        let scale = UIScreen.main.scale

        // Render the PencilKit strokes within the drawing's bounds
        let strokeImage = drawing.image(from: bounds, scale: scale)

        // Composite onto an opaque white background.
        // IMPORTANT: use CGRect(origin: .zero) — the renderer coordinate space always
        // starts at (0,0), NOT at bounds.origin. Using bounds directly here would
        // paint the white fill at the wrong position, leaving transparent pixels that
        // JPEG encodes as black (hence the "all black" image the AI was seeing).
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true  // no alpha channel → no transparent→black JPEG artifacts

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
            strokeImage.draw(in: CGRect(origin: .zero, size: canvasSize))
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
