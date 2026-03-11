import SwiftUI
import PencilKit
import Combine

// MARK: - Tool Models

enum DrawingToolType: CaseIterable, Equatable {
    case pen
    case pencil
    case marker
    case monoline
    case fountainPen
    case watercolor
    case crayon
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
    @Published var urlToExport: URL? = nil  // SwiftUI observes this to show share sheet

    // Selection mode state
    @Published var isSelectionMode = false {
        didSet {
            if !isSelectionMode {
                selectionRect = nil
            }
        }
    }
    @Published var selectionRect: CGRect?

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
        case .monoline:
            if #available(iOS 17.0, *) {
                canvasView.tool = PKInkingTool(.monoline, color: uiColor, width: width)
            } else {
                canvasView.tool = PKInkingTool(.pen, color: uiColor, width: width)
            }
        case .fountainPen:
            if #available(iOS 17.0, *) {
                canvasView.tool = PKInkingTool(.fountainPen, color: uiColor, width: width)
            } else {
                canvasView.tool = PKInkingTool(.pen, color: uiColor, width: width)
            }
        case .watercolor:
            if #available(iOS 17.0, *) {
                canvasView.tool = PKInkingTool(.watercolor, color: uiColor, width: width * 2)
            } else {
                canvasView.tool = PKInkingTool(.marker, color: uiColor, width: width * 2)
            }
        case .crayon:
            if #available(iOS 17.0, *) {
                canvasView.tool = PKInkingTool(.crayon, color: uiColor, width: width * 1.5)
            } else {
                canvasView.tool = PKInkingTool(.pencil, color: uiColor, width: width * 1.5)
            }
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
    }

    func selectTool(_ type: DrawingToolType) {
        toolConfig.type = type
        isSelectionMode = false // desativa modo de selecao ao escolher ferramenta
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

        // Use selection bounds if available, else fallback to drawing bounds
        let bounds: CGRect
        if let selRect = selectionRect, selRect.width > 10, selRect.height > 10 {
            bounds = selRect
        } else {
            bounds = drawing.bounds.isEmpty
                ? CGRect(x: 0, y: 0, width: 800, height: 600)
                : drawing.bounds.insetBy(dx: -20, dy: -20)
        }

        let canvasSize = bounds.size
        let scale = UIScreen.main.scale

        // Render the PencilKit strokes within the drawing's bounds, forcing light mode 
        // to avoid white strokes becoming invisible on the white background.
        var strokeImage: UIImage!
        let traitCollection = UITraitCollection(userInterfaceStyle: .light)
        traitCollection.performAsCurrent {
            strokeImage = drawing.image(from: bounds, scale: scale)
        }

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

    /// Renders the canvas to a PDF and publishes it so SwiftUI can present the share sheet.
    func exportDrawing() {
        guard let canvasView else { return }

        let drawing = canvasView.drawing
        
        let a4Width: CGFloat = 800
        let a4Height: CGFloat = 1140
        let xMargin: CGFloat = 20
        let yMargin: CGFloat = 20
        
        let tileWidth = a4Width + (xMargin * 2)
        let tileHeight = a4Height + (yMargin * 2)
        
        let totalPages = 20
        var pagesToExport: [Int] = []
        
        for i in 0..<totalPages {
            let pageRect = CGRect(x: 0, y: CGFloat(i) * tileHeight, width: tileWidth, height: tileHeight)
            // Apenas as páginas que foram desenhadas
            let hasStrokes = drawing.strokes.contains { $0.renderBounds.intersects(pageRect) }
            if hasStrokes {
                pagesToExport.append(i)
            }
        }
        
        // Se estiver vazio, exporta pelo menos a primeira página
        if pagesToExport.isEmpty {
            pagesToExport.append(0)
        }

        let pdfMetaData = [
            kCGPDFContextCreator: "AI Canvas",
            kCGPDFContextAuthor: "User"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Vamos usar o tamanho original para o PDF
        let pdfPageBounds = CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pdfPageBounds, format: format)
        
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let tempURL = cachesURL.appendingPathComponent("Anotacoes.pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                for pageIndex in pagesToExport {
                    context.beginPage()
                    
                    let bgRect = CGRect(x: 0, y: CGFloat(pageIndex) * tileHeight, width: tileWidth, height: tileHeight)
                    
                    // Fundo branco
                    UIColor.white.setFill()
                    context.cgContext.fill(pdfPageBounds)
                    
                    // Desenha o conteúdo da página, forçando light mode
                    var pageImage: UIImage!
                    let traitCollection = UITraitCollection(userInterfaceStyle: .light)
                    traitCollection.performAsCurrent {
                        pageImage = drawing.image(from: bgRect, scale: 2.0)
                    }
                    pageImage.draw(in: pdfPageBounds)
                }
            }
            urlToExport = tempURL
        } catch {
            print("Failed to create PDF: \(error)")
        }
    }
    
    // MARK: - AI Annotation Support
    
    /// Adiciona um texto ao canvas simulando uma caligrafia
    func addTextToCanvas(_ text: String) {
        guard let canvasView = canvasView else { return }
        
        let textView = DraggableTextView()
        textView.text = text
        
        // Tentar usar uma fonte com cara de escrita à mão, fallback para system
        if let handwrittenFont = UIFont(name: "ChalkboardSE-Regular", size: 28) {
            textView.font = handwrittenFont
        } else if let handwrittenFont = UIFont(name: "Noteworthy-Light", size: 28) {
            textView.font = handwrittenFont
        } else {
            textView.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        }
        
        // Cor azul caneta
        textView.textColor = UIColor(red: 0.15, green: 0.25, blue: 0.85, alpha: 0.95)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = false
        
        // Posicionar próximo à seleção se houver, se não, no centro da visualização atual
        let targetPoint: CGPoint
        if let sel = selectionRect {
            targetPoint = CGPoint(x: sel.maxX + 40, y: sel.minY)
        } else {
            let cx = canvasView.bounds.width / 2 + canvasView.contentOffset.x
            let cy = canvasView.bounds.height / 2 + canvasView.contentOffset.y
            targetPoint = CGPoint(x: cx, y: cy)
        }
        
        textView.frame = CGRect(x: targetPoint.x, y: targetPoint.y, width: 450, height: 100)
        textView.sizeToFit()
        
        // Limite de largura para não ficar uma linha gigante
        if textView.frame.width > 550 {
            textView.frame.size.width = 550
            textView.sizeToFit()
        }
        
        // Adiciona um pequeno fade de entrada
        textView.alpha = 0
        canvasView.addSubview(textView)
        
        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseOut, animations: {
            textView.alpha = 1
        }, completion: nil)
    }
    }


// MARK: - Components

class DraggableTextView: UITextView, UIGestureRecognizerDelegate {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        self.addGestureRecognizer(pan)
        self.isUserInteractionEnabled = true
        
        // Um duplo clique pode remover o texto ou editá-arlo
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        let translation = gesture.translation(in: superview)
        if gesture.state == .changed {
            self.center = CGPoint(x: self.center.x + translation.x, y: self.center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Tocar duas vezes no texto da IA remove-o da tela
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false // Prevents canvas from panning while moving the text
    }
}
