import Foundation
import UIKit

/// Represents a single message in the AI chat conversation.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    let attachedImage: UIImage? // canvas snapshot shown in the bubble

    init(role: Role, content: String, attachedImage: UIImage? = nil) {
        self.role = role
        self.content = content
        self.attachedImage = attachedImage
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
}

/// ViewModel that manages the AI chat conversation state.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Set this after init so the AI panel can capture the canvas.
    weak var canvasManager: CanvasManager?

    private let aiConfig: AIConfiguration

    private let systemPrompt = """
    Você é um tutor de matemática excepcional e um assistente criativo integrado a um app de desenho (AI Canvas). \
    Sua especialidade é ajudar pessoas a entenderem e resolverem cálculos matemáticos passo a passo. \
    Quando receber uma imagem do canvas, analise-a com atenção: identifique as equações, contas ou problemas manuscritos. \
    Resolva os cálculos de maneira didática, amigável e encorajadora. Explique o raciocínio por trás de cada etapa. \
    
    IMPORTANTE SOBRE A FORMATAÇÃO: \
    - Formate sua resposta para ser visualmente agradável na interface. \
    - Use listas com marcadores (- ou *) e numeração (1., 2.) para organizar os passos da resolução. \
    - Use negrito (**texto**) para destacar os resultados finais e pontos importantes. \
    - Adicione emojis (📚, 🔢, ✨, ✅, 💡) para tornar a leitura mais fluida e interessante. \
    - NÃO USE notação LaTeX complexa matemática (como \\sqrt, \\frac, $$, \\[, \\]). \
    - Escreva as fórmulas de forma simples usando texto puro e símbolos comuns (ex: x^2, raiz de 9, 1/2). \
    - Evite usar blocos de código isolados (```) desnecessariamente, prefira organizar a resposta no fluxo do próprio texto. \
    
    Caso não haja cálculos na imagem, ajude o usuário com ideias gerais, sugestões criativas ou explicações sobre suas anotações, \
    sempre mantendo o mesmo nível de educação e a boa formatação com marcação simples e elegante.
    """

    init(aiConfig: AIConfiguration) {
        self.aiConfig = aiConfig
    }

    // MARK: - Send plain text message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let reply = try await AIService.shared.sendMessage(
                    messages: messages,
                    model: aiConfig.selectedModel,
                    systemPrompt: systemPrompt
                )
                messages.append(ChatMessage(role: .assistant, content: reply))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Send message with canvas snapshot

    /// Captures the current canvas and sends it alongside the user's text to a vision model.
    func sendMessageWithCanvas(customPrompt: String? = nil) {
        let text = (customPrompt ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let snapshot = canvasManager?.captureCanvasImage()
        let userMessage = ChatMessage(role: .user, content: text, attachedImage: snapshot)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let reply: String
                if let image = snapshot {
                    reply = try await AIService.shared.sendMessageWithImage(
                        messages: messages,
                        image: image,
                        model: aiConfig.selectedModel,
                        systemPrompt: systemPrompt
                    )
                } else {
                    // No drawing yet — fall back to text
                    reply = try await AIService.shared.sendMessage(
                        messages: messages,
                        model: aiConfig.selectedModel,
                        systemPrompt: systemPrompt
                    )
                }
                messages.append(ChatMessage(role: .assistant, content: reply))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Quick canvas analysis

    /// One-tap "Analisar canvas" action: takes a snapshot and sends a default analysis prompt.
    func analyzeCanvas() {
        sendMessageWithCanvas(customPrompt: "Analise meu canvas: descreva o que está desenhado ou escrito, identifique cálculos, fórmulas ou anotações, e dê sugestões úteis.")
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}
