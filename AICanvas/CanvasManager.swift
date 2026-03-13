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
    
    /// Called when an image needs to be resized with a dialog
    var onImageShowResizeDialog: ((DraggableImageView, CGSize) -> Void)?

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
    func exportDrawing(pattern: BackgroundPattern = .none) {
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
                    
                    // Fundo total branco (representa a margem e o papel)
                    UIColor.white.setFill()
                    context.cgContext.fill(pdfPageBounds)
                    
                    if pattern != .none {
                        // Reproduzir o padrão
                        context.cgContext.setStrokeColor(UIColor.lightGray.withAlphaComponent(0.5).cgColor)
                        context.cgContext.setLineWidth(1)
                        
                        let paperRect = CGRect(x: xMargin, y: yMargin, width: a4Width, height: a4Height)
                        let step: CGFloat = 34
                        let contentRect = paperRect.insetBy(dx: 40, dy: 40)
                        
                        // Linhas horizontais
                        for y in stride(from: contentRect.minY, through: contentRect.maxY, by: step) {
                            context.cgContext.move(to: CGPoint(x: contentRect.minX, y: y))
                            context.cgContext.addLine(to: CGPoint(x: contentRect.maxX, y: y))
                        }
                        
                        if pattern == .grid {
                            // Linhas verticais
                            for x in stride(from: contentRect.minX, through: contentRect.maxX, by: step) {
                                context.cgContext.move(to: CGPoint(x: x, y: contentRect.minY))
                                context.cgContext.addLine(to: CGPoint(x: x, y: contentRect.maxY))
                            }
                        }
                        context.cgContext.strokePath()
                    }
                    
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

    // MARK: - Image Paste / Insert

    /// Lê uma imagem da área de transferência e a insere no canvas.
    /// Retorna `true` se havia imagem disponível.
    @discardableResult
    func pasteImageFromClipboard() -> Bool {
        guard let image = UIPasteboard.general.image else { return false }
        insertImage(image)
        return true
    }

    /// Insere uma UIImage no canvas como uma view arrastável, redimensionável e que acompanha o zoom.
    func insertImage(_ image: UIImage) {
        guard let canvasView = canvasView else { return }

        let zoom = canvasView.zoomScale

        // Tamanho em coordenadas de canvas (zoom = 1)
        let maxW: CGFloat = 300
        let aspect = image.size.height / max(image.size.width, 1)
        let canvasW = min(maxW, image.size.width)
        let canvasH = canvasW * aspect

        // Centro do viewport convertido para coordenadas de canvas
        let canvasCX = (canvasView.contentOffset.x + canvasView.bounds.width  / 2) / zoom
        let canvasCY = (canvasView.contentOffset.y + canvasView.bounds.height / 2) / zoom

        let imageView = DraggableImageView(image: image)
        imageView.canvasOrigin = CGPoint(x: canvasCX - canvasW / 2, y: canvasCY - canvasH / 2)
        imageView.canvasSize   = CGSize(width: canvasW, height: canvasH)
        imageView.applyZoom(zoom)
        imageView.canvasManagerRef = self

        imageView.alpha = 0
        canvasView.addSubview(imageView)

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75,
                       initialSpringVelocity: 0.5, options: .curveEaseOut) {
            imageView.alpha = 1
        }
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
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// MARK: - DraggableImageView

/// UIImageView que vive no espaço de coordenadas do canvas (zoom = 1).
/// A posição e o tamanho são mantidos em `canvasOrigin` / `canvasSize` e
/// o frame é sempre recalculado como `origin * zoom, size * zoom`, de modo
/// que a imagem acompanha o zoom exatamente como os traços do PencilKit.
class DraggableImageView: UIImageView, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {

    // MARK: - Canvas-space state (independente do zoom atual)
    /// Origem da imagem em coordenadas de canvas (zoom = 1).
    var canvasOrigin: CGPoint = .zero
    /// Tamanho da imagem em coordenadas de canvas (zoom = 1).
    var canvasSize: CGSize   = .zero
    /// Zoom atual do canvas — atualizado pelo scrollViewDidZoom via applyZoom().
    private(set) var currentZoom: CGFloat = 1.0

    // MARK: - Pinch state (em coordenadas de canvas)
    private var canvasSizeBeforePinch:   CGSize  = .zero
    private var canvasCenterBeforePinch: CGPoint = .zero

    // MARK: - UI
    private let selectionBorder = CAShapeLayer()
    private var isSelectedState  = false
    private var handleViews: [UIView] = []
    
    // MARK: - Callbacks
    var onContextMenu: ((UIViewController) -> Void)?
    var onDelete: (() -> Void)?
    var onCopyToClipboard: (() -> Void)?
    var onShowResizeDialog: ((CGSize) -> Void)?
    var onBringToFront: (() -> Void)?
    var onSendToBack: (() -> Void)?
    var onDuplicate: (() -> Void)?

    // MARK: - Init

    init(image: UIImage) {
        super.init(image: image)
        contentMode          = .scaleAspectFit
        isUserInteractionEnabled = true
        clipsToBounds        = false
        setupGestures()
        setupSelectionBorder()
        setupHandles()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Zoom

    /// Recalcula o frame a partir das coordenadas de canvas e do zoom atual.
    /// Deve ser chamado sempre que o zoom do canvas mudar (scrollViewDidZoom).
    func applyZoom(_ zoom: CGFloat) {
        currentZoom = zoom
        frame = CGRect(
            x: canvasOrigin.x * zoom,
            y: canvasOrigin.y * zoom,
            width:  canvasSize.width  * zoom,
            height: canvasSize.height * zoom
        )
        setNeedsLayout()
    }

    // MARK: - Setup

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)
        
        // Adiciona UIContextMenuInteraction para suporte de menu em iOS 13+
        if #available(iOS 13.0, *) {
            let contextMenu = UIContextMenuInteraction(delegate: self)
            addInteraction(contextMenu)
        }
    }

    private func setupSelectionBorder() {
        selectionBorder.fillColor    = UIColor.clear.cgColor
        selectionBorder.strokeColor  = UIColor.systemBlue.cgColor
        selectionBorder.lineWidth    = 2.5
        selectionBorder.lineDashPattern = [6, 3]
        selectionBorder.isHidden     = true
        layer.addSublayer(selectionBorder)
    }

    private func setupHandles() {
        for _ in 0..<4 {
            let h = UIView()
            h.backgroundColor      = .systemBlue
            h.layer.borderColor    = UIColor.white.cgColor
            h.layer.borderWidth    = 2.0
            h.layer.cornerRadius   = 8
            h.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
            h.isHidden = true
            addSubview(h)
            handleViews.append(h)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectionBorder.frame = bounds
        selectionBorder.path  = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: 4
        ).cgPath
        positionHandles()
    }

    private func positionHandles() {
        let corners: [CGPoint] = [
            CGPoint(x: -8,             y: -8),
            CGPoint(x: bounds.maxX-8,  y: -8),
            CGPoint(x: -8,             y: bounds.maxY-8),
            CGPoint(x: bounds.maxX-8,  y: bounds.maxY-8)
        ]
        for (i, h) in handleViews.enumerated() {
            h.center     = corners[i]
            h.frame.size = CGSize(width: 16, height: 16)
        }
    }

    // MARK: - Selection UI

    private func setSelectedState(_ selected: Bool) {
        isSelectedState = selected
        selectionBorder.isHidden = !selected
        handleViews.forEach { $0.isHidden = !selected }
    }

    // MARK: - Gesture Handlers

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        setSelectedState(!isSelectedState)
    }

    /// Pan em coordenadas de canvas: divide a translação pelo zoom atual para
    /// que arrastar 50 pt na tela = 50 pt de canvas (qualquer zoom).
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let sv = superview else { return }
        let t = gesture.translation(in: sv)
        if gesture.state == .began { setSelectedState(true) }
        if gesture.state == .changed {
            // t está no espaço da scroll view; converte para canvas dividindo pelo zoom
            canvasOrigin.x += t.x / currentZoom
            canvasOrigin.y += t.y / currentZoom
            applyZoom(currentZoom)
            gesture.setTranslation(.zero, in: sv)
        }
    }

    /// Pinch: redimensiona em coordenadas de canvas, mantendo o centro fixo.
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            canvasSizeBeforePinch = canvasSize
            canvasCenterBeforePinch = CGPoint(
                x: canvasOrigin.x + canvasSize.width  / 2,
                y: canvasOrigin.y + canvasSize.height / 2
            )
            setSelectedState(true)
        case .changed:
            let s = gesture.scale
            // Tamanho mínimo de 40 pt na tela, independente do zoom
            let minCanvas = 40.0 / currentZoom
            let newW = max(minCanvas, canvasSizeBeforePinch.width  * s)
            let newH = max(minCanvas, canvasSizeBeforePinch.height * s)
            canvasSize   = CGSize(width: newW, height: newH)
            canvasOrigin = CGPoint(
                x: canvasCenterBeforePinch.x - newW / 2,
                y: canvasCenterBeforePinch.y - newH / 2
            )
            applyZoom(currentZoom)
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha     = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Select on long press and present context menu if available
            setSelectedState(true)
            if #available(iOS 13.0, *) {
                // Trigger context menu programmatically if possible
                self.becomeFirstResponder()
                // UIContextMenuInteraction shows automatically on long-press,
                // but for safety we can do nothing here; selection feedback:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
    
    // MARK: - UIContextMenuInteractionDelegate
    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let actionProvider: UIContextMenuActionProvider = { [weak self] _ in
            return UIMenu(title: "Imagem", children: [
                UIAction(title: "Copiar", image: UIImage(systemName: "doc.on.doc"), handler: { [weak self] _ in
                    self?.copyToClipboard()
                }),
                UIAction(title: "Redimensionar", image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"), handler: { [weak self] _ in
                    self?.showResizeDialog()
                }),
                UIMenu(title: "Camadas", image: UIImage(systemName: "square.stack"), children: [
                    UIAction(title: "Trazer para frente", image: UIImage(systemName: "arrow.up"), handler: { [weak self] _ in
                        self?.bringToFront()
                    }),
                    UIAction(title: "Enviar para trás", image: UIImage(systemName: "arrow.down"), handler: { [weak self] _ in
                        self?.sendToBack()
                    })
                ]),
                UIAction(title: "Duplicar", image: UIImage(systemName: "doc.on.doc"), handler: { [weak self] _ in
                    self?.duplicate()
                }),
                UIAction(title: "Deletar", image: UIImage(systemName: "trash"), attributes: .destructive, handler: { [weak self] _ in
                    self?.delete()
                })
            ])
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
    }
    
    @available(iOS 13.0, *)
    private func updateConfiguration() {
        // Método mantido para compatibilidade futura
    }
    
    private func copyToClipboard() {
        guard let image = image else { return }
        UIPasteboard.general.image = image
        onCopyToClipboard?()
    }
    
    private func showResizeDialog() {
        // Notifica o CanvasManager para mostrar o diálogo
        // Ele pode então chamar um callback que atualizar o tamanho
        guard let canvasManager = canvasManagerRef else { return }
        canvasManager.onImageShowResizeDialog?(self, canvasSize)
    }
    
    // Referência fraca ao CanvasManager para callbacks
    weak var canvasManagerRef: CanvasManager?
    
    // Método para aplicar novo tamanho após redimensionamento
    func applyNewSize(_ newSize: CGSize) {
        canvasSize = newSize
        applyZoom(currentZoom)
    }
    
    private func bringToFront() {
        superview?.bringSubviewToFront(self)
        onBringToFront?()
    }
    
    private func sendToBack() {
        superview?.sendSubviewToBack(self)
        onSendToBack?()
    }
    
    private func duplicate() {
        guard let image = image, let parentView = superview as? PKCanvasView else { return }
        let newImageView = DraggableImageView(image: image)
        newImageView.canvasOrigin = CGPoint(x: canvasOrigin.x + 30, y: canvasOrigin.y + 30)
        newImageView.canvasSize = canvasSize
        newImageView.applyZoom(currentZoom)
        newImageView.canvasManagerRef = canvasManagerRef
        newImageView.alpha = 0
        parentView.addSubview(newImageView)
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75,
                       initialSpringVelocity: 0.5, options: .curveEaseOut) {
            newImageView.alpha = 1
        }
        
        onDuplicate?()
    }
    
    private func delete() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha     = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in self.removeFromSuperview() }
        
        onDelete?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // pan + pinch simultâneo OK; canvas pan bloqueado
        return gestureRecognizer is UIPinchGestureRecognizer
            || other             is UIPinchGestureRecognizer
    }
}
