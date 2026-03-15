import Foundation

// MARK: - Settings model

struct TranslationSettings: Codable {
    var targetLanguageCode: String
    var isOCREnabled:       Bool

    init(
        targetLanguageCode: String = "fr",
        isOCREnabled:       Bool   = true
    ) {
        self.targetLanguageCode = targetLanguageCode
        self.isOCREnabled       = isOCREnabled
    }

    // Unused properties kept for backward compatibility decoding if needed
    // (though better to handle via Decodable if actually needed)
    var enableFallback: Bool = false
    var engine: String = "apple"

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
