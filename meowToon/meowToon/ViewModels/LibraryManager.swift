import Foundation
import Combine

class LibraryManager: ObservableObject {
    @Published var categories:            [LibraryCategory]  = []
    @Published var uncategorizedWebtoons: [LibraryWebtoon]   = []
    @Published var savedSeries:           Set<String>        = []

    private let key            = "meowToon.libraryV2"
    private let uncatKey       = "meowToon.uncategorized"
    private let savedSeriesKey = "meowToon.savedSeries"

    init() {
        load()
        loadSavedSeries()
        if categories.isEmpty { seedDefaultCategories() }
    }

    private func seedDefaultCategories() {
        let defaults: [(String, String)] = [
            ("Action",    "⚔️"),
            ("Romance",   "💕"),
            ("Fantaisie", "🧙"),
            ("Comédie",   "😄"),
            ("Sci-Fi",    "🚀"),
        ]
        categories = defaults.map { LibraryCategory(name: $0.0, emoji: $0.1) }
        save()
    }

    // MARK: - Categories

    func addCategory(name: String, emoji: String = "📂") {
        categories.append(LibraryCategory(name: name, emoji: emoji))
        save()
    }

    func removeCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        save()
    }

    func renameCategory(id: UUID, name: String) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].name = name
        save()
    }

    // MARK: - Webtoons

    func addWebtoon(name: String, siteURL: String = "", icon: String = "books.vertical", to categoryID: UUID) {
        guard let i = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        let w = LibraryWebtoon(name: name, siteURL: siteURL, iconName: icon)
        categories[i].addWebtoon(w)
        save()
    }

    func removeWebtoon(id: UUID, from categoryID: UUID) {
        guard let i = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[i].removeWebtoon(id: id)
        save()
    }

    func removeUncategorizedWebtoon(id: UUID) {
        uncategorizedWebtoons.removeAll { $0.id == id }
        save()
    }

    func moveWebtoon(id: UUID, toCategoryID: UUID) {
        guard let idx = uncategorizedWebtoons.firstIndex(where: { $0.id == id }) else { return }
        let w = uncategorizedWebtoons.remove(at: idx)
        guard let ci = categories.firstIndex(where: { $0.id == toCategoryID }) else {
            uncategorizedWebtoons.insert(w, at: idx)
            return
        }
        categories[ci].addWebtoon(w)
        save()
    }

    // MARK: - Bookmarks

    func addBookmark(title: String, url: String, note: String = "", to webtoonID: UUID, in categoryID: UUID) {
        guard let ci = categories.firstIndex(where: { $0.id == categoryID }),
              let wi = categories[ci].webtoons.firstIndex(where: { $0.id == webtoonID })
        else { return }
        let bm = WebBookmark(title: title, url: url, note: note)
        categories[ci].webtoons[wi].addBookmark(bm)
        save()
    }

    func removeBookmark(id: UUID, from webtoonID: UUID, in categoryID: UUID) {
        guard let ci = categories.firstIndex(where: { $0.id == categoryID }),
              let wi = categories[ci].webtoons.firstIndex(where: { $0.id == webtoonID })
        else { return }
        categories[ci].webtoons[wi].removeBookmark(id: id)
        save()
    }

    // MARK: - Quick add (creates default category if needed)

    func quickAddWebtoon(name: String, siteURL: String) {
        let w = LibraryWebtoon(name: name, siteURL: siteURL)
        uncategorizedWebtoons.append(w)
        save()
    }

    // MARK: - Series Management
    
    func isSaved(series: WebtoonSeries) -> Bool {
        return savedSeries.contains(series.id)
    }
    
    func toggleSave(series: WebtoonSeries) {
        if savedSeries.contains(series.id) {
            savedSeries.remove(series.id)
        } else {
            savedSeries.insert(series.id)
        }
        saveSavedSeries()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: key)
        }
        if let data = try? JSONEncoder().encode(uncategorizedWebtoons) {
            UserDefaults.standard.set(data, forKey: uncatKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let cats = try? JSONDecoder().decode([LibraryCategory].self, from: data) {
            categories = cats
        }
        if let data = UserDefaults.standard.data(forKey: uncatKey),
           let uncat = try? JSONDecoder().decode([LibraryWebtoon].self, from: data) {
            uncategorizedWebtoons = uncat
        }
    }
    
    private func saveSavedSeries() {
        let array = Array(savedSeries)
        UserDefaults.standard.set(array, forKey: savedSeriesKey)
    }
    
    private func loadSavedSeries() {
        if let array = UserDefaults.standard.array(forKey: savedSeriesKey) as? [String] {
            savedSeries = Set(array)
        }
    }
}
