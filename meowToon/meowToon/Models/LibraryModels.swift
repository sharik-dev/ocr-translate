import Foundation

// MARK: - Bookmark (a saved page inside a webtoon)

struct WebBookmark: Identifiable, Codable {
    var id:      UUID   = UUID()
    var title:   String
    var url:     String
    var note:    String = ""      // e.g. "Chapitre 45"
    var savedAt: Date   = Date()

    /// Human-readable relative date
    var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: savedAt, relativeTo: Date())
    }
}

// MARK: - Webtoon folder

struct LibraryWebtoon: Identifiable, Codable {
    var id:         UUID         = UUID()
    var name:       String
    var siteURL:    String       = ""   // homepage of the series
    var iconName:   String       = "books.vertical"
    /// Newest bookmark first
    var bookmarks:  [WebBookmark] = []

    mutating func addBookmark(_ bm: WebBookmark) {
        bookmarks.insert(bm, at: 0)
    }

    mutating func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }
}

// MARK: - Category folder

struct LibraryCategory: Identifiable, Codable {
    var id:       UUID             = UUID()
    var name:     String
    var emoji:    String           = "📂"
    var webtoons: [LibraryWebtoon] = []

    mutating func addWebtoon(_ w: LibraryWebtoon) {
        webtoons.append(w)
    }

    mutating func removeWebtoon(id: UUID) {
        webtoons.removeAll { $0.id == id }
    }

    mutating func addBookmark(_ bm: WebBookmark, to webtoonID: UUID) {
        guard let i = webtoons.firstIndex(where: { $0.id == webtoonID }) else { return }
        webtoons[i].addBookmark(bm)
    }
}
