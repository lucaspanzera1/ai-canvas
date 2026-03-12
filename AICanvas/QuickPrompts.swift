import Foundation

/// Quick prompts basados em presets
struct QuickPromptSet {
    let presetId: String
    let prompts: [QuickPrompt]
}

struct QuickPrompt: Identifiable {
    let id: String
    let text: String
    let emoji: String
    let withCanvas: Bool // Se deve enviar com canvas snapshot
}

/// Manager for quick prompts based on active preset
final class QuickPromptManager {
    static let shared = QuickPromptManager()
    
    private let promptSets: [String: [QuickPrompt]] = [
        "stem-tutor": [
            QuickPrompt(id: "solve", text: "🧮 Resolva este cálculo passo a passo", emoji: "📝", withCanvas: true),
            QuickPrompt(id: "explain", text: "📖 Explique este conceito de forma clara", emoji: "💡", withCanvas: true),
            QuickPrompt(id: "verify", text: "✅ Verifique se meu trabalho está correto", emoji: "🔍", withCanvas: true),
            QuickPrompt(id: "tips", text: "💡 Me dê dicas para entender melhor", emoji: "⭐", withCanvas: false)
        ],
        
        "creative-writer": [
            QuickPrompt(id: "inspire", text: "✨ Use isso como inspiração para uma história", emoji: "📖", withCanvas: true),
            QuickPrompt(id: "develop", text: "🎭 Desenvolva esses personagens", emoji: "👥", withCanvas: false),
            QuickPrompt(id: "continue", text: "➡️ Continue a história natural", emoji: "📚", withCanvas: false),
            QuickPrompt(id: "suggest", text: "🎬 Sugira melhorias para meu texto", emoji: "✍️", withCanvas: false)
        ],
        
        "design-assistant": [
            QuickPrompt(id: "feedback", text: "🎨 Dê feedback construtivo sobre este design", emoji: "👁️", withCanvas: true),
            QuickPrompt(id: "improve", text: "🎯 Como posso melhorar esta composição?", emoji: "⬆️", withCanvas: true),
            QuickPrompt(id: "colors", text: "🌈 Sugira uma paleta de cores", emoji: "🎨", withCanvas: true),
            QuickPrompt(id: "inspire-design", text: "💫 Me inspire com exemplos", emoji: "✨", withCanvas: false)
        ],
        
        "code-helper": [
            QuickPrompt(id: "debug", text: "🐛 Ajude-me a debugar isto", emoji: "🔧", withCanvas: true),
            QuickPrompt(id: "explain-code", text: "📝 Explique como este código funciona", emoji: "💻", withCanvas: true),
            QuickPrompt(id: "optimize", text: "⚡ Como posso otimizar isto?", emoji: "🚀", withCanvas: true),
            QuickPrompt(id: "refactor", text: "🔄 Sugira uma refatoração", emoji: "📐", withCanvas: false)
        ],
        
        "language-tutor": [
            QuickPrompt(id: "correct", text: "✏️ Corrija minha escrita", emoji: "📍", withCanvas: false),
            QuickPrompt(id: "translate", text: "🌐 Traduza isto para mim", emoji: "🗣️", withCanvas: false),
            QuickPrompt(id: "grammar", text: "📚 Ensine-me a gramática aqui", emoji: "📖", withCanvas: true),
            QuickPrompt(id: "converse", text: "💬 Vamos conversar em [idioma]", emoji: "🎤", withCanvas: false)
        ],
        
        "general-assistant": [
            QuickPrompt(id: "analyze", text: "🔍 Analise isto para mim", emoji: "📊", withCanvas: true),
            QuickPrompt(id: "brainstorm", text: "💭 Vamos fazer brainstorm", emoji: "🧠", withCanvas: false),
            QuickPrompt(id: "explain", text: "📚 Explique este conceito", emoji: "🎓", withCanvas: false),
            QuickPrompt(id: "help", text: "🆘 Preciso de ajuda com isto", emoji: "👋", withCanvas: true)
        ]
    ]
    
    func getPromptsForPreset(_ preset: AIPreset) -> [QuickPrompt] {
        promptSets[preset.id] ?? promptSets["general-assistant"] ?? []
    }
    
    func getPromptsForPresetId(_ presetId: String) -> [QuickPrompt] {
        promptSets[presetId] ?? promptSets["general-assistant"] ?? []
    }
}
