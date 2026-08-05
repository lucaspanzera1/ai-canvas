import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case ptBR = "pt-BR"
    case en = "en"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .ptBR: return "Português (Brasil)"
        case .en: return "English"
        }
    }
}

/// Drives the app's in-app language selection, independent of the device's system language.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private static let storageKey = "app_language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale { language.locale }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        language = AppLanguage(rawValue: saved ?? "") ?? .ptBR
    }

    /// Bundle containing the compiled strings for the currently selected language,
    /// resolved explicitly so it does not depend on the device's system language.
    fileprivate var stringsBundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

extension String {
    /// Looks up this string (used as the Localizable table key, matching the
    /// pt-BR source text) in the currently selected app language, regardless
    /// of the device's system language.
    var localized: String {
        LocalizationManager.shared.stringsBundle.localizedString(forKey: self, value: self, table: "Localizable")
    }
}
