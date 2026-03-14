import Foundation

// MARK: - Engines

enum TranslationEngine: String, Codable, CaseIterable {
    case google   = "google"    // Unofficial Google Translate – default, no auth
    case myMemory = "mymemory"  // MyMemory free API – 5 k chars/day
    case apple    = "apple"     // Apple Translation – offline, iOS 17.4+

    var displayName: String {
        switch self {
        case .google:   return "Google Translate"
        case .myMemory: return "MyMemory"
        case .apple:    return "Apple Translation"
        }
    }

    var subtitle: String {
        switch self {
        case .google:   return "Gratuit · Automatique · Recommandé"
        case .myMemory: return "Gratuit · 5 000 car./jour"
        case .apple:    return "Hors-ligne · Privé · iOS 17.4+"
        }
    }
}

// MARK: - Settings model

struct TranslationSettings: Codable {
    var targetLanguageCode: String
    var isOCREnabled:       Bool
    var engine:             TranslationEngine
    /// If primary engine fails, cascade through the others
    var enableFallback:     Bool

    init(
        targetLanguageCode: String          = "fr",
        isOCREnabled:       Bool            = true,
        engine:             TranslationEngine = .google,
        enableFallback:     Bool            = true
    ) {
        self.targetLanguageCode = targetLanguageCode
        self.isOCREnabled       = isOCREnabled
        self.engine             = engine
        self.enableFallback     = enableFallback
    }

    // Kept for backward-compat decode
    var useAppleFallback: Bool {
        get { enableFallback }
        set { enableFallback = newValue }
    }

    static let availableLanguages: [(code: String, name: String)] = [
        ("fr",      "Français"),
        ("en",      "English"),
        ("es",      "Español"),
        ("de",      "Deutsch"),
        ("ja",      "日本語"),
        ("ko",      "한국어"),
        ("zh-Hans", "中文(简体)"),
        ("zh-Hant", "中文(繁體)"),
        ("pt",      "Português"),
        ("it",      "Italiano"),
        ("ar",      "العربية"),
        ("ru",      "Русский"),
    ]
}
