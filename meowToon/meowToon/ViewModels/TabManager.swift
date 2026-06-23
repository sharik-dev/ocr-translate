import Foundation
import Combine
import UIKit

// MARK: - TabManager

@MainActor
final class TabManager: ObservableObject {

    @Published var tabs:        [BrowserTab] = []
    @Published var activeIndex: Int           = 0
    /// In-memory thumbnail cache per tab. Reset on cold launch.
    @Published var thumbnails:  [UUID: UIImage] = [:]

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
        thumbnails.removeValue(forKey: id)
        tabs.remove(at: idx)
        if tabs.isEmpty { addTab(); return }
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
        persist()
    }

    func closeAllTabs() {
        viewModels.removeAll()
        thumbnails.removeAll()
        tabs.removeAll()
        activeIndex = 0
        addTab()  // always keep at least one
        persist()
    }

    // MARK: - Thumbnails

    func captureThumbnail(for tabID: UUID) async {
        guard let vm = viewModels[tabID], let raw = await vm.takeSnapshot() else { return }
        // Downscale to ~600px wide to keep memory reasonable
        let maxWidth: CGFloat = 600
        let scale = min(1.0, maxWidth / max(raw.size.width, 1))
        if scale >= 1.0 {
            thumbnails[tabID] = raw
            return
        }
        let target = CGSize(width: raw.size.width * scale, height: raw.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let small = renderer.image { _ in
            raw.draw(in: CGRect(origin: .zero, size: target))
        }
        thumbnails[tabID] = small
    }

    func captureActiveTabThumbnail() async {
        guard let tab = activeTab else { return }
        await captureThumbnail(for: tab.id)
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
