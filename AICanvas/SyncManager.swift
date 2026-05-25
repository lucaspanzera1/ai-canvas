import Foundation
import CryptoKit
import PencilKit
import UIKit
import Vision

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

            // 4. Compara por SHA-256 — só transfere se conteúdo realmente mudou
            var toPush: [(localURL: URL, remotePath: String)] = []
            var toPull: [String] = []

            for (localURL, remotePath) in localFiles {
                let localHash = sha256(of: localURL)
                if let serverEntry = serverManifest[remotePath] {
                    guard localHash != serverEntry.sha256 else { continue } // igual → skip
                    let localMtime = (try? localURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate?.timeIntervalSince1970 ?? 0
                    if localMtime >= serverEntry.mtime {
                        toPush.append((localURL, remotePath))
                    } else {
                        toPull.append(remotePath)
                    }
                } else {
                    toPush.append((localURL, remotePath))
                }
            }

            // Arquivos que existem só no servidor → pull
            let localRemotePaths = Set(localFiles.map { $0.remotePath })
            for remotePath in serverManifest.keys where !localRemotePaths.contains(remotePath) {
                // Ignora .md do obsidian no pull — são gerados localmente pelo app
                guard !remotePath.hasPrefix("obsidian/") else { continue }
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
                let serverMtime = serverManifest[remotePath]?.mtime
                try await pullFile(remotePath: remotePath, to: localDest, base: baseURL, apiKey: settings.apiKey, serverMtime: serverMtime)
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
            // Só reconverte se o drawing mudou após o último .md gerado
            let mdURL = obsidianDir.appendingPathComponent(sanitizeFilename(notebook.name) + ".md")
            let drawingURL = store.drawingFileURL(for: notebook)
            if let mdMtime = (try? mdURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               let drawingMtime = (try? drawingURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               drawingMtime <= mdMtime {
                continue
            }

            let drawing = store.loadDrawing(for: notebook)
            guard !drawing.bounds.isEmpty else { continue }

            guard let image = renderDrawing(drawing) else { continue }

            // OCR on-device → extrai texto antes de enviar para FetchFlow
            let recognizedText = await recognizeText(from: image)

            let markdown: String
            if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Caderno visual sem texto detectável: gera placeholder
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .none
                markdown = "# \(notebook.name)\n\n> Caderno sem texto identificável via OCR.\n> Última modificação: \(formatter.string(from: notebook.lastModified))\n"
            } else if let formatted = await callFetchFlow(
                apiKey: fetchflowKey,
                notebookName: notebook.name,
                recognizedText: recognizedText
            ) {
                markdown = formatted
            } else {
                // FetchFlow falhou: salva o texto bruto do OCR
                markdown = "# \(notebook.name)\n\n\(recognizedText)\n"
            }

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

    private func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["pt-BR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func callFetchFlow(apiKey: String, notebookName: String, recognizedText: String) async -> String? {
        guard let url = URL(string: "https://api.fetchflow.io/v1/chat/completions") else { return nil }

        let prompt = """
        Você é um formatador de anotações manuscritas para o Obsidian.
        O texto abaixo foi extraído via OCR de um caderno chamado "\(notebookName)".
        Converta para Markdown compatível com Obsidian seguindo EXATAMENTE estas regras:

        ESTRUTURA:
        - Primeira linha: # \(notebookName)
        - Seções identificadas: ## Título da Seção
        - Subseções: ### Subtítulo

        TAREFAS E CHECKLISTS:
        - Quadrinho vazio [ ] ou □ ou ○ antes de texto → - [ ] texto
        - Quadrinho marcado [x] ou [✓] ou ☑ ou riscado → - [x] texto
        - Lista simples com traço ou bullet → - item

        DESTAQUES:
        - Texto sublinhado ou com asterisco → **texto** (negrito)
        - Texto em itálico ou inclinado → *texto*
        - Texto entre aspas ou destacado → `código` se parecer técnico

        CALLOUTS DO OBSIDIAN (use quando o contexto indicar):
        - Nota importante → > [!note] conteúdo
        - Aviso ou atenção → > [!warning] conteúdo
        - Ideia → > [!tip] conteúdo
        - Tarefa urgente → > [!todo] conteúdo

        OUTROS:
        - Datas no formato dd/mm/aaaa → mantenha como estão
        - Palavras com # antes → #tag (tag do Obsidian)
        - Referências a outros cadernos → [[Nome do Caderno]]
        - Tabelas identificadas → converta para tabela Markdown com | col | col |
        - Fórmulas matemáticas → $formula$ (LaTeX inline)
        - Corrija erros óbvios de OCR (letras trocadas, espaços errados) mantendo o sentido

        IMPORTANTE:
        - Retorne SOMENTE o Markdown, sem explicações, sem blocos de código envolvendo o resultado
        - Não invente conteúdo que não esteja no texto original

        Texto extraído via OCR:
        \(recognizedText)
        """

        let body: [String: Any] = [
            "model": "swift",
            "messages": [["role": "user", "content": prompt]]
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
        let sha256: String
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
            let (respData, resp) = try await URLSession.shared.data(for: req)
            try validateResponse(resp)
            // Sincroniza mtime local com o mtime que o servidor atribuiu ao arquivo,
            // evitando que o próximo sync considere o arquivo "modificado" novamente.
            if let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let serverMtime = json["mtime"] as? Double {
                let date = Date(timeIntervalSince1970: serverMtime)
                try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: localURL.path)
            }
        }
    }

    private func pullFile(remotePath: String, to dest: URL, base: URL, apiKey: String, serverMtime: Double? = nil) async throws {
        let encodedPath = remotePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remotePath
        var req = URLRequest(url: base.appendingPathComponent("sync/pull/\(encodedPath)"))
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateResponse(resp)
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dest, options: .atomic)
        // Espelha o mtime do servidor para evitar re-pull no próximo sync
        if let mtime = serverMtime {
            let date = Date(timeIntervalSince1970: mtime)
            try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: dest.path)
        }
    }

    private func sha256(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
