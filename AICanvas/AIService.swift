import Foundation
import UIKit

/// Universal AI service that supports multiple providers (Groq, OpenAI, Claude, Gemini).
final class AIService {
    
    static let shared = AIService()
    private init() {}
    
    // MARK: - Chat
    
    /// Sends a message using the specified model and returns the assistant's reply.
    func sendMessage(
        messages: [ChatMessage],
        model: AIModel,
        systemPrompt: String? = nil
    ) async throws -> String {
        
        guard let apiKey = KeychainManager.shared.apiKey(for: model.provider) else {
            throw AIError.noAPIKey(provider: model.provider)
        }
        
        switch model.provider {
        case .groq, .openai:
            return try await sendOpenAICompatibleMessage(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        case .anthropic:
            return try await sendClaudeMessage(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        case .gemini:
            return try await sendGeminiMessage(
                messages: messages,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        }
    }

    // MARK: - Vision (Image + Text)

    /// Sends a message along with a canvas image to a vision-capable model.
    func sendMessageWithImage(
        messages: [ChatMessage],
        image: UIImage,
        model: AIModel,
        systemPrompt: String? = nil
    ) async throws -> String {

        guard let apiKey = KeychainManager.shared.apiKey(for: model.provider) else {
            throw AIError.noAPIKey(provider: model.provider)
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AIError.parsingError
        }
        let base64Image = imageData.base64EncodedString()

        switch model.provider {
        case .groq:
            // Groq also uses OpenAI-compatible vision format (Llama 4 Scout supports images)
            return try await sendOpenAIVisionMessage(
                messages: messages,
                base64Image: base64Image,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        case .openai:
            return try await sendOpenAIVisionMessage(
                messages: messages,
                base64Image: base64Image,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        case .anthropic:
            return try await sendClaudeVisionMessage(
                messages: messages,
                base64Image: base64Image,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        case .gemini:
            return try await sendGeminiVisionMessage(
                messages: messages,
                base64Image: base64Image,
                imageData: imageData,
                model: model,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        }
    }

    // MARK: - OpenAI Vision

    private func sendOpenAIVisionMessage(
        messages: [ChatMessage],
        base64Image: String,
        model: AIModel,
        systemPrompt: String?,
        apiKey: String
    ) async throws -> String {

        guard let url = URL(string: model.provider.baseURL) else {
            throw AIError.invalidURL
        }

        var apiMessages: [[String: Any]] = []

        if let systemPrompt {
            apiMessages.append(["role": "system", "content": systemPrompt])
        }

        // Add previous messages as plain text
        for msg in messages.dropLast() {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Last user message gets image attached
        let lastText = messages.last?.content ?? ""
        let userContent: [[String: Any]] = [
            ["type": "text", "text": lastText],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)", "detail": "high"]]
        ]
        apiMessages.append(["role": "user", "content": userContent])

        let body: [String: Any] = [
            "model": model.id,
            "messages": apiMessages,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIError.parsingError
        }

        return cleanAIResponse(text)
    }

    // MARK: - Claude Vision

    private func sendClaudeVisionMessage(
        messages: [ChatMessage],
        base64Image: String,
        model: AIModel,
        systemPrompt: String?,
        apiKey: String
    ) async throws -> String {

        guard let url = URL(string: model.provider.baseURL) else {
            throw AIError.invalidURL
        }

        var apiMessages: [[String: Any]] = []

        // History (text only)
        for msg in messages.dropLast() where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Last message includes the image
        let lastText = messages.last?.content ?? ""
        let userContent: [[String: Any]] = [
            ["type": "image", "source": [
                "type": "base64",
                "media_type": "image/jpeg",
                "data": base64Image
            ]],
            ["type": "text", "text": lastText]
        ]
        apiMessages.append(["role": "user", "content": userContent])

        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": 2048,
            "messages": apiMessages
        ]
        if let systemPrompt {
            body["system"] = systemPrompt
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.parsingError
        }

        return cleanAIResponse(text)
    }

    // MARK: - Gemini Vision

    private func sendGeminiVisionMessage(
        messages: [ChatMessage],
        base64Image: String,
        imageData: Data,
        model: AIModel,
        systemPrompt: String?,
        apiKey: String
    ) async throws -> String {

        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(model.id):generateContent"
        guard let url = URL(string: baseURL) else {
            throw AIError.invalidURL
        }

        let lastText = messages.last?.content ?? ""

        // Build a single "user" turn with image + text
        let parts: [[String: Any]] = [
            ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]],
            ["text": lastText]
        ]

        var body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["temperature": 0.7, "maxOutputTokens": 2048]
        ]

        if let systemPrompt {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIError.parsingError
        }

        return cleanAIResponse(text)
    }

    /// Quick validation check for an API key.
    func validateKey(_ key: String, for provider: AIProvider) async -> Bool {
        // Quick format check first
        let hasCorrectFormat = validateKeyFormat(key, for: provider)
        if !hasCorrectFormat {
            return false
        }
        
        switch provider {
        case .groq:
            return await validateGroqKey(key)
        case .openai:
            return await validateOpenAIKey(key)
        case .anthropic:
            return await validateClaudeKey(key)
        case .gemini:
            return await validateGeminiKey(key)
        }
    }
    
    /// Debug version of validation with detailed logging - call this if you need to debug key issues
    func validateKeyWithDebug(_ key: String, for provider: AIProvider) async -> Bool {
        print("🔑 [DEBUG] Validating key for \(provider.displayName)...")
        print("🔑 [DEBUG] Key format: \(key.prefix(10))... (length: \(key.count))")
        
        // Quick format check first
        let hasCorrectFormat = validateKeyFormat(key, for: provider)
        if !hasCorrectFormat {
            print("❌ [DEBUG] Key format is incorrect for \(provider.displayName)")
            return false
        }
        print("✅ [DEBUG] Key format is correct")
        
        let result: Bool
        switch provider {
        case .groq:
            result = await validateGroqKeyWithDebug(key)
        case .openai:
            result = await validateOpenAIKeyWithDebug(key)
        case .anthropic:
            result = await validateClaudeKeyWithDebug(key)
        case .gemini:
            result = await validateGeminiKeyWithDebug(key)
        }
        
        print("🔑 [DEBUG] Final validation result for \(provider.displayName): \(result ? "✅ Valid" : "❌ Invalid")")
        return result
    }
    
    /// Basic format validation for API keys
    private func validateKeyFormat(_ key: String, for provider: AIProvider) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch provider {
        case .groq:
            return trimmed.hasPrefix("gsk_") && trimmed.count > 10
        case .openai:
            return trimmed.hasPrefix("sk-") && trimmed.count > 10
        case .anthropic:
            return trimmed.hasPrefix("sk-ant-") && trimmed.count > 15
        case .gemini:
            return trimmed.hasPrefix("AIza") && trimmed.count > 10
        }
    }
    
    // MARK: - OpenAI Compatible (Groq, OpenAI)
    
    private func sendOpenAICompatibleMessage(
        messages: [ChatMessage],
        model: AIModel,
        systemPrompt: String?,
        apiKey: String
    ) async throws -> String {
        
        guard let url = URL(string: model.provider.baseURL) else {
            throw AIError.invalidURL
        }
        
        var apiMessages: [[String: String]] = []
        
        if let systemPrompt {
            apiMessages.append(["role": "system", "content": systemPrompt])
        }
        
        for msg in messages {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        
        let body: [String: Any] = [
            "model": model.id,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let rawContent = message["content"] as? String else {
            throw AIError.parsingError
        }
        
        return cleanAIResponse(rawContent)
    }
    
    // MARK: - Validation Methods
    
    private func validateGroqKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            return false
        }
        
        // Use a very simple model that should always be available
        let body: [String: Any] = [
            "model": "llama-3.1-8b-instant",
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
            "temperature": 0
        ]
        
        return await performValidation(url: url, body: body, headers: [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ], provider: "Groq")
    }
    
    private func validateOpenAIKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return false
        }
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
            "temperature": 0
        ]
        
