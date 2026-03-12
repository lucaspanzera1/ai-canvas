import SwiftUI
import Foundation

// MARK: - Model Information Database

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

// MARK: - Model Details Card

/// Enhanced model details card with performance metrics
struct ModelDetailsCard: View {
    let modelInfo: AIModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with model name
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelInfo.model.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(modelInfo.bestFor)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            
            // Performance metrics grid
            VStack(spacing: 8) {
                // Speed
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "hare.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Velocidade")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(modelInfo.speed.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text(modelInfo.speed.emoji)
                        .font(.system(size: 14))
                }
                
                // Quality
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Qualidade")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(modelInfo.quality.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text(modelInfo.quality.emoji)
                        .font(.system(size: 14))
                }
                
                // Cost
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Custo")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(modelInfo.cost.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text(modelInfo.cost.emoji)
                        .font(.system(size: 14))
                }
            }
            
            Divider()
                .overlay(AppTheme.border)
            
            // Additional info
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Label("Lançamento", systemImage: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(modelInfo.releaseDate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                HStack(spacing: 6) {
                    Label("Tokens", systemImage: "function")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%,d", modelInfo.maxTokens))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                HStack(spacing: 6) {
                    Label("Visão", systemImage: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(modelInfo.supportsVision ? "Suportada" : "Não suportada")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(modelInfo.supportsVision ? Color.green : AppTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
    }
}

/// Comparison view for multiple models
struct ModelComparisonView: View {
    let models: [AIModelInfo]
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comparar Modelos")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Alente características e desempenho")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)
                
                // Models list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(models, id: \.model.id) { modelInfo in
                            ModelDetailsCard(modelInfo: modelInfo)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

#Preview {
    ModelDetailsCard(
        modelInfo: ModelInfoDatabase.shared.getModelInfo(for: "gpt-4o") ?? 
        AIModelInfo(
            model: AIModel(id: "test", name: "Test Model", provider: .openai),
            speed: .fast,
            quality: .excellent,
            cost: .medium,
            bestFor: "Test",
            maxTokens: 8000,
            supportsVision: true,
            releaseDate: "2024"
        )
    )
    .padding()
    .background(AppTheme.background)
}
