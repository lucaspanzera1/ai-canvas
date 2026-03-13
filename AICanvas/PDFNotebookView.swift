import SwiftUI
import PDFKit
import UIKit

enum PDFAnnotationTool: String, CaseIterable {
    case select
    case draw
    case note
    case erase
}

final class PDFEditorController: ObservableObject {
    @Published var selectedTool: PDFAnnotationTool = .select
    @Published var inkColor: Color = .yellow
    @Published var lineWidth: CGFloat = 4

    weak var pdfView: PDFView?
    var saveHandler: (() -> Void)?

    private var pendingSave: DispatchWorkItem?

    func applyHighlightToSelection() {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection else { return }

        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }

                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = UIColor.systemYellow.withAlphaComponent(0.35)
                page.addAnnotation(annotation)
            }
        }

        pdfView.clearSelection()
        scheduleSave()
    }

    func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveHandler?()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func flushSave() {
        pendingSave?.cancel()
        saveHandler?()
    }
}

struct PDFNotebookView: View {
    let notebook: Notebook
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    @Binding var showSidebar: Bool

    @StateObject private var controller = PDFEditorController()

    private var pdfURL: URL? {
        store.pdfDocumentURL(for: notebook)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if let pdfURL {
                PDFEditorRepresentable(documentURL: pdfURL, controller: controller) { data in
                    store.savePDFDocument(data, for: notebook)
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)

                    Text("PDF não encontrado")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Este caderno não possui um arquivo PDF válido.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            }
        }
        .background(AppTheme.background)
        .onDisappear {
            controller.flushSave()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            if !showSidebar {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showSidebar = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button {
                store.persistMetadata()
                selectedNotebook = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Cadernos")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text("📄")
                .font(.system(size: 16))

            Text(notebook.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            toolButton(icon: "cursorarrow", tool: .select, title: "Selecionar")
            toolButton(icon: "pencil.tip", tool: .draw, title: "Caneta")
            toolButton(icon: "note.text", tool: .note, title: "Nota")
            toolButton(icon: "eraser", tool: .erase, title: "Apagar")

            Button {
                controller.applyHighlightToSelection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "highlighter")
                    Text("Grifar seleção")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if controller.selectedTool == .draw {
                ColorPicker("", selection: $controller.inkColor, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 30, height: 30)

                Slider(value: $controller.lineWidth, in: 1...12, step: 1)
                    .frame(width: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)
    }

    private func toolButton(icon: String, tool: PDFAnnotationTool, title: String) -> some View {
        let selected = controller.selectedTool == tool
        return Button {
            controller.selectedTool = tool
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? .white : AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? AppTheme.accent : AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.clear : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PDFEditorRepresentable: UIViewRepresentable {
    let documentURL: URL
    @ObservedObject var controller: PDFEditorController
    let onDocumentChanged: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView(frame: .zero)
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .secondarySystemBackground

        if let document = PDFDocument(url: documentURL) {
            pdfView.document = document
        }

        controller.pdfView = pdfView
        controller.saveHandler = { [weak pdfView] in
            guard let data = pdfView?.document?.dataRepresentation() else { return }
            onDocumentChanged(data)
        }

        context.coordinator.configureGestures(for: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.updateTool(controller.selectedTool)
        context.coordinator.updateInk(color: UIColor(controller.inkColor), width: controller.lineWidth)
    }

    final class Coordinator: NSObject {
        private let controller: PDFEditorController

        private weak var pdfView: PDFView?
        private var currentTool: PDFAnnotationTool = .select
        private var inkColor: UIColor = .systemYellow
        private var lineWidth: CGFloat = 4

        private let drawPanRecognizer = UIPanGestureRecognizer()
        private let tapRecognizer = UITapGestureRecognizer()

        private var activePath: UIBezierPath?
        private weak var activePage: PDFPage?

        init(controller: PDFEditorController) {
            self.controller = controller
            super.init()
            drawPanRecognizer.addTarget(self, action: #selector(handleDrawPan(_:)))
            drawPanRecognizer.maximumNumberOfTouches = 1
            tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        }

        func configureGestures(for pdfView: PDFView) {
            self.pdfView = pdfView
            drawPanRecognizer.delegate = self
            tapRecognizer.delegate = self
            pdfView.addGestureRecognizer(drawPanRecognizer)
            pdfView.addGestureRecognizer(tapRecognizer)
        }

        func updateTool(_ tool: PDFAnnotationTool) {
            currentTool = tool
            drawPanRecognizer.isEnabled = (tool == .draw)
            tapRecognizer.isEnabled = (tool == .note || tool == .erase)
        }

        func updateInk(color: UIColor, width: CGFloat) {
            inkColor = color
            lineWidth = width
        }

        @objc private func handleDrawPan(_ gesture: UIPanGestureRecognizer) {
            guard currentTool == .draw,
                  let pdfView = pdfView else { return }

            let viewPoint = gesture.location(in: pdfView)

            switch gesture.state {
            case .began:
                guard let page = pdfView.page(for: viewPoint, nearest: true) else { return }
                activePage = page
                let pagePoint = pdfView.convert(viewPoint, to: page)
                let path = UIBezierPath()
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: pagePoint)
                activePath = path

            case .changed:
                guard let page = activePage,
                      let path = activePath else { return }
                let pagePoint = pdfView.convert(viewPoint, to: page)
                path.addLine(to: pagePoint)

            case .ended, .cancelled:
                guard let page = activePage,
                      let path = activePath else {
                    activePath = nil
                    activePage = nil
                    return
                }

                let bounds = path.bounds.insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2)
                let inkAnnotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
                inkAnnotation.color = inkColor
                inkAnnotation.border = PDFBorder()
                inkAnnotation.border?.lineWidth = lineWidth
                inkAnnotation.add(path)
                page.addAnnotation(inkAnnotation)

                controller.scheduleSave()
                activePath = nil
                activePage = nil

            default:
                break
            }
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView,
                  let page = pdfView.page(for: gesture.location(in: pdfView), nearest: true) else { return }

            let pointInView = gesture.location(in: pdfView)
            let pointInPage = pdfView.convert(pointInView, to: page)

            switch currentTool {
            case .note:
                let noteBounds = CGRect(x: pointInPage.x, y: pointInPage.y, width: 28, height: 28)
                let note = PDFAnnotation(bounds: noteBounds, forType: .text, withProperties: nil)
                note.contents = "Nova nota"
                note.color = UIColor.systemYellow.withAlphaComponent(0.9)
                page.addAnnotation(note)
                controller.scheduleSave()

            case .erase:
                if let annotation = page.annotations.reversed().first(where: { annotation in
                    annotation.bounds.insetBy(dx: -8, dy: -8).contains(pointInPage)
                }) {
                    page.removeAnnotation(annotation)
                    controller.scheduleSave()
                }

            default:
                break
            }
        }
    }
}

extension PDFEditorRepresentable.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
