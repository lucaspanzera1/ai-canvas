import Foundation
import Security

/// Manages AI API keys using Keychain for secure storage.
/// Supports multiple providers (Groq, OpenAI, Claude, Gemini).
final class KeychainManager {

    static let shared = KeychainManager()
    private let service = "com.panzera.AICanvas"

    private init() {}

    // MARK: - Public API

    /// Check if any AI provider has a stored API key.
    var hasAnyAPIKey: Bool {
        return AIProvider.allCases.contains { hasAPIKey(for: $0) }
    }

    /// Check if a specific provider has a stored API key.
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return retrieveKey(for: provider) != nil
    }

    /// Get the API key for a specific provider.
    func apiKey(for provider: AIProvider) -> String? {
        return retrieveKey(for: provider)
    }

    /// Save an API key for a specific provider.
    @discardableResult
    func saveKey(_ key: String, for provider: AIProvider) -> Bool {
        // Delete existing key first
        deleteKey(for: provider)

        let data = Data(key.utf8)
        let account = accountName(for: provider)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete the API key for a specific provider.
    @discardableResult
    func deleteKey(for provider: AIProvider) -> Bool {
        let account = accountName(for: provider)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Delete all API keys.
    func deleteAllKeys() {
        for provider in AIProvider.allCases {
            deleteKey(for: provider)
        }
    }

    /// Get all configured providers.
    var configuredProviders: [AIProvider] {
        return AIProvider.allCases.filter { hasAPIKey(for: $0) }
    }

    // MARK: - Legacy Support

    /// Legacy method for backward compatibility - uses Groq as default.
    var hasAPIKey: Bool {
        return hasAPIKey(for: .groq)
    }

    /// Legacy method for backward compatibility - uses Groq as default.
    var apiKey: String? {
        return apiKey(for: .groq)
    }

    /// Legacy method for backward compatibility - uses Groq as default.
    @discardableResult
    func saveKey(_ key: String) -> Bool {
        return saveKey(key, for: .groq)
    }

    /// Legacy method for backward compatibility - uses Groq as default.
    @discardableResult
    func deleteKey() -> Bool {
        return deleteKey(for: .groq)
    }

    // MARK: - Private

    private func accountName(for provider: AIProvider) -> String {
        return "\(provider.rawValue)-api-key"
    }

    private func retrieveKey(for provider: AIProvider) -> String? {
        let account = accountName(for: provider)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
