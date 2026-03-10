import Foundation
import UIKit

/// Represents a single message in the AI chat conversation.
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    // Image is purposely ignored during Codable serialization to keep chat history light.
    var attachedImage: UIImage? = nil

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), attachedImage: UIImage? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
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

    // Custom Codable implementation to ignore UIImage
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        attachedImage = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
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
    Sua especialidade é ajudar pessoas a entenderem e resolverem cálculos matemáticos, além de dar ótimas dicas e ideias. \
    Quando receber uma imagem do canvas, analise-a com atenção: identifique as equações, contas ou problemas manuscritos. \
    
    IMPORTANTE SOBRE A FORMATAÇÃO (MATEMÁTICA E TEXTO): \
    - Formate sua resposta para ser visualmente agradável, bem espaçada e fácil de ler na interface do chat. \
    - Use caracteres Unicode elegantes para operações matemáticas (ex: potências como x², y³, raízes como √16, frações como ½, ¾). \
    - Escreva equações matemáticas de forma clara, utilizando itálico (*x + y = z*) ou negrito para destacar expressões importantes. \
    
    🔥 NOVO PODER: INTERAÇÃO DIRETO NO CANVAS 🔥 \
    Você tem a habilidade de enviar conteúdo mágico direto para o quadro do usuário! Siga estas regras OBRIGATORIAMENTE: \
    
    1. RESOLUÇÕES E RESPOSTAS (Texto Simples): \
    - Se o usuário pedir a **resolução**, a **conta**, ou a **resposta** matemática, forneça o passo a passo resumido ou a resposta final dentro de uma tag <canvas_text> ... </canvas_text>. \
    - Isso será "escrito à mão" no quadro dele. \
    
    Exemplo:
    Aqui está a conta resolvida no quadro:
    <canvas_text>
    2x + 4 = 10
    2x = 6
    ▶ x = 3
    </canvas_text>
    
    Sempre dê explicações extras e converse de forma amigável no corpo normal da mensagem.
    """

    init(aiConfig: AIConfiguration, initialMessages: [ChatMessage] = []) {
        self.aiConfig = aiConfig
        self.messages = initialMessages
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
                var finalReply = reply
                
                // Extrair <canvas_text> usando expressões regulares
                if let range = reply.range(of: "(?<=<canvas_text>)[\\s\\S]*?(?=</canvas_text>)", options: .regularExpression) {
                    let textToDraw = String(reply[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !textToDraw.isEmpty {
                        await MainActor.run {
                            self.canvasManager?.addTextToCanvas(textToDraw)
                        }
                    }
                    
                    // Em vez de remover o texto, substituímos as tags por uma formatação bacana no chat
                    finalReply = finalReply.replacingOccurrences(of: "<canvas_text>", with: "📝 **Enviado para o Canvas:**\n> ")
                    finalReply = finalReply.replacingOccurrences(of: "</canvas_text>", with: "")
                }
                
                if !finalReply.isEmpty {
                    messages.append(ChatMessage(role: .assistant, content: finalReply))
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
