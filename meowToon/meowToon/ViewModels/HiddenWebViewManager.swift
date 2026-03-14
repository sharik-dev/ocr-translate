import Foundation
import WebKit
import SwiftUI
import Combine

/// A manager that holds a background WKWebView for scraping sites with high security (Cloudflare/DDoS-Guard)
class HiddenWebViewManager: NSObject, ObservableObject {
    static let shared = HiddenWebViewManager()
    
    @Published var isShowingCaptcha = false
    @Published var currentURL: URL?
    
    private(set) var webView: WKWebView!
    private var completionHandler: ((String?) -> Void)?
    
    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        // Ensure we don't block anything that might be needed for Captchas
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
    }
    
    func fetchHTML(url: URL, completion: @escaping (String?) -> Void) {
        self.completionHandler = completion
        self.currentURL = url
        
        DispatchQueue.main.async {
            self.webView.load(URLRequest(url: url))
        }
    }
}

extension HiddenWebViewManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Evaluate if we are on a challenge page
        webView.evaluateJavaScript("document.title") { (result, error) in
            let title = result as? String ?? ""
            if title.contains("Cloudflare") || title.contains("DDoS-Guard") || title.contains("Just a moment") {
                print("HiddenWebView: Challenge detected (\(title))")
                DispatchQueue.main.async {
                    self.isShowingCaptcha = true
                }
            } else {
                // Not a challenge, extract HTML
                webView.evaluateJavaScript("document.documentElement.outerHTML") { (html, error) in
                    self.completionHandler?(html as? String)
                    self.completionHandler = nil
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("HiddenWebView: Failed navigation: \(error)")
        completionHandler?(nil)
        completionHandler = nil
    }
}

/// A simple wrapper to show the hidden webview for captcha solving
struct CaptchaWebViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        return HiddenWebViewManager.shared.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
