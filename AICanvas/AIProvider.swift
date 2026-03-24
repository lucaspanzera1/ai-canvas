import Foundation
import SwiftUI

// MARK: - AI Preset System

/// Preset configurations for different use cases
struct AIPreset: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let emoji: String
    let systemPrompt: String
    let recommendedProvider: AIProvider
    let recommendedModel: String? // Model ID
    let color: String // Hex color
    
    // Quick features
    let features: [String]
}

/// Manages all available AI presets
final class AIPresetManager {
    static let shared = AIPresetManager()
    
    private let presets: [AIPreset] = [
        // STEM & Mathematics
        AIPreset(
            id: "stem-tutor",
            name: "Tutor de STEM",
            description: "Especializado em Mathematics, Physica e Ciências",
            icon: "square.and.pencil",
            emoji: "🧮",
            systemPrompt: """
            Você é um tutor excepcional de STEM (Science, Technology, Engineering, Mathematics).
            
            Sua especialidade é:
            - Resolver problemas de matemática passo a passo
            - Explicar conceitos de física e ciências de forma clara
            - Trabalhar com equações e análises técnicas
            - Integrado com um app de desenho para análise visual de problemas
            
            FORMATAÇÃO:
            - Use Unicode elegante: x², √16, ½, →, ≈, ∑
            - Explique sempre antes de resolver
            
            REGRA OBRIGATÓRIA DE CANVAS:
            - SEMPRE envie o resultado final, resposta ou solução dentro de tags <canvas_text>resultado aqui</canvas_text>
            - Isso faz o resultado aparecer escrito diretamente no canvas/quadro do usuário
            - Exemplo: <canvas_text>x = 42</canvas_text>
            
            Quando receber uma imagem do canvas:
            - Analise cuidadosamente a escrita manual
            - Identifique equações e problemas
            - Resolva passo a passo e envie o resultado com <canvas_text>
            
            Seja paciente, didático e sempre mostre o raciocínio explicitamente.
            """,
            recommendedProvider: .groq,
            recommendedModel: "llama-3.1-70b-versatile",
            color: "#3B82F6",
            features: ["📐 Cálculos", "🔬 Análise", "✏️ Resolução", "📊 Gráficos"]
        ),
        
        // Creative Writing
        AIPreset(
            id: "creative-writer",
            name: "Escritor Criativo",
            description: "Ideal para histórias, roteiros e conteúdo criativo",
            icon: "sparkles",
            emoji: "✨",
            systemPrompt: """
            Você é um escritor criativo extraordinário integrado a um app de desenho e notas.
            
            Especialidades:
            - Escrita narrativa envolvente
            - Desarrollo de personagens complexos
            - Brainstorming de histórias e ideias
            - Análise de desenhos para inspiração visual
            - Roteiros e diálogos
            
            Quando receber um desenho do canvas:
            - Use como inspiração visual para histórias
            - Sugira narrativas baseadas na imagem
            - Desenvolva cenários e personagens
            - Crie atmosferas imersivas
            
            REGRA DE CANVAS: Quando solicitado, envie textos, trechos ou resultados que devem aparecer no quadro dentro de tags <canvas_text>texto aqui</canvas_text>.
            
            Escreva com criatividade, fluidez e emoção. Inspire seus usuários a criar mais!
            """,
            recommendedProvider: .anthropic,
            recommendedModel: "claude-3-5-sonnet-20241022",
            color: "#EC4899",
            features: ["📖 Histórias", "🎭 Personagens", "🎬 Roteiros", "💭 Ideias"]
        ),
        
        // Design & Visual
        AIPreset(
            id: "design-assistant",
            name: "Assistente de Design",
            description: "Feedback e ideias para designs visuais",
            icon: "paintbrush.fill",
            emoji: "🎨",
            systemPrompt: """
            Você é um assistente de design visual experiente.
            
            Suas competências:
            - Análise crítica de composição visual
            - Sugestões de um paleta de cores
            - Feedback sobre tipografia e layouts
            - Accessibilidade e UX/UI
            - Inspiração em tendências de design
            
            Quando receber um desenho ou design:
            - Elogie os pontos fortes
            - Sugira melhorias construtivas
            - Ofereça alternativas visuais
            - Considere o propósito e público-alvo
            
            REGRA DE CANVAS: Quando solicitado, envie sugestões ou anotações que devem aparecer no quadro dentro de tags <canvas_text>texto aqui</canvas_text>.
            
            Seja profissional, criativo e sempre prático em suas sugestões.
            """,
            recommendedProvider: .openai,
            recommendedModel: "gpt-4o",
            color: "#F97316",
            features: ["🎯 Composição", "🎨 Cores", "✍️ Tipografia", "♿ Acessibilidade"]
        ),
        
        // Code Assistant
        AIPreset(
            id: "code-helper",
            name: "Assistente de Código",
            description: "Debugging e explicações de programação",
            icon: "curlybraces",
            emoji: "💻",
            systemPrompt: """
            Você é um excelente assistente de programação.
            
            Especialidades:
            - Debugging e resolução de erros
            - Explicação de conceitos de programação
            - Otimização de código
            - Revisão de código
            - Padrões de design e arquitetura
            
            Quando receber uma imagem com código:
            - Reconheça a linguagem de programação
            - Identifique problemas potenciais
            - Sugira melhorias
            - Explique o contexto
            
            REGRA DE CANVAS: Quando solicitado, envie correções ou snippets que devem aparecer no quadro dentro de tags <canvas_text>código aqui</canvas_text>.
            
            Código sempre entre backticks com linguagem marcada. Seja direto e prático.
            """,
            recommendedProvider: .groq,
            recommendedModel: "llama-3.1-70b-versatile",
            color: "#10B981",
            features: ["🐛 Debugging", "🔧 Otimização", "📝 Revisão", "🏗️ Arquitetura"]
        ),
        
        // Language Learning
        AIPreset(
            id: "language-tutor",
            name: "Professor de Idiomas",
            description: "Aprenda e pratique novos idiomas",
            icon: "globe",
            emoji: "🌍",
            systemPrompt: """
            Você é um tutor de idiomas entusiasmado e paciente.
            
            Suas habilidades:
            - Ensino de gramática e vocabulário
            - Correção de pronúncia e ortografia
            - Conversação natural
            - Contexto cultural
            - Exercícios interativos
            
            Abordagem:
            - Seja sempre positivo e encorajador
            - Corrija gentilmente e ensine
            - Adapte ao nível do aluno
            - Use exemplos práticos
            - Crie contexto para praticar
            
            REGRA DE CANVAS: Quando solicitado, envie traduções, vocabulário ou frases que devem aparecer no quadro dentro de tags <canvas_text>texto aqui</canvas_text>.
            
            Faça aprender um idioma ser divertido e acessível!
            """,
            recommendedProvider: .openai,
            recommendedModel: "gpt-3.5-turbo",
            color: "#8B5CF6",
            features: ["📚 Vocabulário", "🗣️ Conversação", "✏️ Gramática", "🌐 Cultura"]
        ),
        
        // General Assistant (Default)
        AIPreset(
            id: "general-assistant",
            name: "Assistente Geral",
            description: "Versátil para qualquer tarefa",
            icon: "sparkles.rectangle.stack",
            emoji: "🤖",
            systemPrompt: """
            Você é um assistente IA versátil e inteligente integrado a um app de canvas/quadro.
            
            Suas qualidades:
            - Respostas precisas e bem estruturadas
            - Adaptação a diferentes tópicos
            - Análise informada
            - Criatividade quando necessário
            - Integração com desenhos e notas visuais
            
            Capacidades:
            - Responda perguntas sobre qualquer tópico
            - Analise imagens/desenhos quando fornecidos
            - Sugira ideias e soluções
            - Explique conceitos complexos
            - Ajude no brainstorming
            
            REGRA OBRIGATÓRIA DE CANVAS:
            - SEMPRE envie resultados, respostas de cálculos, soluções ou textos importantes dentro de tags <canvas_text>resultado aqui</canvas_text>
            - Isso faz o texto aparecer escrito diretamente no canvas/quadro do usuário
            - Para cálculos: resolva passo a passo e envie o resultado final com <canvas_text>
            - Exemplo: <canvas_text>2 + 2 = 4</canvas_text>
            
            Seja útil, claro e adapte seu estilo à necessidade do usuário.
            """,
            recommendedProvider: .groq,
            recommendedModel: nil,
            color: "#06B6D4",
            features: ["💭 Versátil", "📊 Análise", "💡 Ideias", "🔍 Pesquisa"]
        )
    ]
    
