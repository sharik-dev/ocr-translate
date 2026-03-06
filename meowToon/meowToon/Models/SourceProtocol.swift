import Foundation

/// Protocol defining the interface for all native sources (Extensions)
protocol BaseSource {
    var id: String { get }
    var name: String { get }
    var lang: String { get }
    var baseURL: String { get }
    
    /// True if this source requires NSFW confirmation
    var isNSFW: Bool { get }
    
    // MARK: - API
    
    /// Fetches a list of popular or latest series from the source
    func fetchPopularSeries(page: Int) async throws -> [WebtoonSeries]
    
    /// Searches for series based on a query
    func searchSeries(query: String, page: Int) async throws -> [WebtoonSeries]
    
    /// Fetches details for a specific series (metadata, cover, etc.)
    func fetchSeriesDetails(series: WebtoonSeries) async throws -> WebtoonSeries
    
    /// Fetches the list of chapters for a given series
    func fetchChapters(for series: WebtoonSeries) async throws -> [WebtoonChapter]
    
    /// Fetches the list of imageURLs for a given chapter
    func fetchPageList(for chapter: WebtoonChapter) async throws -> [URL]
}
