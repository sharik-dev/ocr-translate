import WebKit
import Combine

/// Singleton that compiles and caches the WKContentRuleList from AdBlockRules.json.
/// Supports dynamic enable/disable per WKUserContentController.
@MainActor
class AdBlockManager: ObservableObject {
    static let shared = AdBlockManager()

    private var compiledRuleList: WKContentRuleList?
    private var isLoaded = false

    private init() {
        loadRules()
    }

    private func loadRules() {
        guard let url  = Bundle.main.url(forResource: "AdBlockRules", withExtension: "json"),
              let data = try? String(contentsOf: url, encoding: .utf8)
        else {
            print("AdBlock: rules file not found")
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "meowToon.AdBlock",
            encodedContentRuleList: data
        ) { [weak self] list, error in
            if let list {
                self?.compiledRuleList = list
                self?.isLoaded = true
                print("AdBlock: \(list) compiled successfully")
            } else {
                print("AdBlock compile error: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    // MARK: - Apply / Remove

    func apply(to controller: WKUserContentController) {
        guard let list = compiledRuleList else { return }
        controller.removeAllContentRuleLists()
        controller.add(list)
    }

    func remove(from controller: WKUserContentController) {
        controller.removeAllContentRuleLists()
    }
}
