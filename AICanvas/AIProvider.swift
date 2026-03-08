import Foundation

/// Supported AI providers and their configurations.
enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case groq = "groq"
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .anthropic: return "Claude"
        case .gemini: return "Gemini"
        }
    }
    
    var icon: String {
        switch self {
        case .groq: return "bolt.fill"
        case .openai: return "brain.head.profile"
        case .anthropic: return "sparkles"
        case .gemini: return "diamond.fill"
        }
    }
    
    var baseURL: String {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .openai:
            return "https://api.openai.com/v1/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models"
        }
    }
    
    var keyPlaceholder: String {
        switch self {
        case .groq: return "gsk_..."
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .gemini: return "AIza..."
        }
    }
    
    var keyDocURL: String {
        switch self {
        case .groq:
            return "https://console.groq.com/keys"
        case .openai:
            return "https://platform.openai.com/api-keys"
        case .anthropic:
            return "https://console.anthropic.com/account/keys"
        case .gemini:
            return "https://aistudio.google.com/app/apikey"
        }
    }
    
    var defaultModels: [AIModel] {
        switch self {
        case .groq:
            return [
                AIModel(id: "llama-3.1-70b-versatile", name: "Llama 3.1 70B", provider: .groq),
                AIModel(id: "llama-3.1-8b-instant", name: "Llama 3.1 8B", provider: .groq),
                AIModel(id: "mixtral-8x7b-32768", name: "Mixtral 8x7B", provider: .groq),
                AIModel(id: "gemma-7b-it", name: "Gemma 7B", provider: .groq)
            ]
        case .openai:
            return [
                AIModel(id: "gpt-4o", name: "GPT-4o", provider: .openai),
                AIModel(id: "gpt-4", name: "GPT-4", provider: .openai),
                AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openai)
            ]
        case .anthropic:
            return [
                AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: .anthropic),
                AIModel(id: "claude-3-haiku-20240307", name: "Claude 3 Haiku", provider: .anthropic),
                AIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: .anthropic)
            ]
        case .gemini:
            return [
                AIModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: .gemini),
                AIModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: .gemini)
            ]
        }
    }
}

/// Individual AI model configuration.
struct AIModel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let provider: AIProvider
    
    var displayName: String {
        "\(provider.displayName) • \(name)"
    }
}

/// Current AI configuration state.
@MainActor
final class AIConfiguration: ObservableObject {
    @Published var selectedModel: AIModel
    @Published var availableModels: [AIModel] = []
    
    private let defaultModel = AIModel(id: "llama-3.1-70b-versatile", name: "Llama 3.1 70B", provider: .groq)
    
    init() {
        // Try to load saved model, fallback to default
        if let savedData = UserDefaults.standard.data(forKey: "selectedAIModel"),
           let savedModel = try? JSONDecoder().decode(AIModel.self, from: savedData) {
            selectedModel = savedModel
        } else {
            selectedModel = defaultModel
        }
        
        updateAvailableModels()
    }
    
    func setSelectedModel(_ model: AIModel) {
        selectedModel = model
        saveSelectedModel()
    }
    
    func updateAvailableModels() {
        var models: [AIModel] = []
        
        for provider in AIProvider.allCases {
            if KeychainManager.shared.hasAPIKey(for: provider) {
                models.append(contentsOf: provider.defaultModels)
            }
        }
        
        availableModels = models
        
        // If selected model is no longer available, switch to first available or default
        if !models.contains(selectedModel) {
            selectedModel = models.first ?? defaultModel
            saveSelectedModel()
        }
    }
    
    private func saveSelectedModel() {
        if let data = try? JSONEncoder().encode(selectedModel) {
            UserDefaults.standard.set(data, forKey: "selectedAIModel")
        }
    }
}