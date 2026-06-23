import Foundation

// MARK: - Favorite type

enum FavoriteType: String, Codable, CaseIterable {
    case site    = "site"    // Shortcut on the Home screen
    case webtoon = "webtoon" // Stored in the Library

    var label: String {
        switch self {
        case .site:    return "Site (Accueil)"
        case .webtoon: return "Webtoon (Librairie)"
        }
    }

    var icon: String {
        switch self {
        case .site:    return "safari"
        case .webtoon: return "books.vertical.fill"
        }
    }
}

// MARK: - Model

struct FavoriteSite: Identifiable, Codable, Hashable {
    var id:             UUID
    var name:           String
    var urlString:      String
    var iconSystemName: String
    var type:           FavoriteType
    /// JPEG screenshot of the page at save time, compressed thumbnail (~300×200)
    var thumbnailData:  Data?

    init(
        id:             UUID         = UUID(),
        name:           String,
        urlString:      String,
        iconSystemName: String       = "globe",
        type:           FavoriteType = .site,
        thumbnailData:  Data?        = nil
    ) {
        self.id             = id
        self.name           = name
        self.urlString      = urlString
        self.iconSystemName = iconSystemName
        self.type           = type
        self.thumbnailData  = thumbnailData
    }

    var url: URL? { URL(string: urlString) }
}
