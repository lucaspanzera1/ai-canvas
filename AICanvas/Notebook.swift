import Foundation
import PencilKit
import UIKit

// MARK: - Notebook Type

enum NotebookType: String, Codable, CaseIterable {
    case notebook = "Caderno"
    case whiteboard = "Quadro Branco"
}

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
    var bannerImageData: Data?
    var parentFolderId: UUID?
    
    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📁",
        colorIndex: Int = 0,
        bannerImageData: Data? = nil,
        parentFolderId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.bannerImageData = bannerImageData
        self.parentFolderId = parentFolderId
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
    var bannerImageData: Data?
    var type: NotebookType

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📓",
        colorIndex: Int = 0,
        pageCount: Int = 1,
        backgroundPattern: BackgroundPattern = .none,
        folderId: UUID? = nil,
        bannerImageData: Data? = nil,
        type: NotebookType = .notebook
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
        self.bannerImageData = bannerImageData
        self.type = type
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
    private let foldersMetadataKey = "ai_canvas_folders_v2"
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
    func createNotebook(name: String, emoji: String, colorIndex: Int, folderId: UUID? = nil, bannerImageData: Data? = nil, type: NotebookType = .notebook) -> Notebook {
        let notebook = Notebook(name: name, emoji: emoji, colorIndex: colorIndex, folderId: folderId, bannerImageData: bannerImageData, type: type)
        notebooks.append(notebook)
        
        // Create banners folder with preset images
        createBannersFolder(for: notebook)
        
        saveMetadata()
        return notebook
    }

    func deleteNotebook(_ notebook: Notebook) {
        notebooks.removeAll { $0.id == notebook.id }
        try? FileManager.default.removeItem(at: drawingURL(for: notebook))
        saveMetadata()
    }

    func renameNotebook(_ notebook: Notebook, to name: String, emoji: String? = nil, colorIndex: Int? = nil, bannerImageData: Data?? = nil) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[idx].name = name
        if let emoji = emoji { notebooks[idx].emoji = emoji }
        if let colorIndex = colorIndex { notebooks[idx].colorIndex = colorIndex }
        if let bannerImageData = bannerImageData { notebooks[idx].bannerImageData = bannerImageData }
        saveMetadata()
    }

    func updateNotebookPattern(_ notebook: Notebook, to pattern: BackgroundPattern) {
        guard let idx = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[idx].backgroundPattern = pattern
        saveMetadata()
    }

    // MARK: - CRUD Folders

    @discardableResult
    func createFolder(name: String, emoji: String, colorIndex: Int, bannerImageData: Data? = nil, parentFolderId: UUID? = nil) -> Folder {
        let folder = Folder(name: name, emoji: emoji, colorIndex: colorIndex, bannerImageData: bannerImageData, parentFolderId: parentFolderId)
        folders.append(folder)
        
        // Create banners folder with preset images
        createBannersFolder(for: folder)
        
        saveMetadata()
        return folder
    }

    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        
        // Delete all notebooks in this folder
        let notebooksToDelete = notebooks.filter { $0.folderId == folder.id }
        for nb in notebooksToDelete {
            deleteNotebook(nb)
        }
        
        // Delete all subfolders recursively
        let subfoldersToDelete = folders.filter { $0.parentFolderId == folder.id }
        for subfolder in subfoldersToDelete {
            deleteFolder(subfolder)
        }
        
        saveMetadata()
    }

    func renameFolder(_ folder: Folder, to name: String, emoji: String? = nil, colorIndex: Int? = nil, bannerImageData: Data?? = nil) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].name = name
        if let emoji = emoji { folders[idx].emoji = emoji }
        if let colorIndex = colorIndex { folders[idx].colorIndex = colorIndex }
        if let bannerImageData = bannerImageData { folders[idx].bannerImageData = bannerImageData }
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

    // MARK: - Chat Persistence

    func saveChatHistory(_ messages: [ChatMessage], for notebook: Notebook) {
        if let data = try? JSONEncoder().encode(messages) {
            try? data.write(to: chatURL(for: notebook))
        }
    }

    func loadChatHistory(for notebook: Notebook) -> [ChatMessage] {
        guard let data = try? Data(contentsOf: chatURL(for: notebook)),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    func persistMetadata() {
        saveMetadata()
    }

    // MARK: - Banners

    func getBannersFolder(for identifier: String) -> URL {
        drawingsDirectory.appendingPathComponent("\(identifier)_banners", isDirectory: true)
    }

    func getAvailableBanners(for identifier: String) -> [URL] {
        let bannersFolder = getBannersFolder(for: identifier)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: bannersFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func createBannersFolder(for notebook: Notebook) {
        let bannersPath = getBannersFolder(for: notebook.id.uuidString)
        try? FileManager.default.createDirectory(at: bannersPath, withIntermediateDirectories: true)
        guard (try? FileManager.default.contentsOfDirectory(atPath: bannersPath.path))?.isEmpty != false else {
            return // Banners already exist
        }
        saveBannerPresets(to: bannersPath)
    }

    private func createBannersFolder(for folder: Folder) {
        let bannersPath = getBannersFolder(for: folder.id.uuidString)
        try? FileManager.default.createDirectory(at: bannersPath, withIntermediateDirectories: true)
        guard (try? FileManager.default.contentsOfDirectory(atPath: bannersPath.path))?.isEmpty != false else {
            return // Banners already exist
        }
        saveBannerPresets(to: bannersPath)
    }

    private func saveBannerPresets(to directory: URL) {
        let presets = generateBannerPresets()
        for (index, image) in presets.enumerated() {
            if let pngData = image.pngData() {
                let fileName = String(format: "%02d_banner.png", index + 1)
                let fileURL = directory.appendingPathComponent(fileName)
                try? pngData.write(to: fileURL)
            }
        }
    }

    private func generateBannerPresets() -> [UIImage] {
        let size = CGSize(width: 1200, height: 400)
        var banners: [UIImage] = []

        // Preset 1: Gradient Azul-Roxo
        banners.append(createGradientBanner(
            size: size,
            colors: [
                UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0)
            ]
        ))

        // Preset 2: Gradient Roxo-Rosa
        banners.append(createGradientBanner(
            size: size,
            colors: [
                UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1.0),
                UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
            ]
        ))

        // Preset 3: Gradient Laranja-Amarelo
        banners.append(createGradientBanner(
            size: size,
            colors: [
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
                UIColor(red: 1.0, green: 1.0, blue: 0.2, alpha: 1.0)
            ]
        ))

        // Preset 4: Gradient Verde-Cyan
        banners.append(createGradientBanner(
            size: size,
            colors: [
                UIColor(red: 0.2, green: 1.0, blue: 0.6, alpha: 1.0),
                UIColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1.0)
            ]
        ))

        // Preset 5: Gradient Vermelho-Laranja
        banners.append(createGradientBanner(
            size: size,
            colors: [
                UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
            ]
        ))

        // Preset 6: Gradient Cinza Moderno
        banners.append(createGradientBanner(
            size: size,
            colors: [
                UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0),
                UIColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0)
            ]
        ))

        return banners
    }

    private func createGradientBanner(size: CGSize, colors: [UIColor]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Create gradient
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(origin: .zero, size: size)
            gradientLayer.colors = colors.map { $0.cgColor }
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)

            // Draw gradient using Core Graphics
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: nil
            )!

            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Add subtle pattern overlay
            let pattern = createPatternTexture(size: size)
            pattern.withAlphaComponent(0.1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }

        return image
    }

    private func createPatternTexture(size: CGSize) -> UIColor {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let patternImage = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 10, height: 10))
            context.cgContext.fillEllipse(in: CGRect(x: 10, y: 10, width: 10, height: 10))
        }

        return UIColor(patternImage: patternImage)
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

    private func chatURL(for notebook: Notebook) -> URL {
        drawingsDirectory.appendingPathComponent("\(notebook.id.uuidString).chat")
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