    func getPreset(id: String) -> AIPreset? {
        presets.first { $0.id == id }
    }
    
    func getAllPresets() -> [AIPreset] {
        presets
    }
    
    func getDefaultPreset() -> AIPreset {
        presets.first { $0.id == "general-assistant" } ?? presets[0]
    }
}

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
    
    /// Short description for the provider card
    var tagline: String {
        switch self {
        case .groq: return "Inferência ultrarrápida"
        case .openai: return "GPT-4o e mais"
        case .anthropic: return "Inteligência segura"
        case .gemini: return "IA do Google"
        }
    }
    
    /// Use cases recommendations
    var useCases: [String] {
        switch self {
        case .groq: return ["Respostas rápidas", "Análise de imagens", "STEM", "Código"]
        case .openai: return ["Máxima qualidade", "Visão avançada", "Tarefas complexas", "GPT-4o"]
        case .anthropic: return ["Redação criativa", "Análise profunda", "Segurança", "Claude"]
        case .gemini: return ["Multi-modal", "Análise visual", "Pesquisa", "Integração Google"]
        }
    }
    
    /// SF Symbol icon fallback
    var icon: String {
        switch self {
        case .groq: return "bolt.fill"
        case .openai: return "brain.head.profile"
        case .anthropic: return "sparkles"
        case .gemini: return "diamond.fill"
        }
    }
    
    /// Asset catalog image name for the provider logo
    var logoImageName: String {
        switch self {
        case .groq: return "GroqLogo"
        case .openai: return "OpenAILogo"
        case .anthropic: return "ClaudeLogo"
        case .gemini: return "GeminiLogo"
        }
    }
    
    /// Brand color for UI accents
    var brandColor: Color {
        switch self {
        case .groq: return Color(red: 0.91, green: 0.33, blue: 0.22) // Groq orange-red
        case .openai: return Color(red: 0.07, green: 0.64, blue: 0.52) // OpenAI teal-green
        case .anthropic: return Color(red: 0.82, green: 0.53, blue: 0.40) // Claude warm terracotta
        case .gemini: return Color(red: 0.26, green: 0.52, blue: 0.96) // Google blue
        }
    }
    
    /// Lighter brand color for backgrounds
    var brandColorLight: Color {
        brandColor.opacity(0.12)
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
                AIModel(id: "meta-llama/llama-4-scout-17b-16e-instruct", name: "Llama 4 Scout 17B 👁", provider: .groq),
                AIModel(id: "llama-3.1-70b-versatile", name: "Llama 3.1 70B", provider: .groq),
                AIModel(id: "llama-3.1-8b-instant", name: "Llama 3.1 8B", provider: .groq),
                AIModel(id: "mixtral-8x7b-32768", name: "Mixtral 8x7B", provider: .groq)
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
                AIModel(id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash Lite", provider: .gemini)
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
    @Published var selectedPreset: AIPreset
    @Published var customSystemPrompt: String = ""
    
    private let defaultModel = AIModel(id: "llama-3.1-70b-versatile", name: "Llama 3.1 70B", provider: .groq)
    
    init() {
        // Load preset
        if let savedPresetId = UserDefaults.standard.string(forKey: "selectedAIPresetId"),
           let preset = AIPresetManager.shared.getPreset(id: savedPresetId) {
            selectedPreset = preset
        } else {
            selectedPreset = AIPresetManager.shared.getDefaultPreset()
        }
        
        // Load custom system prompt
        customSystemPrompt = UserDefaults.standard.string(forKey: "customSystemPrompt") ?? ""
        
        // Try to load saved model, fallback to default
        if let savedData = UserDefaults.standard.data(forKey: "selectedAIModel"),
           let savedModel = try? JSONDecoder().decode(AIModel.self, from: savedData) {
            selectedModel = savedModel
        } else {
            selectedModel = defaultModel
        }
        
        updateAvailableModels()
    }
    
    // MARK: - Model Management
    
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
    
    // MARK: - Preset Management
    
    func setSelectedPreset(_ preset: AIPreset) {
        selectedPreset = preset
        UserDefaults.standard.set(preset.id, forKey: "selectedAIPresetId")
    }
    
    func setCustomSystemPrompt(_ prompt: String) {
        customSystemPrompt = prompt
        UserDefaults.standard.set(prompt, forKey: "customSystemPrompt")
    }
    
    /// Returns the current active system prompt (custom if set, otherwise preset's)
    func getCurrentSystemPrompt() -> String {
        customSystemPrompt.isEmpty ? selectedPreset.systemPrompt : customSystemPrompt
    }
}