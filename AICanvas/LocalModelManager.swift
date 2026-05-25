import Foundation
import Combine

// MARK: - Catalog Entry

struct LocalModelInfo: Identifiable, Hashable {
    let id: String          // filename (e.g. "Llama-3.2-1B-Instruct-Q4_K_M.gguf")
    let name: String
    let description: String
    let parametersLabel: String
    let quantization: String
    let sizeGB: Double
    let downloadURL: String
    let promptFormat: PromptFormat

    var filename: String { id }
    var sizeLabel: String { String(format: "%.1f GB", sizeGB) }

    static func == (lhs: LocalModelInfo, rhs: LocalModelInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Manager

@MainActor
final class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()

    @Published var catalog: [LocalModelInfo] = []
    @Published var downloadingModelId: String?
    @Published var downloadProgress: Double = 0
    @Published var downloadError: String?

    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?

    private let modelsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("LocalModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let rawCatalog: [LocalModelInfo] = [
        LocalModelInfo(
            id: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            name: "Llama 3.2 1B",
            description: "Modelo rápido e leve da Meta. Ideal para respostas rápidas.",
            parametersLabel: "1B", quantization: "Q4_K_M", sizeGB: 0.77,
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            promptFormat: .llama3
        ),
        LocalModelInfo(
            id: "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
            name: "Qwen 2.5 1.5B",
            description: "Modelo compacto da Alibaba com excelente qualidade para o tamanho.",
            parametersLabel: "1.5B", quantization: "Q4_K_M", sizeGB: 1.0,
            downloadURL: "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
            promptFormat: .chatml
        ),
        LocalModelInfo(
            id: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            name: "Llama 3.2 3B",
            description: "Versão maior do Llama 3.2 com melhor raciocínio e qualidade.",
            parametersLabel: "3B", quantization: "Q4_K_M", sizeGB: 1.9,
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            promptFormat: .llama3
        ),
        LocalModelInfo(
            id: "gemma-2-2b-it-Q4_K_M.gguf",
            name: "Gemma 2 2B",
            description: "Modelo eficiente do Google com ótima qualidade de resposta.",
            parametersLabel: "2B", quantization: "Q4_K_M", sizeGB: 1.6,
            downloadURL: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf",
            promptFormat: .chatml
        ),
        LocalModelInfo(
            id: "Phi-3-mini-4k-instruct-Q4_K_M.gguf",
            name: "Phi-3 Mini",
            description: "Modelo da Microsoft otimizado para raciocínio e código.",
            parametersLabel: "3.8B", quantization: "Q4_K_M", sizeGB: 2.3,
            downloadURL: "https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf",
            promptFormat: .phi3
        ),
    ]

    private init() {
        refreshCatalog()
    }

    // MARK: - Catalog

    func refreshCatalog() {
        let installed = installedFilenames()
        catalog = Self.rawCatalog.map { info in
            var m = info
            _ = m // suppress unused warning; isInstalled is read-only above
            return info
        }
        updateModelsCache()
    }

    private func installedFilenames() -> Set<String> {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: modelsDirectory.path)) ?? []
        return Set(files.filter { $0.hasSuffix(".gguf") })
    }

    func isInstalled(_ info: LocalModelInfo) -> Bool {
        FileManager.default.fileExists(atPath: modelsDirectory.appendingPathComponent(info.filename).path)
    }

    // MARK: - Paths

    func modelPath(for model: AIModel) -> String {
        modelsDirectory.appendingPathComponent(model.id).path
    }

    func installedModels() -> [AIModel] {
        let installed = installedFilenames()
        return installed.map { filename in
            let name = Self.rawCatalog.first(where: { $0.filename == filename })?.name
                ?? filename.replacingOccurrences(of: ".gguf", with: "")
            return AIModel(id: filename, name: name, provider: .local)
        }.sorted { $0.name < $1.name }
    }

    func promptFormat(for model: AIModel) -> PromptFormat {
        Self.rawCatalog.first(where: { $0.filename == model.id })?.promptFormat ?? .chatml
    }

    var hasInstalledModels: Bool {
        !installedFilenames().isEmpty
    }

    // MARK: - Delete

    func deleteModel(_ info: LocalModelInfo) {
        let url = modelsDirectory.appendingPathComponent(info.filename)
        try? FileManager.default.removeItem(at: url)
        if !hasInstalledModels {
            KeychainManager.shared.deleteKey(for: .local)
        }
        updateModelsCache()
    }

    // MARK: - Download

    func download(_ info: LocalModelInfo) {
        guard downloadingModelId == nil else { return }
        guard let url = URL(string: info.downloadURL) else { return }

        downloadingModelId = info.id
        downloadProgress = 0
        downloadError = nil

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600 // 1 hour for large models
        let session = URLSession(configuration: config)

        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    self.downloadingModelId = nil
                    self.downloadProgress = 0
                    self.progressObservation = nil
                }
                if let error = error {
                    self.downloadError = error.localizedDescription
                    return
                }
                guard let tempURL else {
                    self.downloadError = "Download falhou sem URL temporária."
                    return
                }
                let dest = self.modelsDirectory.appendingPathComponent(info.filename)
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    KeychainManager.shared.saveKey("configured", for: .local)
                    self.updateModelsCache()
                    self.refreshCatalog()
                } catch {
                    self.downloadError = "Erro ao salvar: \(error.localizedDescription)"
                }
            }
        }

        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                self?.downloadProgress = progress.fractionCompleted
            }
        }

        downloadTask = task
        task.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadingModelId = nil
        downloadProgress = 0
    }

    // MARK: - Cache (for AIProvider.local.defaultModels)

    private func updateModelsCache() {
        let models = installedModels()
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: "local_installed_models_cache")
        }
    }
}
