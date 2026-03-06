import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var favorites: [FavoriteSite]
    @Published var translationSettings: TranslationSettings

    private let favoritesKey         = "meowToon.favorites"
    private let translationKey       = "meowToon.translationSettings"

    init() {
        if let data    = UserDefaults.standard.data(forKey: "meowToon.favorites"),
           let decoded = try? JSONDecoder().decode([FavoriteSite].self, from: data) {
            self.favorites = decoded
        } else {
            self.favorites = FavoriteSite.defaults
        }

        if let data    = UserDefaults.standard.data(forKey: "meowToon.translationSettings"),
           let decoded = try? JSONDecoder().decode(TranslationSettings.self, from: data) {
            self.translationSettings = decoded
        } else {
            self.translationSettings = TranslationSettings()
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
}
