import Foundation
import WebKit
import Combine

@MainActor
class WebViewModel: ObservableObject {
    @Published var urlString:   String = ""
    @Published var title:       String = ""
    @Published var isLoading:   Bool   = false
    @Published var progress:    Double = 0
    @Published var canGoBack:   Bool   = false
    @Published var canGoForward: Bool  = false

    /// Set by WebViewContainerView after the WKWebView is created.
    weak var webView: WKWebView?

    // MARK: - Navigation

    func load(urlString raw: String) {
        var normalized = raw.trimmingCharacters(in: .whitespaces)
        if normalized.isEmpty { return }

        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            // Looks like a search query rather than a URL
            if normalized.contains(".") && !normalized.contains(" ") {
                normalized = "https://" + normalized
            } else {
                let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalized
                normalized = "https://www.google.com/search?q=\(encoded)"
            }
        }

        guard let url = URL(string: normalized) else { return }
        urlString = normalized
        webView?.load(URLRequest(url: url))
    }

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }
    func stop()      { webView?.stopLoading() }

    // MARK: - Screenshot

    /// Asynchronously captures the visible content of the web view as a UIImage.
    func takeSnapshot() async -> UIImage? {
        guard let webView else { return nil }
        return await withCheckedContinuation { continuation in
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
