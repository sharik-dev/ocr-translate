import Foundation
import Combine

// MARK: - TabManager

@MainActor
final class TabManager: ObservableObject {

    @Published var tabs:        [BrowserTab] = []
    @Published var activeIndex: Int           = 0

    /// One WebViewModel per tab — keyed by tab ID.
    private(set) var viewModels: [UUID: WebViewModel] = [:]

    private var cancellables = Set<AnyCancellable>()

    private let tabsKey   = "browser.tabs"
    private let activeKey = "browser.activeIndex"

    // MARK: - Computed helpers

    var activeTab: BrowserTab? {
        tabs.indices.contains(activeIndex) ? tabs[activeIndex] : nil
    }

    var activeViewModel: WebViewModel? {
        activeTab.flatMap { viewModels[$0.id] }
    }

    var isActiveTabInBrowser: Bool {
        activeTab?.isInBrowser ?? false
    }

    func viewModel(for id: UUID) -> WebViewModel? {
        viewModels[id]
    }

    // MARK: - Init

    init() {
        restore()
        if tabs.isEmpty { addTab() }
    }

    // MARK: - Tab lifecycle

    @discardableResult
    func addTab() -> BrowserTab {
        let tab = BrowserTab()
        tabs.append(tab)
        viewModels[tab.id] = WebViewModel()
        activeIndex = tabs.count - 1
        persist()
        return tab
    }

    func closeTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        viewModels.removeValue(forKey: id)
        tabs.remove(at: idx)
        if tabs.isEmpty { addTab(); return }
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
        persist()
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
        persist()
    }

    // MARK: - State helpers (called from ContentView)

    func setInBrowser(_ value: Bool) {
        guard tabs.indices.contains(activeIndex) else { return }
        tabs[activeIndex].isInBrowser = value
        persist()
    }

    func syncActiveTabMeta(title: String, urlString: String) {
        guard tabs.indices.contains(activeIndex) else { return }
        if !title.isEmpty     { tabs[activeIndex].title     = title }
        if !urlString.isEmpty { tabs[activeIndex].urlString = urlString }
        persist()
    }

    // MARK: - Persistence

    func persist() {
        if let data = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(data, forKey: tabsKey)
        }
        UserDefaults.standard.set(activeIndex, forKey: activeKey)
    }

    private func restore() {
        let savedIndex = UserDefaults.standard.integer(forKey: activeKey)
        guard
            let data  = UserDefaults.standard.data(forKey: tabsKey),
            let saved = try? JSONDecoder().decode([BrowserTab].self, from: data),
            !saved.isEmpty
        else { return }

        tabs        = saved
        activeIndex = max(0, min(savedIndex, saved.count - 1))

        for tab in tabs {
            let vm = WebViewModel()
            if !tab.urlString.isEmpty {
                vm.pendingURL  = tab.urlString
                vm.urlString   = tab.urlString
                vm.title       = tab.title
            }
            viewModels[tab.id] = vm
        }
    }
}
