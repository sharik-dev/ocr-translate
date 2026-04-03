import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    var isAdBlockEnabled: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        viewModel.webView = webView
        viewModel.loadPendingIfNeeded()

        // Apply adblock on creation if enabled
        if isAdBlockEnabled {
            Task { @MainActor in
                AdBlockManager.shared.apply(to: config.userContentController)
            }
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Dynamically apply/remove adblock rules when the toggle changes
        context.coordinator.syncAdBlock(enabled: isAdBlockEnabled, webView: webView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        private var adBlockApplied = false

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        @MainActor
        func syncAdBlock(enabled: Bool, webView: WKWebView) {
            let ucc = webView.configuration.userContentController
            if enabled && !adBlockApplied {
                AdBlockManager.shared.apply(to: ucc)
                adBlockApplied = true
            } else if !enabled && adBlockApplied {
                AdBlockManager.shared.remove(from: ucc)
                adBlockApplied = false
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = true
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? ""
                self.parent.updateState(webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.title = webView.title ?? ""
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? ""
                self.parent.updateState(webView)
            }
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.updateState(webView)
            }
        }
    }

    func updateState(_ webView: WKWebView) {
        viewModel.canGoBack    = webView.canGoBack
        viewModel.canGoForward = webView.canGoForward
    }
}
