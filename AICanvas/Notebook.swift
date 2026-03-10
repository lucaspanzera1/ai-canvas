import Foundation
import PencilKit

// MARK: - Background Pattern

enum BackgroundPattern: String, Codable, CaseIterable {
    case none = "Vazio"
    case lines = "Linhas"
    case grid = "Grade"
}

// MARK: - Folder Model

struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var createdAt: Date
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📁",
        colorIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.createdAt = Date()
        self.lastModified = Date()
    }
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
    var folderId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📓",
        colorIndex: Int = 0,
        pageCount: Int = 1,
        backgroundPattern: BackgroundPattern = .none,
        folderId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.createdAt = Date()
        self.lastModified = Date()
        self.pageCount = pageCount
        self.backgroundPattern = backgroundPattern
        self.folderId = folderId
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
    @Published var folders: [Folder] = []

    private let metadataKey = "ai_canvas_notebooks_v2"
    private let foldersMetadataKey = "ai_canvas_folders_v1"
    private let drawingsDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        drawingsDirectory = docs.appendingPathComponent("AICanvas_Drawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        
        // Migrate old data if v2 doesn't exist
        if UserDefaults.standard.data(forKey: metadataKey) == nil,
           let oldData = UserDefaults.standard.data(forKey: "ai_canvas_notebooks_v1") {
            UserDefaults.standard.set(oldData, forKey: metadataKey)
        }
        
        loadMetadata()

        // Seed com um caderno padrão se vazio
        if notebooks.isEmpty && folders.isEmpty {
            let welcome = Notebook(name: "Caderno 1", emoji: "✨", colorIndex: 0)
            notebooks.append(welcome)
            saveMetadata()
        }
    }

    // MARK: - CRUD

    // MARK: - CRUD Notebooks

    @discardableResult
    func createNotebook(name: String, emoji: String, colorIndex: Int, folderId: UUID? = nil) -> Notebook {
        let notebook = Notebook(name: name, emoji: emoji, colorIndex: colorIndex, folderId: folderId)
        notebooks.append(notebook)
        saveMetadata()
        return notebook
    }

    func deleteNotebook(_ notebook: Notebook) {
        notebooks.removeAll { $0.id == notebook.id }
        try? FileManager.default.removeItem(at: drawingURL(for: notebook))
        saveMetadata()
    }

    func renameNotebook(_ notebook: Notebook, to name: String, emoji: String? = nil, colorIndex: Int? = nil) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[idx].name = name
        if let emoji = emoji { notebooks[idx].emoji = emoji }
        if let colorIndex = colorIndex { notebooks[idx].colorIndex = colorIndex }
        saveMetadata()
    }

    func updateNotebookPattern(_ notebook: Notebook, to pattern: BackgroundPattern) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[idx].backgroundPattern = pattern
        saveMetadata()
    }

    // MARK: - CRUD Folders

    @discardableResult
    func createFolder(name: String, emoji: String, colorIndex: Int) -> Folder {
        let folder = Folder(name: name, emoji: emoji, colorIndex: colorIndex)
        folders.append(folder)
        saveMetadata()
        return folder
    }

    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        let notebooksToDelete = notebooks.filter { $0.folderId == folder.id }
        for nb in notebooksToDelete {
            deleteNotebook(nb)
        }
        saveMetadata()
    }

    func renameFolder(_ folder: Folder, to name: String, emoji: String? = nil, colorIndex: Int? = nil) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].name = name
        if let emoji = emoji { folders[idx].emoji = emoji }
        if let colorIndex = colorIndex { folders[idx].colorIndex = colorIndex }
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
        if let data = try? JSONEncoder().encode(notebooks) {
            UserDefaults.standard.set(data, forKey: metadataKey)
        }
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: foldersMetadataKey)
        }
    }

    private func loadMetadata() {
        if let data = UserDefaults.standard.data(forKey: metadataKey),
           let decoded = try? JSONDecoder().decode([Notebook].self, from: data) {
            notebooks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: foldersMetadataKey),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = decoded
        }
    }
}
