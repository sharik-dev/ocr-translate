import Foundation
import JavaScriptCore

/// Singleton engine to execute JavaScript scripts for extensions
class JSEngine {
    static let shared = JSEngine()
    
    private let context: JSContext
    
    private init() {
        self.context = JSContext()
        setupBridge()
    }
    
    private func setupBridge() {
        // Expose native logging
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("JS Log: \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "nativeLog" as NSString)
        
        // Expose a native fetch method (escaping DDoS-Guard if possible by using native URLSession)
        let nativeFetch: @convention(block) (String, JSValue?) -> Void = { urlString, callback in
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let html = String(data: data, encoding: .utf8) {
                        callback?.call(withArguments: [html])
                    }
                } catch {
                    print("JS Native Fetch Error: \(error)")
                    callback?.call(withArguments: [JSValue(nullIn: self.context) as Any])
                }
            }
        }
        context.setObject(nativeFetch, forKeyedSubscript: "nativeFetch" as NSString)
        
        // Expose a browser-based fetch for sites with Cloudflare
        let nativeBrowserFetch: @convention(block) (String, JSValue?) -> Void = { urlString, callback in
            guard let url = URL(string: urlString) else { return }
            
            HiddenWebViewManager.shared.fetchHTML(url: url) { html in
                callback?.call(withArguments: [html ?? NSNull()])
            }
        }
        context.setObject(nativeBrowserFetch, forKeyedSubscript: "nativeBrowserFetch" as NSString)
    }
    
    private let queue = DispatchQueue(label: "meowToon.jsEngine")
    
    /// Executes a script and returns the result
    func evaluateScript(_ script: String) -> JSValue? {
        queue.sync {
            return context.evaluateScript(script)
        }
    }
    
    /// Calls a specific function in the JS context
    func callFunction(_ name: String, withArguments args: [Any]) -> JSValue? {
        queue.sync {
            guard let function = context.objectForKeyedSubscript(name) else {
                print("JS Error: function \(name) not found")
                return nil
            }
            return function.call(withArguments: args)
        }
    }
}
