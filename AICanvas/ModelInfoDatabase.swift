import Foundation

/// Enhanced model information with characteristics
struct AIModelInfo {
    let model: AIModel
    let speed: ModelSpeed
    let quality: ModelQuality
    let cost: ModelCost
    let bestFor: String
    let maxTokens: Int
    let supportsVision: Bool
    let releaseDate: String
}

enum ModelSpeed: String, Codable {
    case ultraFast = "Ultra-rápido"
    case veryFast = "Muito rápido"
    case fast = "Rápido"
    case balanced = "Equilibrado"
    case slow = "Lento"
    
    var emoji: String {
        switch self {
        case .ultraFast: return "⚡⚡⚡"
        case .veryFast: return "⚡⚡"
        case .fast: return "⚡"
        case .balanced: return "⚙️"
        case .slow: return "🐢"
        }
    }
}

enum ModelQuality: String, Codable {
    case excellent = "Excelente"
    case veryGood = "Muito Bom"
    case good = "Bom"
    case fair = "Razoável"
    case basic = "Básico"
    
    var emoji: String {
        switch self {
        case .excellent: return "⭐⭐⭐⭐⭐"
        case .veryGood: return "⭐⭐⭐⭐"
        case .good: return "⭐⭐⭐"
        case .fair: return "⭐⭐"
        case .basic: return "⭐"
        }
    }
}

enum ModelCost: String, Codable {
    case free = "Gratuito"
    case veryLow = "Muito Baixo"
    case low = "Baixo"
    case medium = "Médio"
    case high = "Alto"
    
    var emoji: String {
        switch self {
        case .free: return "🎁"
        case .veryLow: return "💚"
        case .low: return "💙"
        case .medium: return "💛"
        case .high: return "❤️"
        }
    }
}

/// Database of model information
final class ModelInfoDatabase {
    static let shared = ModelInfoDatabase()
    
    private lazy var modelInfoMap: [String: AIModelInfo] = [
        // Groq Models
        "meta-llama/llama-4-scout-17b-16e-instruct": AIModelInfo(
            model: AIModel(id: "meta-llama/llama-4-scout-17b-16e-instruct", name: "Llama 4 Scout 17B 👁", provider: .groq),
            speed: .ultraFast,
            quality: .veryGood,
            cost: .free,
            bestFor: "Análise visual rápida, vision tasks",
            maxTokens: 8192,
            supportsVision: true,
            releaseDate: "2024"
        ),
        "llama-3.1-70b-versatile": AIModelInfo(
            model: AIModel(id: "llama-3.1-70b-versatile", name: "Llama 3.1 70B", provider: .groq),
            speed: .veryFast,
            quality: .excellent,
            cost: .free,
            bestFor: "Propósitos gerais, STEM, código",
            maxTokens: 8192,
            supportsVision: false,
            releaseDate: "2024"
        ),
        "llama-3.1-8b-instant": AIModelInfo(
            model: AIModel(id: "llama-3.1-8b-instant", name: "Llama 3.1 8B", provider: .groq),
            speed: .ultraFast,
            quality: .good,
            cost: .free,
            bestFor: "Respostas rápidas, conversas leves",
            maxTokens: 8192,
            supportsVision: false,
            releaseDate: "2024"
        ),
        "mixtral-8x7b-32768": AIModelInfo(
            model: AIModel(id: "mixtral-8x7b-32768", name: "Mixtral 8x7B", provider: .groq),
            speed: .veryFast,
            quality: .veryGood,
            cost: .free,
            bestFor: "Equilíbrio de velocidade e qualidade",
            maxTokens: 32768,
            supportsVision: false,
            releaseDate: "2023"
        ),
        
        // OpenAI Models
        "gpt-4o": AIModelInfo(
            model: AIModel(id: "gpt-4o", name: "GPT-4o", provider: .openai),
            speed: .fast,
            quality: .excellent,
            cost: .medium,
            bestFor: "Tarefas complexas, análise profunda, vision",
            maxTokens: 128000,
            supportsVision: true,
            releaseDate: "2024"
        ),
        "gpt-4": AIModelInfo(
            model: AIModel(id: "gpt-4", name: "GPT-4", provider: .openai),
            speed: .balanced,
            quality: .excellent,
            cost: .high,
            bestFor: "Máxima qualidade, tarefas críticas",
            maxTokens: 8192,
            supportsVision: true,
            releaseDate: "2023"
        ),
        "gpt-3.5-turbo": AIModelInfo(
            model: AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openai),
            speed: .veryFast,
            quality: .good,
            cost: .low,
            bestFor: "Custo-benefício, uso geral",
            maxTokens: 4096,
            supportsVision: false,
            releaseDate: "2023"
        ),
        
        // Claude Models
        "claude-3-5-sonnet-20241022": AIModelInfo(
            model: AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: .anthropic),
            speed: .fast,
            quality: .excellent,
            cost: .medium,
            bestFor: "Redação, análise, criatividade",
            maxTokens: 200000,
            supportsVision: true,
            releaseDate: "2024"
        ),
        "claude-3-opus-20240229": AIModelInfo(
            model: AIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: .anthropic),
            speed: .balanced,
            quality: .excellent,
            cost: .high,
            bestFor: "Máxima inteligência, raciocínio complexo",
            maxTokens: 200000,
            supportsVision: true,
            releaseDate: "2024"
        ),
        "claude-3-haiku-20240307": AIModelInfo(
            model: AIModel(id: "claude-3-haiku-20240307", name: "Claude 3 Haiku", provider: .anthropic),
            speed: .ultraFast,
            quality: .good,
            cost: .veryLow,
            bestFor: "Respostas rápidas, custos baixos",
            maxTokens: 200000,
            supportsVision: true,
            releaseDate: "2024"
        ),
        
        // Gemini Models
        "gemini-2.5-flash-lite": AIModelInfo(
            model: AIModel(id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash Lite", provider: .gemini),
            speed: .ultraFast,
            quality: .veryGood,
            cost: .free,
            bestFor: "Respostas rápidas, análise leve",
            maxTokens: 1000000,
            supportsVision: true,
            releaseDate: "2024"
        )
    ]
    
    func getModelInfo(_ model: AIModel) -> AIModelInfo? {
        modelInfoMap[model.id]
    }
    
    func getModelInfo(for modelId: String) -> AIModelInfo? {
        modelInfoMap[modelId]
    }
    
    func getModelsInfo(for provider: AIProvider) -> [AIModelInfo] {
        provider.defaultModels.compactMap { getModelInfo($0) }
    }
}
