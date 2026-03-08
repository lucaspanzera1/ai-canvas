import Foundation

/// Represents a single message in the AI chat conversation.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

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

    private let systemPrompt = """
    Você é um assistente criativo integrado a um app de desenho e escrita (AI Canvas). \
    Ajude o usuário com ideias, sugestões artísticas, brainstorming, feedback sobre conceitos, \
    e qualquer dúvida. Responda de forma concisa e útil. Pode usar emojis quando apropriado.
    """

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
                let reply = try await GroqService.shared.sendMessage(
                    messages: messages,
                    systemPrompt: systemPrompt
                )
                let assistantMessage = ChatMessage(role: .assistant, content: reply)
                messages.append(assistantMessage)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}
