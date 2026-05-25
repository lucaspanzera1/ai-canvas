import Foundation
import PencilKit
import UIKit

// MARK: - Settings

struct SyncSettings: Codable {
    var serverURL: String   // ex: https://sync.seudominio.com
    var apiKey: String
    var fetchflowKey: String

    static let empty = SyncSettings(serverURL: "", apiKey: "", fetchflowKey: "")

    private static let key = "aicanvas_sync_settings"

    static func load() -> SyncSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(SyncSettings.self, from: data) else {
            return .empty
        }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SyncSettings.key)
        }
    }

    var isConfigured: Bool { !serverURL.isEmpty && !apiKey.isEmpty }
    var fetchflowConfigured: Bool { !fetchflowKey.isEmpty }
}

// MARK: - Sync Result

enum SyncResult {
    case success(pushed: Int, pulled: Int)
    case failure(String)
}

// MARK: - Manager

@MainActor
final class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date? = nil
    @Published var lastError: String? = nil

    private let store: NotebookStore

    init(store: NotebookStore) {
        self.store = store
    }

    // MARK: - Public API

    func sync() async -> SyncResult {
        let settings = SyncSettings.load()
        guard settings.isConfigured else {
            let msg = "Sync não configurado. Acesse as configurações."
            lastError = msg
            return .failure(msg)
        }
        guard let baseURL = URL(string: settings.serverURL) else {
            let msg = "URL do servidor inválida."
            lastError = msg
            return .failure(msg)
        }

        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        do {
            // 1. Salva metadados em arquivo para incluir no sync
            store.saveMetadataToFile()

            // 2. Busca manifesto do servidor
            let serverManifest = try await fetchManifest(base: baseURL, apiKey: settings.apiKey)

            // 3. Lista arquivos locais
            let localFiles = collectLocalFiles()

            // 4. Compara e decide o que push/pull
            var toPush: [(localURL: URL, remotePath: String)] = []
            var toPull: [String] = []

            for (localURL, remotePath) in localFiles {
                let localMtime = (try? localURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? 0
                if let serverEntry = serverManifest[remotePath] {
                    if localMtime > serverEntry.mtime + 1 {
                        toPush.append((localURL, remotePath))
                    } else if serverEntry.mtime > localMtime + 1 {
                        toPull.append(remotePath)
                    }
                } else {
                    // Não existe no servidor → push
                    toPush.append((localURL, remotePath))
                }
            }

            // Arquivos que existem no servidor mas não localmente → pull
            let localRemotePaths = Set(localFiles.map { $0.remotePath })
            for remotePath in serverManifest.keys where !localRemotePaths.contains(remotePath) {
                toPull.append(remotePath)
            }

            // 5. Executa push (em lotes de 5 para não estourar memória)
            if !toPush.isEmpty {
                try await pushFiles(toPush, base: baseURL, apiKey: settings.apiKey)
            }

            // 6. Executa pull
            var pulledMetadata = false
            for remotePath in toPull {
                let localDest = localURL(for: remotePath)
                try await pullFile(remotePath: remotePath, to: localDest, base: baseURL, apiKey: settings.apiKey)
                if remotePath == "metadata.json" { pulledMetadata = true }
            }

            // 7. Se baixou metadados, recarrega o store
            if pulledMetadata {
                store.loadMetadataFromFile()
            }

            // 8. Converte cadernos para Markdown via FetchFlow (se configurado)
            if settings.fetchflowConfigured {
                await convertNotebooksToObsidian(
                    fetchflowKey: settings.fetchflowKey,
                    base: baseURL,
                    syncApiKey: settings.apiKey
                )
            }

            lastSyncDate = Date()
            return .success(pushed: toPush.count, pulled: toPull.count)

        } catch {
            let msg = error.localizedDescription
            lastError = msg
            return .failure(msg)
        }
    }

    // MARK: - FetchFlow → Obsidian Markdown

    func convertNotebooksToObsidian(fetchflowKey: String, base: URL, syncApiKey: String) async {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let obsidianDir = docs.appendingPathComponent("AICanvas_Obsidian")
        try? fm.createDirectory(at: obsidianDir, withIntermediateDirectories: true)

        for notebook in store.notebooks where notebook.type == .notebook || notebook.type == .whiteboard {
            let drawing = store.loadDrawing(for: notebook)
            guard !drawing.bounds.isEmpty else { continue }

            guard let image = renderDrawing(drawing) else { continue }
            guard let jpegData = image.jpegData(compressionQuality: 0.82) else { continue }
            let base64 = jpegData.base64EncodedString()

            guard let markdown = await callFetchFlow(
                apiKey: fetchflowKey,
                notebookName: notebook.name,
                imageBase64: base64
            ) else { continue }

            let filename = sanitizeFilename(notebook.name) + ".md"
            let localMD = obsidianDir.appendingPathComponent(filename)
            try? markdown.data(using: .utf8)?.write(to: localMD, options: .atomic)

            let remotePath = "obsidian/\(filename)"
            try? await pushFiles([(localMD, remotePath)], base: base, apiKey: syncApiKey)
        }
    }

    private func renderDrawing(_ drawing: PKDrawing) -> UIImage? {
        let bounds = drawing.bounds.insetBy(dx: -40, dy: -40)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        // Limita resolução para não estourar memória em desenhos muito grandes
        let scale: CGFloat = min(1.5, 3000 / max(bounds.width, bounds.height))
        var image: UIImage!
        let trait = UITraitCollection(userInterfaceStyle: .light)
        trait.performAsCurrent {
            image = drawing.image(from: bounds, scale: scale)
        }
        // Composta sobre fundo branco
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func callFetchFlow(apiKey: String, notebookName: String, imageBase64: String) async -> String? {
        guard let url = URL(string: "https://api.fetchflow.io/v1/chat/completions") else { return nil }

        let prompt = """
        Você recebeu uma imagem de anotações de um caderno chamado "\(notebookName)".
        Transcreva e organize TODO o conteúdo visível como um documento Markdown formatado para o Obsidian.
        Regras:
        - Use # para o título principal (nome do caderno)
        - Use ## e ### para seções identificadas
        - Preserve listas, fórmulas e estruturas visuais como tabelas Markdown quando possível
        - Se houver diagramas ou desenhos, descreva-os em bloco de citação > [Diagrama: ...]
        - Não invente conteúdo — transcreva apenas o que está visível
        - Retorne SOMENTE o Markdown, sem explicações adicionais
        """

        let body: [String: Any] = [
            "model": "swift",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url",
                         "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]],
                        ["type": "text", "text": prompt]
                    ]
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData
        req.timeoutInterval = 60

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }

        return content
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "-")
    }

    // MARK: - Local file enumeration

    private struct LocalFile {
        let url: URL
        let remotePath: String
    }

    private func collectLocalFiles() -> [(localURL: URL, remotePath: String)] {
        var result: [(URL, String)] = []
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let drawingsDir = docs.appendingPathComponent("AICanvas_Drawings")
        let pdfsDir = docs.appendingPathComponent("AICanvas_PDFs")

        // metadata.json lives in AICanvas_Drawings/
        let metaURL = drawingsDir.appendingPathComponent("metadata.json")
        if fm.fileExists(atPath: metaURL.path) {
            result.append((metaURL, "metadata.json"))
        }

        // Drawings and chat files
        if let items = try? fm.contentsOfDirectory(at: drawingsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for url in items {
                let ext = url.pathExtension.lowercased()
                guard ext == "drawing" || ext == "chat" else { continue }
                result.append((url, "drawings/\(url.lastPathComponent)"))
            }
        }

        // PDFs
        if let items = try? fm.contentsOfDirectory(at: pdfsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for url in items {
                guard url.pathExtension.lowercased() == "pdf" else { continue }
                result.append((url, "pdfs/\(url.lastPathComponent)"))
            }
        }

        return result
    }

    private func localURL(for remotePath: String) -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let drawingsDir = docs.appendingPathComponent("AICanvas_Drawings")
        let pdfsDir = docs.appendingPathComponent("AICanvas_PDFs")

        if remotePath == "metadata.json" {
            return drawingsDir.appendingPathComponent("metadata.json")
        } else if remotePath.hasPrefix("drawings/") {
            let name = String(remotePath.dropFirst("drawings/".count))
            return drawingsDir.appendingPathComponent(name)
        } else {
            let name = String(remotePath.dropFirst("pdfs/".count))
            return pdfsDir.appendingPathComponent(name)
        }
    }

    // MARK: - HTTP helpers

    private struct ManifestEntry: Decodable {
        let size: Int
        let mtime: Double
    }

    private struct ManifestResponse: Decodable {
        let files: [String: ManifestEntry]
    }

    private func fetchManifest(base: URL, apiKey: String) async throws -> [String: ManifestEntry] {
        var req = URLRequest(url: base.appendingPathComponent("sync/manifest"))
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateResponse(resp)
        let decoded = try JSONDecoder().decode(ManifestResponse.self, from: data)
        return decoded.files
    }

    private func pushFiles(_ files: [(localURL: URL, remotePath: String)], base: URL, apiKey: String) async throws {
        for (localURL, remotePath) in files {
            guard let data = try? Data(contentsOf: localURL) else { continue }
            let encoded = remotePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remotePath
            var req = URLRequest(url: base.appendingPathComponent("sync/push/\(encoded)"))
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.httpBody = data
            let (_, resp) = try await URLSession.shared.data(for: req)
            try validateResponse(resp)
        }
    }

    private func pullFile(remotePath: String, to dest: URL, base: URL, apiKey: String) async throws {
        let encodedPath = remotePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remotePath
        var req = URLRequest(url: base.appendingPathComponent("sync/pull/\(encodedPath)"))
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateResponse(resp)
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dest, options: .atomic)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.httpError(http.statusCode)
        }
    }

}

// MARK: - Errors

enum SyncError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Resposta inválida do servidor."
        case .httpError(let code): return "Erro HTTP \(code) do servidor."
        }
    }
}
