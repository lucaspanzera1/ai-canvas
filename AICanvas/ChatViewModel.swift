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
    
    IMPORTANTE SOBRE A FORMATAÇÃO (MATEMÁTICA E TEXTO): \
    - Formate sua resposta para ser visualmente agradável, bem espaçada e fácil de ler na interface. \
    - Use caracteres Unicode elegantes para operações matemáticas (ex: potências como x², y³, raízes como √16, frações como ½, ¾). \
    - Escreva equações matemáticas de forma clara, utilizando itálico (*x + y = z*) ou negrito para destacar expressões importantes. \
    - Organize resoluções longas alinhando etapas e usando espaçamento apropriado para simular uma resolução em caderno. \
    
    🔥 NOVO PODER: DESENHAR NO CANVAS DO USUÁRIO 🔥 \
    - Se a imagem contiver um cálculo matemático ou problema, você DEVE fornecer uma versão resumida da resolução ou a resposta final dentro de uma tag <canvas_text> ... </canvas_text>. \
    - O conteúdo dentro dessa tag será "desenhado" automaticamente usando uma fonte com estilo de caligrafia diretamente no quadro do usuário ao lado do problema! \
    - Seja conciso e use espaços e quebras de linha limpas dentro dessa tag. \
    Exemplo:
    <canvas_text>
    Resolvendo: 2x = 10
    ▶ x = 5
    </canvas_text>
    
    No restante da sua resposta (fora da tag), você pode dar a explicação passo a passo completa, usar listas, emojis, etc. \
    
    Caso não haja cálculos na imagem, ajude o usuário com ideias gerais, sugestões criativas ou explicações sobre suas anotações.
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
                
                // Extrair <canvas_text> usando expressões regulares
                if let range = reply.range(of: "(?<=<canvas_text>)[\\s\\S]*?(?=</canvas_text>)", options: .regularExpression) {
                    let textToDraw = String(reply[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !textToDraw.isEmpty {
                        await MainActor.run {
                            self.canvasManager?.addTextToCanvas(textToDraw)
                        }
                    }
                }
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
