import Foundation

class SourceFactory {
    static let shared = SourceFactory()
    
    // For the POC, we return our native MangaDex scraper regardless of the Tachiyomi source tapped,
    // because iOS cannot natively run compiled Kotlin APKs from the Tachiyomi index,
    // and Akuma.moe specifically is locked behind DDoS-Guard preventing simple HTTP requests.
    func getSource(for sourceId: String) -> BaseSource {
        return MangaDexSource()
    }
}
