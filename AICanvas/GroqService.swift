import Foundation

/// Service to communicate with the Groq API (OpenAI-compatible responses endpoint).
final class GroqService {

    static let shared = GroqService()
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "qwen/qwen3-32b"

    private init() {}

    // MARK: - Chat

    /// Sends a message to the Groq API and returns the assistant's reply.
    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String? = nil
    ) async throws -> String {
        guard let apiKey = KeychainManager.shared.apiKey else {
            throw GroqError.noAPIKey
        }

        var apiMessages: [[String: String]] = []

        // System prompt
        if let systemPrompt {
            apiMessages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        // Conversation history
        for msg in messages {
            apiMessages.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 2048
        ]

        guard let url = URL(string: baseURL) else {
            throw GroqError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GroqError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.parsingError
        }

        return Self.stripThinkTags(from: content)
    }

    // MARK: - Validate Key

    /// Quick check if the API key is valid by making a minimal request.
    func validateKey(_ key: String) async -> Bool {
        guard let url = URL(string: baseURL) else { return false }

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    /// Strips `<think>...</think>` reasoning tags from model output.
    /// Some reasoning models (e.g. Qwen3, DeepSeek-R1) wrap internal
    /// chain-of-thought in these tags — they shouldn't be shown to the user.
    static func stripThinkTags(from text: String) -> String {
        // Remove <think>...</think> blocks (including multiline content)
        let pattern = "<think>[\\s\\S]*?</think>"
        let cleaned = text.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Types

enum GroqError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case parsingError
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API Key não configurada."
        case .invalidURL:
            return "URL inválida."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        case .parsingError:
            return "Erro ao processar resposta."
        case .apiError(let code, let message):
            return "Erro \(code): \(message)"
        }
    }
}
