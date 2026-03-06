import Foundation

// MARK: - Tachiyomi JSON Repository Models

/// Top level object representing a package inside the `index.min.json`
struct RepoExtension: Codable, Identifiable, Equatable, Hashable {
    var id: String { pkg }
    let name: String
    let pkg: String
    let apk: String
    let lang: String
    let code: Int
    let version: String
    let nsfw: Int
    let sources: [SourceDescriptor]?
}

/// Represents a source inside a package
struct SourceDescriptor: Codable, Identifiable, Equatable, Hashable {
    let name: String
    let lang: String
    let id: String
    let baseUrl: String
}

// MARK: - Application Native Models

/// Represents a Webtoon/Manga series fetched from a source
struct WebtoonSeries: Identifiable, Hashable, Codable {
    let id: String // Usually the URL path (e.g., "/manga/my-series")
    let sourceId: String // The ID of the BaseSource that provides it
    let title: String
    let coverURL: String?
    let author: String?
    let description: String?
    let status: String? // "Ongoing", "Completed", etc.
}

/// Represents a Chapter of a WebtoonSeries
struct WebtoonChapter: Identifiable, Hashable {
    let id: String // Usually the URL path (e.g., "/chapter/123")
    let seriesId: String // Links back to the WebtoonSeries
    let name: String
    let chapterNumber: Float?
    let dateUpload: Date?
}
