import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var favorites: [FavoriteSite]
    @Published var translationSettings: TranslationSettings
    @Published var isAdBlockEnabled: Bool

    private let favoritesKey       = "meowToon.favorites"
    private let translationKey     = "meowToon.translationSettings"
    private let adBlockKey         = "meowToon.adBlockEnabled"

    init() {
        // Favorites — start empty if no saved data
        if let data    = UserDefaults.standard.data(forKey: "meowToon.favorites"),
           let decoded = try? JSONDecoder().decode([FavoriteSite].self, from: data) {
            self.favorites = decoded
        } else {
            self.favorites = []
        }

        // Translation settings
        if let data    = UserDefaults.standard.data(forKey: "meowToon.translationSettings"),
           let decoded = try? JSONDecoder().decode(TranslationSettings.self, from: data) {
            self.translationSettings = decoded
        } else {
            self.translationSettings = TranslationSettings()
        }

        // Ad blocker — enabled by default
        if UserDefaults.standard.object(forKey: "meowToon.adBlockEnabled") != nil {
            self.isAdBlockEnabled = UserDefaults.standard.bool(forKey: "meowToon.adBlockEnabled")
        } else {
            self.isAdBlockEnabled = true
        }
    }

    // MARK: - Favorites CRUD

    func addFavorite(_ site: FavoriteSite) {
        favorites.append(site)
        saveFavorites()
    }

    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        saveFavorites()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    // MARK: - Persistence

    func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: favoritesKey)
    }

    func saveTranslationSettings() {
        guard let data = try? JSONEncoder().encode(translationSettings) else { return }
        UserDefaults.standard.set(data, forKey: translationKey)
    }

    func saveAdBlock() {
        UserDefaults.standard.set(isAdBlockEnabled, forKey: adBlockKey)
    }

    func saveAll() {
        saveFavorites()
        saveTranslationSettings()
        saveAdBlock()
    }
}
