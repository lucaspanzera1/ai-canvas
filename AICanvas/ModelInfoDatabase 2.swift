// ModelInfoDatabase.swift
import Foundation

final class ModelInfoDatabase {
    static let shared = ModelInfoDatabase()
    private init() {}

    // Minimal hardcoded catalog for the models you ship in AIProvider.defaultModels
    private let catalog: [String: ModelInfo] = {
        var dict: [String: ModelInfo] = [:]

        // Groq
        dict["meta-llama/llama-4-scout-17b-16e-instruct"] = ModelInfo(
            id: "meta-llama/llama-4-scout-17b-16e-instruct",
            displayName: "Llama 4 Scout 17B 👁",
            provider: .groq,
            speed: 5, quality: 3, cost: 1,
            visionCapable: true,
            notes: "Rápido, com visão (OpenAI-compatible vision)."
        )
        dict["llama-3.1-70b-versatile"] = ModelInfo(
            id: "llama-3.1-70b-versatile",
            displayName: "Llama 3.1 70B",
            provider: .groq,
            speed: 4, quality: 4, cost: 2,
            visionCapable: false,
            notes: "Bom equilíbrio entre velocidade e qualidade."
        )
        dict["llama-3.1-8b-instant"] = ModelInfo(
            id: "llama-3.1-8b-instant",
            displayName: "Llama 3.1 8B",
            provider: .groq,
            speed: 5, quality: 3, cost: 1,
            visionCapable: false,
            notes: "Muito rápido e barato."
        )
        dict["mixtral-8x7b-32768"] = ModelInfo(
            id: "mixtral-8x7b-32768",
            displayName: "Mixtral 8x7B",
            provider: .groq,
            speed: 4, quality: 4, cost: 2,
            visionCapable: false,
            notes: "Modelo Mixture-of-Experts eficiente."
        )

        // OpenAI
        dict["gpt-4o"] = ModelInfo(
            id: "gpt-4o",
            displayName: "GPT-4o",
            provider: .openai,
            speed: 3, quality: 5, cost: 4,
            visionCapable: true,
            notes: "Alta qualidade e visão avançada."
        )
        dict["gpt-4"] = ModelInfo(
            id: "gpt-4",
            displayName: "GPT-4",
            provider: .openai,
            speed: 2, quality: 5, cost: 5,
            visionCapable: false,
            notes: "Qualidade máxima, mais caro."
        )
        dict["gpt-3.5-turbo"] = ModelInfo(
            id: "gpt-3.5-turbo",
            displayName: "GPT-3.5 Turbo",
            provider: .openai,
            speed: 4, quality: 3, cost: 2,
            visionCapable: false,
            notes: "Relação custo-benefício."
        )

        // Anthropic (Claude)
        dict["claude-3-5-sonnet-20241022"] = ModelInfo(
            id: "claude-3-5-sonnet-20241022",
            displayName: "Claude 3.5 Sonnet",
            provider: .anthropic,
            speed: 3, quality: 5, cost: 4,
            visionCapable: false,
            notes: "Excelente para escrita e análise profunda."
        )
        dict["claude-3-haiku-20240307"] = ModelInfo(
            id: "claude-3-haiku-20240307",
            displayName: "Claude 3 Haiku",
            provider: .anthropic,
            speed: 5, quality: 3, cost: 1,
            visionCapable: false,
            notes: "Muito rápido e econômico."
        )
        dict["claude-3-opus-20240229"] = ModelInfo(
            id: "claude-3-opus-20240229",
            displayName: "Claude 3 Opus",
            provider: .anthropic,
            speed: 2, quality: 5, cost: 5,
            visionCapable: false,
            notes: "Alta qualidade, custo mais alto."
        )

        // Gemini
        dict["gemini-2.5-flash-lite"] = ModelInfo(
            id: "gemini-2.5-flash-lite",
            displayName: "Gemini 2.5 Flash Lite",
            provider: .gemini,
            speed: 5, quality: 3, cost: 1,
            visionCapable: true,
            notes: "Multi-modal, rápido e econômico."
        )

        return dict
    }()

    func getModelInfo(_ model: AIModel) -> ModelInfo? {
        // Try direct id match
        if let info = catalog[model.id] {
            return info
        }

        // Fallback: basic info synthesized from AIModel if unknown
        return ModelInfo(
            id: model.id,
            displayName: model.name,
            provider: model.provider,
            speed: 3,
            quality: 3,
            cost: 3,
            visionCapable: model.provider == .openai || model.provider == .groq || model.provider == .gemini,
            notes: nil
        )
    }
}
