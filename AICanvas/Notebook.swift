import Foundation
import PencilKit

// MARK: - Background Pattern

enum BackgroundPattern: String, Codable, CaseIterable {
    case none = "Vazio"
    case lines = "Linhas"
    case grid = "Grade"
}

// MARK: - Notebook Model

struct Notebook: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var createdAt: Date
    var lastModified: Date
    var pageCount: Int
    var backgroundPattern: BackgroundPattern?

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📓",
        colorIndex: Int = 0,
        pageCount: Int = 1,
        backgroundPattern: BackgroundPattern = .none
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.createdAt = Date()
        self.lastModified = Date()
        self.pageCount = pageCount
        self.backgroundPattern = backgroundPattern
    }

    static func == (lhs: Notebook, rhs: Notebook) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notebook Colors (neon palette)

let notebookNeonColors: [(name: String, accent: String)] = [
    ("Roxo",    "#9438FF"),
    ("Cyan",    "#00D9FF"),
    ("Verde",   "#2EFF94"),
    ("Rosa",    "#FF3399"),
    ("Laranja", "#FF9900"),
    ("Azul",    "#4D9DFF"),
    ("Amarelo", "#FFE600"),
    ("Vermelho","#FF4040"),
]

// MARK: - Notebook Store

final class NotebookStore: ObservableObject {
    @Published var notebooks: [Notebook] = []

    private let metadataKey = "ai_canvas_notebooks_v1"
    private let drawingsDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        drawingsDirectory = docs.appendingPathComponent("AICanvas_Drawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        loadMetadata()

        // Seed com um caderno padrão se vazio
        if notebooks.isEmpty {
            let welcome = Notebook(name: "Caderno 1", emoji: "✨", colorIndex: 0)
            notebooks.append(welcome)
            saveMetadata()
        }
    }

    // MARK: - CRUD

    @discardableResult
    func createNotebook(name: String, emoji: String, colorIndex: Int) -> Notebook {
        let notebook = Notebook(name: name, emoji: emoji, colorIndex: colorIndex)
        notebooks.append(notebook)
        saveMetadata()
        return notebook
    }

    func deleteNotebook(_ notebook: Notebook) {
        notebooks.removeAll { $0.id == notebook.id }
        try? FileManager.default.removeItem(at: drawingURL(for: notebook))
        saveMetadata()
    }

    func renameNotebook(_ notebook: Notebook, to name: String) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[idx].name = name
        saveMetadata()
    }

    func updateNotebookPattern(_ notebook: Notebook, to pattern: BackgroundPattern) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[idx].backgroundPattern = pattern
        saveMetadata()
    }

    // MARK: - Drawing Persistence

    func saveDrawing(_ drawing: PKDrawing, for notebook: Notebook) {
        let data = drawing.dataRepresentation()
        try? data.write(to: drawingURL(for: notebook))

        if let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[idx].lastModified = Date()
            // Don't call saveMetadata on every stroke — only update in memory
            // Batch save is called on app background/notebook switch
        }
    }

    func loadDrawing(for notebook: Notebook) -> PKDrawing {
        guard let data = try? Data(contentsOf: drawingURL(for: notebook)),
              let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    func persistMetadata() {
        saveMetadata()
    }

    // MARK: - Thumbnail

    func thumbnail(for notebook: Notebook, size: CGSize) -> UIImage? {
        let drawing = loadDrawing(for: notebook)
        guard !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
    }

    // MARK: - Private

    private func drawingURL(for notebook: Notebook) -> URL {
        drawingsDirectory.appendingPathComponent("\(notebook.id.uuidString).drawing")
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(notebooks) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let decoded = try? JSONDecoder().decode([Notebook].self, from: data) else { return }
        notebooks = decoded
    }
}
