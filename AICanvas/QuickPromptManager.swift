import Foundation

struct QuickPrompt: Identifiable, Equatable {
    let id: String
    let text: String
    let withCanvas: Bool
    
    init(id: String = UUID().uuidString, text: String, withCanvas: Bool = false) {
        self.id = id
        self.text = text
        self.withCanvas = withCanvas
    }
}

final class QuickPromptManager {
    static let shared = QuickPromptManager()
    private init() {}
    
    func getPromptsForPreset(_ preset: AIPreset) -> [QuickPrompt] {
        switch preset.id {
        case "stem-tutor":
            return [
                QuickPrompt(text: "Explique passo a passo este problema", withCanvas: false),
                QuickPrompt(text: "Analise meu canvas e resolva a equação", withCanvas: true),
                QuickPrompt(text: "Mostre a fórmula e um exemplo prático", withCanvas: false),
                QuickPrompt(text: "Verifique meus cálculos no desenho", withCanvas: true)
            ]
        case "creative-writer":
            return [
                QuickPrompt(text: "Gere 3 ideias de histórias com base no meu desenho", withCanvas: true),
                QuickPrompt(text: "Escreva um parágrafo inspirador a partir desta cena", withCanvas: true),
                QuickPrompt(text: "Crie um personagem interessante para esta história", withCanvas: false),
                QuickPrompt(text: "Sugira um final surpreendente", withCanvas: false)
            ]
        case "design-assistant":
            return [
                QuickPrompt(text: "Dê feedback de design para este layout", withCanvas: true),
                QuickPrompt(text: "Sugira uma paleta de cores complementar", withCanvas: false),
                QuickPrompt(text: "Avalie tipografia e hierarquia visual", withCanvas: true),
                QuickPrompt(text: "Liste 3 melhorias rápidas de UX", withCanvas: false)
            ]
        case "code-helper":
            return [
                QuickPrompt(text: "Explique o que este código faz", withCanvas: true),
                QuickPrompt(text: "Aponte possíveis bugs e melhorias", withCanvas: true),
                QuickPrompt(text: "Refatore para ficar mais legível", withCanvas: false),
                QuickPrompt(text: "Escreva testes unitários básicos", withCanvas: false)
            ]
        case "language-tutor":
            return [
                QuickPrompt(text: "Converse comigo neste idioma (nível iniciante)", withCanvas: false),
                QuickPrompt(text: "Corrija meus erros de gramática neste texto", withCanvas: true),
                QuickPrompt(text: "Ensine 5 expressões comuns com exemplos", withCanvas: false),
                QuickPrompt(text: "Explique as diferenças entre estes tempos verbais", withCanvas: false)
            ]
        case "general-assistant":
            fallthrough
        default:
            return [
                QuickPrompt(text: "Analisar meu canvas agora", withCanvas: true),
                QuickPrompt(text: "Resuma minhas anotações", withCanvas: true),
                QuickPrompt(text: "Sugira próximos passos", withCanvas: false),
                QuickPrompt(text: "Organize ideias em tópicos", withCanvas: false)
            ]
        }
    }
}
