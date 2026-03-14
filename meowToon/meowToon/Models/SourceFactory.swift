import Foundation

class SourceFactory {
    static let shared = SourceFactory()
    
    // For the POC, we return our native MangaDex scraper regardless of the Tachiyomi source tapped,
    // because iOS cannot natively run compiled Kotlin APKs from the Tachiyomi index,
    // and Akuma.moe specifically is locked behind DDoS-Guard preventing simple HTTP requests.
    func getSource(for sourceId: String) -> BaseSource {
        if sourceId == "mangadex" {
            return MangaDexSource()
        }
        
        // Fallback: Load JS example for everything else
        if let scriptPath = Bundle.main.path(forResource: "sample_source", ofType: "js"),
           let script = try? String(contentsOfFile: scriptPath, encoding: .utf8) {
            let descriptor = SourceDescriptor(name: "JS extension", lang: "fr", id: sourceId, baseUrl: "")
            return JavaScriptSource(descriptor: descriptor, script: script)
        }
        
        return MangaDexSource()
    }
}
