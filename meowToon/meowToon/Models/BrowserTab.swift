import Foundation

struct BrowserTab: Identifiable, Codable {
    var id:          UUID   = UUID()
    var title:       String = "Nouvel onglet"
    var urlString:   String = ""
    var isInBrowser: Bool   = false
}
