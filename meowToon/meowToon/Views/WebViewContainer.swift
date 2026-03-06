import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        
        // Load AdBlock Rules
        if let rulesURL = Bundle.main.url(forResource: "AdBlockRules", withExtension: "json") {
            do {
                let rulesData = try String(contentsOf: rulesURL)
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "AdBlockRules",
                    encodedContentRuleList: rulesData
                ) { ruleList, error in
                    if let ruleList = ruleList {
                        config.userContentController.add(ruleList)
                        print("AdBlock rules applied successfully.")
                    } else if let error = error {
                        print("Failed to compile AdBlock rules: \(error)")
                    }
                }
            } catch {
                print("Failed to load AdBlock rules from file: \(error)")
            }
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true // Allow swipe to go back/forward
        
        // Set the reference in the ViewModel so we can trigger navigation and snapshots
        viewModel.webView = webView
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // We only load initial URL if it hasn't loaded yet,
        // otherwise we let the ViewModel explicit load() command handle it.
        // It's mostly handled via the action functions in WebViewModel.
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = true
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? ""
                self.parent.updateState(webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                if let viewTitle = webView.title {
                    self.parent.viewModel.title = viewTitle
                }
                self.parent.viewModel.urlString = webView.url?.absoluteString ?? ""
                self.parent.updateState(webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.updateState(webView)
            }
        }
    }
    
    func updateState(_ webView: WKWebView) {
        viewModel.canGoBack = webView.canGoBack
        viewModel.canGoForward = webView.canGoForward
    }
}
