import Foundation

// MARK: - MangaDex API Response Models
fileprivate struct MDResponse<T: Decodable>: Decodable {
    let data: T
}

fileprivate struct MDListResponse<T: Decodable>: Decodable {
    let data: [T]
}

fileprivate struct MDManga: Decodable {
    let id: String
    let attributes: MDMangaAttributes
    let relationships: [MDRelationship]
}

fileprivate struct MDMangaAttributes: Decodable {
    let title: [String: String]
    let description: [String: String]?
    let status: String?
}

fileprivate struct MDRelationship: Decodable {
    let id: String
    let type: String
    let attributes: MDRelationshipAttributes?
}

fileprivate struct MDRelationshipAttributes: Decodable {
    let fileName: String?
    let name: String?
}

fileprivate struct MDChapter: Decodable {
    let id: String
    let attributes: MDChapterAttributes
}

fileprivate struct MDChapterAttributes: Decodable {
    let title: String?
    let chapter: String?
    let externalUrl: String?
}

fileprivate struct MDAtHomeResponse: Decodable {
    let baseUrl: String
    let chapter: MDAtHomeChapter
}

fileprivate struct MDAtHomeChapter: Decodable {
    let hash: String
    let data: [String]
}

// MARK: - MangaDex Source Implementation
class MangaDexSource: BaseSource {
    var id: String = "mangadex"
    var name: String = "MangaDex (Native Demo)"
    var lang: String = "en"
    var baseURL: String = "https://api.mangadex.org"
    var isNSFW: Bool = false
    
    func fetchPopularSeries(page: Int) async throws -> [WebtoonSeries] {
        let offset = (page - 1) * 20
        let urlString = "\(baseURL)/manga?includes[]=cover_art&includes[]=author&order[followedCount]=desc&limit=20&offset=\(offset)"
        return try await fetchSeriesList(from: urlString)
    }
    
    func searchSeries(query: String, page: Int) async throws -> [WebtoonSeries] {
        let offset = (page - 1) * 20
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let urlString = "\(baseURL)/manga?title=\(encodedQuery)&includes[]=cover_art&includes[]=author&limit=20&offset=\(offset)"
        return try await fetchSeriesList(from: urlString)
    }
    
    func fetchSeriesDetails(series: WebtoonSeries) async throws -> WebtoonSeries {
        // WebtoonSeries already has metadata populated from fetchList.
        return series
    }
    
    func fetchChapters(for series: WebtoonSeries) async throws -> [WebtoonChapter] {
        // Fetch english chapters for simplicity in POC
        let urlString = "\(baseURL)/manga/\(series.id)/feed?translatedLanguage[]=en&translatedLanguage[]=fr&order[chapter]=desc&limit=100"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("meowToon/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MDListResponse<MDChapter>.self, from: data)
        
        return response.data.map { chapter in
            let title = chapter.attributes.title ?? ""
            let chapterNum = chapter.attributes.chapter ?? "?"
            let displayName = title.isEmpty ? "Chapter \(chapterNum)" : "Ch. \(chapterNum) - \(title)"
            
            return WebtoonChapter(
                id: chapter.id,
                seriesId: series.id,
                name: displayName,
                chapterNumber: Float(chapter.attributes.chapter ?? "0"),
                dateUpload: Date() // Mocking date for brevity
            )
        }
    }
    
    func fetchPageList(for chapter: WebtoonChapter) async throws -> [URL] {
        let urlString = "\(baseURL)/at-home/server/\(chapter.id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("meowToon/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MDAtHomeResponse.self, from: data)
        
        let host = response.baseUrl
        let hash = response.chapter.hash
        
        // Build image URLs
        return response.chapter.data.compactMap { filename in
            URL(string: "\(host)/data/\(hash)/\(filename)")
        }
    }
    
    // MARK: - Private Helpers
    private func fetchSeriesList(from urlString: String) async throws -> [WebtoonSeries] {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("meowToon/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MDListResponse<MDManga>.self, from: data)
        
        return response.data.map { manga in
            let title = manga.attributes.title.values.first ?? "Unknown Title"
            let desc = manga.attributes.description?.values.first ?? "No description"
            
            var coverURL: String? = nil
            var authorName = "Unknown"
            
            if let coverRel = manga.relationships.first(where: { $0.type == "cover_art" }),
               let fileName = coverRel.attributes?.fileName {
                coverURL = "https://uploads.mangadex.org/covers/\(manga.id)/\(fileName).256.jpg"
            }
            
            if let authorRel = manga.relationships.first(where: { $0.type == "author" }),
               let name = authorRel.attributes?.name {
                authorName = name
            }
            
            return WebtoonSeries(
                id: manga.id,
                sourceId: self.id,
                title: title,
                coverURL: coverURL,
                author: authorName,
                description: desc,
                status: manga.attributes.status?.capitalized
            )
        }
    }
}
