import Foundation

// MARK: - Settings

struct SyncSettings: Codable {
    var serverURL: String   // ex: https://sync.seudominio.com
    var apiKey: String

    static let empty = SyncSettings(serverURL: "", apiKey: "")

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

            lastSyncDate = Date()
            return .success(pushed: toPush.count, pulled: toPull.count)

        } catch {
            let msg = error.localizedDescription
            lastError = msg
            return .failure(msg)
        }
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
        // Push in batches of 5
        let batchSize = 5
        var offset = 0
        while offset < files.count {
            let batch = Array(files[offset..<min(offset + batchSize, files.count)])
            try await pushBatch(batch, base: base, apiKey: apiKey)
            offset += batchSize
        }
    }

    private func pushBatch(_ batch: [(localURL: URL, remotePath: String)], base: URL, apiKey: String) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: base.appendingPathComponent("sync/push"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (url, path) in batch {
            guard let data = try? Data(contentsOf: url) else { continue }
            let mimeType = mimeType(for: url.pathExtension)

            // paths field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"paths\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(path)\r\n".data(using: .utf8)!)

            // files field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (_, resp) = try await URLSession.shared.data(for: req)
        try validateResponse(resp)
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

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "application/pdf"
        case "json": return "application/json"
        default: return "application/octet-stream"
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
