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
    Você é um assistente criativo integrado a um app de desenho e escrita (AI Canvas). \
    Quando receber uma imagem do canvas, analise-a com atenção: identifique anotações, \
    texto manuscrito, formas, cálculos matemáticos ou qualquer conteúdo visual relevante. \
    Ajude o usuário com ideias, cálculos, explicações sobre o que está desenhado, \
    sugestões de melhoria e qualquer dúvida. Responda de forma concisa e útil. \
    Pode usar emojis quando apropriado.
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