        return await performValidation(url: url, body: body, headers: [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ], provider: "OpenAI")
    }
    
    private func validateClaudeKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return false
        }
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        
        return await performValidation(url: url, body: body, headers: [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01"
        ], provider: "Claude")
    }
    
    private func validateGeminiKey(_ key: String) async -> Bool {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"
        guard let url = URL(string: urlString) else {
            return false
        }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": "hi"]]]
            ],
            "generationConfig": ["maxOutputTokens": 1]
        ]
        
        return await performValidation(url: url, body: body, headers: [
            "Content-Type": "application/json",
            "x-goog-api-key": key
        ], provider: "Gemini")
    }
    
    // MARK: - Debug Validation Methods
    
    private func validateGroqKeyWithDebug(_ key: String) async -> Bool {
        print("🔑 [DEBUG] Testing Groq API...")
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            print("❌ [DEBUG] Invalid Groq URL")
            return false
        }
        
        let body: [String: Any] = [
            "model": "llama-3.1-8b-instant",
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
            "temperature": 0
        ]
        
        return await performValidationWithDebug(url: url, body: body, headers: [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ], provider: "Groq")
    }
    
    private func validateOpenAIKeyWithDebug(_ key: String) async -> Bool {
        print("🔑 [DEBUG] Testing OpenAI API...")
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ [DEBUG] Invalid OpenAI URL")
            return false
        }
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
            "temperature": 0
        ]
        
        return await performValidationWithDebug(url: url, body: body, headers: [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ], provider: "OpenAI")
    }
    
    private func validateClaudeKeyWithDebug(_ key: String) async -> Bool {
        print("🔑 [DEBUG] Testing Claude API...")
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            print("❌ [DEBUG] Invalid Claude URL")
            return false
        }
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        
        return await performValidationWithDebug(url: url, body: body, headers: [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01"
        ], provider: "Claude")
    }
    
    private func validateGeminiKeyWithDebug(_ key: String) async -> Bool {
        print("🔑 [DEBUG] Testing Gemini API...")
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"
        guard let url = URL(string: urlString) else {
            print("❌ [DEBUG] Invalid Gemini URL")
            return false
        }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": "hi"]]]
            ],
            "generationConfig": ["maxOutputTokens": 1]
        ]
        
        return await performValidationWithDebug(url: url, body: body, headers: [
            "Content-Type": "application/json",
            "x-goog-api-key": key
        ], provider: "Gemini")
    }
    
    private func performValidationWithDebug(url: URL, body: [String: Any], headers: [String: String], provider: String) async -> Bool {
        do {
            print("🔗 [DEBUG] Making request to: \(url)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            
            for (key, value) in headers {
                let maskedValue = key == "Authorization" ? "\(value.prefix(20))..." : value
                print("📋 [DEBUG] Header \(key): \(maskedValue)")
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                print("📡 [DEBUG] \(provider) response: \(statusCode)")
                
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("📄 [DEBUG] \(provider) response body: \(responseBody.prefix(200))...")
                }
                
                let isValid = statusCode == 200 || statusCode == 400
                if !isValid {
                    print("❌ [DEBUG] \(provider) validation failed with status \(statusCode)")
                    if statusCode == 401 || statusCode == 403 {
                        print("❌ [DEBUG] This indicates an invalid API key")
                    }
                } else {
                    print("✅ [DEBUG] \(provider) key appears to be valid")
                }
                return isValid
            }
            print("❌ [DEBUG] No HTTP response received")
            return false
        } catch {
            print("❌ [DEBUG] \(provider) validation error: \(error.localizedDescription)")
            return false
        }
    }
    
    private func performValidation(url: URL, body: [String: Any], headers: [String: String], provider: String) async -> Bool {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                // Accept 200 (OK) and 400 (Bad Request) - 400 usually means the request structure is wrong but the key is valid
                // Reject 401 (Unauthorized), 403 (Forbidden) which indicate invalid API key
                return statusCode == 200 || statusCode == 400
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Claude (Anthropic)
    
    private func sendClaudeMessage(
        messages: [ChatMessage],
        model: AIModel,
        systemPrompt: String?,
        apiKey: String
    ) async throws -> String {
        
        guard let url = URL(string: model.provider.baseURL) else {
            throw AIError.invalidURL
        }
        
        var apiMessages: [[String: String]] = []
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        
        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": 2048,
            "messages": apiMessages
        ]
        
        if let systemPrompt {
            body["system"] = systemPrompt
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIError.parsingError
        }
        
        return cleanAIResponse(text)
    }
    
    private func validateClaudeKey(_ key: String, model: AIModel) async -> Bool {
        guard let url = URL(string: model.provider.baseURL) else { return false }
        
        let body: [String: Any] = [
            "model": model.id,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Gemini
    
    private func sendGeminiMessage(
        messages: [ChatMessage],
        model: AIModel,
        systemPrompt: String?,
        apiKey: String
    ) async throws -> String {
        
        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(model.id):generateContent"
        guard let url = URL(string: baseURL) else {
            throw AIError.invalidURL
        }
        
        var parts: [[String: String]] = []
        
        // Add system prompt as first message if provided
        if let systemPrompt {
            parts.append(["text": systemPrompt])
        }
        
        // Add conversation history (Gemini expects a different format)
        var conversationText = ""
        for msg in messages {
            let role = msg.role == .assistant ? "Model" : "User"
            conversationText += "\(role): \(msg.content)\n"
        }
        
        if !conversationText.isEmpty {
            parts.append(["text": conversationText])
        }
        
        let body: [String: Any] = [
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 2048
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.parsingError
        }
        
        return cleanAIResponse(text)
    }

    
    // MARK: - Content Cleaning
    
    /// Removes AI thinking tags and other artifacts from the response.
    private func cleanAIResponse(_ content: String) -> String {
        var cleaned = content
        
        // Use [\\s\\S]*? to match across newlines instead of relying on a non-existent option
        let patterns = [
            "<think>[\\s\\S]*?</think>",
            "<thinking>[\\s\\S]*?</thinking>",
            "<thought>[\\s\\S]*?</thought>",
            "<reason>[\\s\\S]*?</reason>",
            "<analysis>[\\s\\S]*?</analysis>"
        ]
        
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - Error Types

enum AIError: LocalizedError {
    case noAPIKey(provider: AIProvider)
    case invalidURL
    case invalidResponse
    case parsingError
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "API Key do \(provider.displayName) não configurada."
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
