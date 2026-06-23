import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var favorites: [FavoriteSite]
    @Published var translationSettings: TranslationSettings
    @Published var isAdBlockEnabled: Bool

    // Floating buttons appearance
    @Published var floatingButtonOpacity: Double
    @Published var showFavoriteButton:    Bool
    @Published var showTranslateButton:   Bool

    private let favoritesKey          = "meowToon.favorites"
    private let translationKey        = "meowToon.translationSettings"
    private let adBlockKey            = "meowToon.adBlockEnabled"
    private let floatOpacityKey       = "meowToon.floatOpacity"
    private let showFavBtnKey         = "meowToon.showFavBtn"
    private let showTranslateBtnKey   = "meowToon.showTranslateBtn"
    private let defaultsSeededKey     = "meowToon.defaultFavoritesSeeded"

    static let defaultFavorites: [FavoriteSite] = []

    init() {
        // Favorites — seed defaults on first launch, otherwise restore saved data
        if let data    = UserDefaults.standard.data(forKey: "meowToon.favorites"),
           let decoded = try? JSONDecoder().decode([FavoriteSite].self, from: data) {
            self.favorites = decoded
        } else {
            self.favorites = SettingsViewModel.defaultFavorites
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

        // Floating buttons
        let ud = UserDefaults.standard
        self.floatingButtonOpacity = ud.object(forKey: "meowToon.floatOpacity") != nil
            ? ud.double(forKey: "meowToon.floatOpacity") : 1.0
        self.showFavoriteButton = ud.object(forKey: "meowToon.showFavBtn") != nil
            ? ud.bool(forKey: "meowToon.showFavBtn") : true
        self.showTranslateButton = ud.object(forKey: "meowToon.showTranslateBtn") != nil
            ? ud.bool(forKey: "meowToon.showTranslateBtn") : true

        // Ensure the bundled default favorites are present at least once,
        // even for users who already had saved data before this version.
        if !ud.bool(forKey: defaultsSeededKey) {
            for fav in SettingsViewModel.defaultFavorites
            where !favorites.contains(where: { $0.urlString == fav.urlString }) {
                favorites.append(fav)
            }
            ud.set(true, forKey: defaultsSeededKey)
        }

        // Persist any freshly-seeded default favorites.
        saveFavorites()
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

    func saveFloatingButtons() {
        let ud = UserDefaults.standard
        ud.set(floatingButtonOpacity, forKey: floatOpacityKey)
        ud.set(showFavoriteButton,    forKey: showFavBtnKey)
        ud.set(showTranslateButton,   forKey: showTranslateBtnKey)
    }

    func saveAll() {
        saveFavorites()
        saveTranslationSettings()
        saveAdBlock()
        saveFloatingButtons()
    }
}
