import Foundation
import JavaScriptCore

/// A source implementation that delegates all logic to a JavaScript script
class JavaScriptSource: BaseSource {
    let id: String
    let name: String
    let lang: String
    let baseURL: String
    let isNSFW: Bool
    
    private let script: String
    private let engine = JSEngine.shared
    
    init(descriptor: SourceDescriptor, script: String) {
        self.id = descriptor.id
        self.name = descriptor.name
        self.lang = descriptor.lang
        self.baseURL = descriptor.baseUrl
        self.isNSFW = false // Mocked for now
        self.script = script
        
        // Initialize the script in the context
        _ = engine.evaluateScript(script)
    }
    
    func fetchPopularSeries(page: Int) async throws -> [WebtoonSeries] {
        return try await withCheckedThrowingContinuation { continuation in
            _ = engine.callFunction("fetchPopularSeries", withArguments: [page, { (result: JSValue?) in
                guard let result = result, result.isArray else {
                    continuation.resume(returning: [])
                    return
                }
                
                let series = self.mapJSArrayToSeries(result)
                continuation.resume(returning: series)
            } as @convention(block) (JSValue?) -> Void])
        }
    }
    
    func searchSeries(query: String, page: Int) async throws -> [WebtoonSeries] {
        return try await withCheckedThrowingContinuation { continuation in
            _ = engine.callFunction("searchSeries", withArguments: [query, page, { (result: JSValue?) in
                guard let result = result, result.isArray else {
                    continuation.resume(returning: [])
                    return
                }
                let series = self.mapJSArrayToSeries(result)
                continuation.resume(returning: series)
            } as @convention(block) (JSValue?) -> Void])
        }
    }
    
    func fetchSeriesDetails(series: WebtoonSeries) async throws -> WebtoonSeries {
        return series // Simplification for POC
    }
    
    func fetchChapters(for series: WebtoonSeries) async throws -> [WebtoonChapter] {
        return try await withCheckedThrowingContinuation { continuation in
            _ = engine.callFunction("fetchChapters", withArguments: [series.id, { (result: JSValue?) in
                guard let result = result, result.isArray else {
                    continuation.resume(returning: [])
                    return
                }
                
                let dicts = result.toArray() as? [[String: Any]] ?? []
                let chapters = dicts.map { dict in
                    WebtoonChapter(
                        id: dict["id"] as? String ?? "",
                        seriesId: series.id,
                        name: dict["name"] as? String ?? "Unnamed",
                        chapterNumber: Float(dict["number"] as? String ?? "0"),
                        dateUpload: Date()
                    )
                }
                continuation.resume(returning: chapters)
            } as @convention(block) (JSValue?) -> Void])
        }
    }
    
    func fetchPageList(for chapter: WebtoonChapter) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            _ = engine.callFunction("fetchPageList", withArguments: [chapter.id, { (result: JSValue?) in
                guard let result = result, result.isArray else {
                    continuation.resume(returning: [])
                    return
                }
                
                let strings = result.toArray() as? [String] ?? []
                let urls = strings.compactMap { URL(string: $0) }
                continuation.resume(returning: urls)
            } as @convention(block) (JSValue?) -> Void])
        }
    }
    
    // MARK: - Private Helpers
    private func mapJSArrayToSeries(_ array: JSValue) -> [WebtoonSeries] {
        let dicts = array.toArray() as? [[String: Any]] ?? []
        return dicts.map { dict in
            WebtoonSeries(
                id: dict["id"] as? String ?? "",
                sourceId: self.id,
                title: dict["title"] as? String ?? "Unknown",
                coverURL: dict["cover"] as? String,
                author: dict["author"] as? String,
                description: dict["description"] as? String,
                status: dict["status"] as? String
            )
        }
    }
}
