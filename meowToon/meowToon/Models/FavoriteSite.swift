import Foundation

struct FavoriteSite: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var urlString: String
    var iconSystemName: String

    init(id: UUID = UUID(), name: String, urlString: String, iconSystemName: String = "globe") {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.iconSystemName = iconSystemName
    }

    var url: URL? { URL(string: urlString) }

    // MARK: - Default webtoon sites
    static let defaults: [FavoriteSite] = [
        .init(name: "Webtoons",    urlString: "https://www.webtoons.com",  iconSystemName: "rectangle.stack"),
        .init(name: "MangaDex",    urlString: "https://mangadex.org",      iconSystemName: "books.vertical"),
        .init(name: "Tapas",       urlString: "https://tapas.io",          iconSystemName: "newspaper"),
        .init(name: "Tappytoon",   urlString: "https://www.tappytoon.com", iconSystemName: "book"),
        .init(name: "Lezhin",      urlString: "https://www.lezhin.com",    iconSystemName: "heart"),
        .init(name: "Comico",      urlString: "https://www.comico.jp",     iconSystemName: "star"),
    ]
}
