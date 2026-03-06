import Foundation

struct TranslationSettings: Codable {
    /// BCP-47 language code of the target translation language (e.g. "fr", "en", "ja")
    var targetLanguageCode: String
    /// Whether the floating OCR bubble is shown in the browser
    var isOCREnabled: Bool

    init(targetLanguageCode: String = "fr", isOCREnabled: Bool = true) {
        self.targetLanguageCode = targetLanguageCode
        self.isOCREnabled = isOCREnabled
    }

    // MARK: - Available languages
    static let availableLanguages: [(code: String, name: String)] = [
        ("fr", "Français"),
        ("en", "English"),
        ("es", "Español"),
        ("de", "Deutsch"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("zh-Hans", "中文(简体)"),
        ("zh-Hant", "中文(繁體)"),
        ("pt", "Português"),
        ("it", "Italiano"),
        ("ar", "العربية"),
        ("ru", "Русский"),
    ]
}
