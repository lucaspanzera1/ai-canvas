import SwiftUI
import PencilKit

/// UIViewRepresentable wrapper for PKCanvasView — sem PKToolPicker nativo.
struct CanvasRepresentable: UIViewRepresentable {
    @ObservedObject var canvasManager: CanvasManager
    @Binding var showToolPicker: Bool
    @Binding var pattern: BackgroundPattern

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = CenteredCanvasView()

        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.allowsFingerDrawing = true
        canvasView.isScrollEnabled = true
        
        // Define canvas grande para simular infinidade
        let canvasWidth: CGFloat = 840  // 1 página por linha
        let canvasHeight: CGFloat = 1180 * 20 // 20 páginas para baixo
        canvasView.contentSize = CGSize(width: canvasWidth, height: canvasHeight)
        
        // Background view que contém a textura repetida das páginas
        let bgView = UIView(frame: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        bgView.layer.anchorPoint = CGPoint(x: 0, y: 0)
        bgView.layer.position = CGPoint(x: 0, y: 0)
        bgView.tag = 999
        bgView.isUserInteractionEnabled = false
        canvasView.insertSubview(bgView, at: 0)
        
        canvasView.minimumZoomScale = 0.5
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
        if let bgView = canvasView.viewWithTag(999) {
            updateBackgroundPattern(for: bgView, pattern: pattern)
            bgView.transform = CGAffineTransform(scaleX: canvasView.zoomScale, y: canvasView.zoomScale)
        }
    }
    
    private func updateBackgroundPattern(for view: UIView, pattern: BackgroundPattern) {
        let a4Width: CGFloat = 800
        let a4Height: CGFloat = 1140
        let xMargin: CGFloat = 20
        let yMargin: CGFloat = 20
        
        let tileWidth = a4Width + (xMargin * 2)
        let tileHeight = a4Height + (yMargin * 2)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: tileWidth, height: tileHeight), false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Fundo vazio (margem entre folhas)
        UIColor.clear.setFill()
        context.fill(CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight))
        
        // O papel A4
        let paperRect = CGRect(x: xMargin, y: yMargin, width: a4Width, height: a4Height)
        
        // Sombra da folha
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.08).cgColor)
        UIColor.white.setFill()
        let path = UIBezierPath(roundedRect: paperRect, cornerRadius: 2)
        path.fill()
        
        // Limpar sombra para não afetar as linhas
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // Desenhar padrões (linhas ou grade)
        if pattern != .none {
            context.setStrokeColor(UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0).cgColor)
            context.setLineWidth(1)
            
            let linePath = UIBezierPath()
            let step: CGFloat = 34
            
            // Margens internas da folha (pautado tipicamente não chega na borda exata)
            let contentRect = paperRect.insetBy(dx: 40, dy: 40)
            
            // Linhas horizontais
            for y in stride(from: contentRect.minY, through: contentRect.maxY, by: step) {
                linePath.move(to: CGPoint(x: contentRect.minX, y: y))
                linePath.addLine(to: CGPoint(x: contentRect.maxX, y: y))
            }
            
            // Linhas verticais para grade
            if pattern == .grid {
                for x in stride(from: contentRect.minX, through: contentRect.maxX, by: step) {
                    linePath.move(to: CGPoint(x: x, y: contentRect.minY))
                    linePath.addLine(to: CGPoint(x: x, y: contentRect.maxY))
                }
            }
            
            linePath.stroke()
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let img = image {
            view.backgroundColor = UIColor(patternImage: img)
        }
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

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if let bgView = scrollView.viewWithTag(999) {
                bgView.transform = CGAffineTransform(scaleX: scrollView.zoomScale, y: scrollView.zoomScale)
            }
        }
    }
}

class CenteredCanvasView: PKCanvasView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let horizontalInset = max(0, (bounds.width - contentSize.width * zoomScale) / 2)
        let verticalInset = max(0, (bounds.height - contentSize.height * zoomScale) / 2)
        
        self.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }
}
