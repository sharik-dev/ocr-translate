import SwiftUI
import Translation

// MARK: - Theme constants (internal so sub-views can access)

let kGreen  = Color(red: 0.0, green: 0.835, blue: 0.392)
let kDarkBG = Color(red: 0.02, green: 0.06, blue: 0.02)

// MARK: - Persisted bubble position helpers

private func loadBubblePos() -> CGPoint {
    let x = UserDefaults.standard.double(forKey: "navBubble.x")
    let y = UserDefaults.standard.double(forKey: "navBubble.y")
    guard x != 0 || y != 0 else {
        return CGPoint(x: UIScreen.main.bounds.width / 2,
                       y: UIScreen.main.bounds.height - 90)
    }
    return CGPoint(x: x, y: y)
}

private func saveBubblePos(_ p: CGPoint) {
    UserDefaults.standard.set(Double(p.x), forKey: "navBubble.x")
    UserDefaults.standard.set(Double(p.y), forKey: "navBubble.y")
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var settingsVM     = SettingsViewModel()
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var ocrVM          = OCRViewModel()
    @StateObject private var tabManager     = TabManager()
    @StateObject private var navigator      = AppNavigator()

    // URL bar state (per session — resets on tab switch via onAppear)
    @State private var urlBarText   = ""
    @State private var isEditingURL = false

    // Sheets / dialogs
    @State private var showLibrary      = false
    @State private var showSettings     = false
    @State private var showBMChoice     = false
    @State private var showBMSheet      = false
    @State private var showFavOnboarding = false
    @State private var showTabGrid      = false
    @AppStorage("didSeeFavOnboarding") private var didSeeFavOnboarding: Bool = false

    @State private var showHistory   = false
    @State private var searchHistory: [String] = UserDefaults.standard.stringArray(forKey: "search.history") ?? []

    // Nav bar collapse / drag bubble
    @State        private var navExpanded    = true
    @State        private var bubblePos      = loadBubblePos()
    @GestureState private var bubbleDrag: CGSize = .zero
    @State        private var bubbleHasDragged = false

    // Floating button positions
    @State private var ocrBtnPos = CGPoint(
        x: UIScreen.main.bounds.width - 36,
        y: UIScreen.main.bounds.height - 270
    )
    @State private var favBtnPos = CGPoint(
        x: UIScreen.main.bounds.width - 36,
        y: UIScreen.main.bounds.height - 200
    )

    // Lazy-mounting: only create WebViewContainers for tabs that have been visited
    @State private var mountedTabIDs: Set<UUID> = []

    // MARK: - Computed helpers

    private var isInBrowser: Bool { tabManager.isActiveTabInBrowser }

    private var activeVM: WebViewModel {
        tabManager.activeViewModel ?? _fallbackVM
    }
    @StateObject private var _fallbackVM = WebViewModel()

    private var isSiteFavorite: Bool {
        settingsVM.favorites.contains { $0.urlString == activeVM.urlString && $0.type == .site }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                kDarkBG.ignoresSafeArea()

                // ── All lazily-mounted WebViews ────────────────────────────
                ForEach(tabManager.tabs) { tab in
                    if mountedTabIDs.contains(tab.id),
                       let vm = tabManager.viewModel(for: tab.id) {
                        let isActiveTab = tab.id == tabManager.activeTab?.id
                        let visible     = isActiveTab && isInBrowser
                        WebViewContainer(viewModel: vm,
                                         isAdBlockEnabled: settingsVM.isAdBlockEnabled)
                            .ignoresSafeArea()
                            .opacity(visible ? 1 : 0)
                            .allowsHitTesting(visible)
                    }
                }

                // ── Home overlay ──────────────────────────────────────────
                if !isInBrowser {
                    HomeContent()
                        .environmentObject(settingsVM)
                        .environmentObject(libraryManager)
                        .environmentObject(navigator)
                        .transition(.opacity)
                }

                // ── OCR overlays ──────────────────────────────────────────
                if ocrVM.isProcessing {
                    ocrProcessingOverlay
                } else if ocrVM.showOverlay {
                    OCRResultOverlay(items: ocrVM.recognizedItems) {
                        ocrVM.dismissOverlay()
                    }
                }

                // ── Floating OCR / Translate button (toujours visible) ────
                if !ocrVM.isProcessing {
                    FloatingBubbleButton(
                        position: $ocrBtnPos,
                        screenWidth: geo.size.width,
                        icon: "text.viewfinder",
                        dimmed: !settingsVM.translationSettings.isOCREnabled
                    ) {
                        if settingsVM.translationSettings.isOCREnabled {
                            Task { await triggerOCR() }
                        } else {
                            showSettings = true
                        }
                    }
                }

                // ── Floating Favorite button (toujours visible) ───────────
                FloatingBubbleButton(
                    position: $favBtnPos,
                    screenWidth: geo.size.width,
                    icon: isSiteFavorite ? "bookmark.fill" : "bookmark",
                    dimmed: !isInBrowser || activeVM.urlString.isEmpty
                ) {
                    if isInBrowser && !activeVM.urlString.isEmpty {
                        handleBookmarkTap()
                    } else {
                        showBMSheet = true
                    }
                }

                // ── Persistent nav bar ────────────────────────────────────
                if navExpanded {
                    VStack {
                        Spacer()
                        TabNavBar(
                            webVM:        activeVM,
                            isInBrowser:  isInBrowser,
                            tabCount:     tabManager.tabs.count,
                            geo:          geo,
                            onTapSearch: {
                                urlBarText   = isInBrowser ? activeVM.urlString : ""
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isEditingURL = true
                                }
                            },
                            onReload:     { activeVM.reload() },
                            onStop:       { activeVM.stop() },
                            onGoHome: {
                                isEditingURL = false
                                urlBarText   = ""
                                tabManager.setInBrowser(false)
                            },
                            onShowSettings: { showSettings = true },
                            onShowTabs:   { showTabGrid = true },
                            onCollapse:   {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    navExpanded = false
                                }
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // ── Collapsed draggable bubble ────────────────────────────
                if !navExpanded {
                    navBubble
                        .position(
                            x: bubblePos.x + bubbleDrag.width,
                            y: bubblePos.y + bubbleDrag.height
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                                .updating($bubbleDrag) { value, state, _ in
                                    state = value.translation
                                }
                                .onChanged { _ in bubbleHasDragged = true }
                                .onEnded { value in
                                    let margin: CGFloat = 32
                                    let rawX = bubblePos.x + value.translation.width
                                    let rawY = bubblePos.y + value.translation.height
                                    let snapX = rawX < geo.size.width / 2
                                        ? margin : geo.size.width - margin
                                    let clampedY = min(max(rawY, 60), geo.size.height - 60)
                                    let final = CGPoint(x: snapX, y: clampedY)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        bubblePos = final
                                    }
                                    saveBubblePos(final)
                                    DispatchQueue.main.async { bubbleHasDragged = false }
                                }
                        )
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }

                // ── Expanded search overlay ───────────────────────────
                if isEditingURL {
                    SearchBarOverlay(
                        text:          $urlBarText,
                        searchHistory: searchHistory,
                        onSubmit: {
                            submitURL()
                        },
                        onCancel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isEditingURL = false
                                urlBarText   = ""
                            }
                        },
                        onSelectHistory: { item in
                            urlBarText = item
                            submitURL()
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(45)
                }

                CaptchaResolverView()
                    .environmentObject(settingsVM)
                    .environmentObject(libraryManager)
                    .environmentObject(ocrVM)

                // ── Tab grid overlay ──────────────────────────────────────
                if showTabGrid {
                    TabGridView(
                        tabManager: tabManager,
                        onSelectTab: { idx in
                            tabManager.selectTab(at: idx)
                            if let id = tabManager.activeTab?.id {
                                mountedTabIDs.insert(id)
                            }
                            isEditingURL = false
                            urlBarText   = ""
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTabGrid = false
                            }
                        },
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTabGrid = false
                            }
                        },
                        onNewTab: {
                            tabManager.addTab()
                            if let id = tabManager.activeTab?.id {
                                mountedTabIDs.insert(id)
                            }
                            isEditingURL = false
                            urlBarText   = ""
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTabGrid = false
                            }
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(50)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: navExpanded)
            .animation(.easeInOut(duration: 0.2), value: isInBrowser)
            .animation(.easeInOut(duration: 0.18), value: showTabGrid)
            .onAppear {
                // Mount the active tab on first appear
                if let id = tabManager.activeTab?.id {
                    mountedTabIDs.insert(id)
                }
            }
            .onChange(of: tabManager.activeIndex) { _, _ in
                // Mount newly-selected tab (lazy creation)
                if let id = tabManager.activeTab?.id {
                    mountedTabIDs.insert(id)
                }
                // Reset URL bar for new tab context
                isEditingURL = false
                urlBarText   = ""
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: navigator.requestedURL) { _, url in
            guard let url else { return }
            loadURL(url)
            showLibrary = false
            navigator.requestedURL = nil
        }
        .onChange(of: settingsVM.translationSettings.targetLanguageCode) { _, _ in
            ocrVM.invalidateSession()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView()
                .environmentObject(libraryManager)
                .environmentObject(settingsVM)
                .environmentObject(navigator)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settingsVM)
                .environmentObject(ocrVM)
        }
        .sheet(isPresented: $showBMSheet) {
            AddBookmarkSheet(
                pageTitle: activeVM.title,
                pageURL:   activeVM.urlString
            )
            .environmentObject(libraryManager)
        }
        .sheet(isPresented: $showHistory) {
            SearchHistorySheet(
                items: searchHistory,
                onSelect: { item in
                    urlBarText = item
                    submitURL()
                    showHistory = false
                },
                onDelete: { index in
                    searchHistory.remove(at: index)
                    UserDefaults.standard.set(searchHistory, forKey: "search.history")
                },
                onClearAll: {
                    searchHistory.removeAll()
                    UserDefaults.standard.set(searchHistory, forKey: "search.history")
                }
            )
        }
        .sheet(isPresented: $showFavOnboarding) {
            FavoriteOnboardingSheet(
                onChooseHome: {
                    didSeeFavOnboarding = true
                    showFavOnboarding   = false
                    showBMChoice        = true
                },
                onChooseLibrary: {
                    didSeeFavOnboarding = true
                    showFavOnboarding   = false
                    showBMSheet         = true
                }
            )
        }
        .confirmationDialog("Enregistrer en tant que…",
                            isPresented: $showBMChoice,
                            titleVisibility: .visible) {
            Button("Favori Accueil")         { addSiteFavorite() }
            Button("Marque-page Librairie") { showBMSheet = true }
            Button("Annuler", role: .cancel)   {}
        }
        .translationTask(ocrVM.translationConfig) { session in
            await ocrVM.performTranslation(session: session)
        }
    }

    // MARK: - Collapsed bubble

    private var navBubble: some View {
        Button {
            guard !bubbleHasDragged else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                navExpanded = true
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .shadow(color: .white.opacity(0.9), radius: 6)
                .shadow(color: .white.opacity(0.8), radius: 14)
                .shadow(color: .white.opacity(0.55), radius: 28)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(bubbleDrag == .zero ? 1.0 : 1.08)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: bubbleDrag == .zero)
    }

// MARK: - Navigation helpers

    private func loadURL(_ raw: String) {
        isEditingURL = false
        urlBarText   = ""
        tabManager.setInBrowser(true)
        activeVM.load(urlString: raw)
        // Sync meta after a brief delay to let the webview settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tabManager.syncActiveTabMeta(
                title:     activeVM.title,
                urlString: activeVM.urlString
            )
        }
    }

    private func submitURL() {
        let text = urlBarText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { isEditingURL = false; return }
        if let existing = searchHistory.firstIndex(where: { $0.caseInsensitiveCompare(text) == .orderedSame }) {
            searchHistory.remove(at: existing)
        }
        searchHistory.insert(text, at: 0)
        if searchHistory.count > 50 { searchHistory.removeLast(searchHistory.count - 50) }
        UserDefaults.standard.set(searchHistory, forKey: "search.history")
        loadURL(text)
    }

    private func handleBookmarkTap() {
        let url = activeVM.urlString
        guard !url.isEmpty else { return }
        if isSiteFavorite {
            if let i = settingsVM.favorites.firstIndex(where: {
                $0.urlString == url && $0.type == .site
            }) {
                settingsVM.removeFavorite(at: IndexSet(integer: i))
            }
        } else {
            if !didSeeFavOnboarding {
                showFavOnboarding = true
            } else {
                showBMChoice = true
            }
        }
    }

    private func addSiteFavorite() {
        let url  = activeVM.urlString
        let name = activeVM.title.isEmpty ? url : activeVM.title
        settingsVM.addFavorite(FavoriteSite(name: name, urlString: url, type: .site))
    }

    // MARK: - OCR trigger

    @MainActor
    private func triggerOCR() async {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: \.isKeyWindow),
              let image = window.snapshot()
        else { return }

        ocrVM.startPipeline(
            image: image,
            viewSize: window.bounds.size,
            targetLanguageCode: settingsVM.translationSettings.targetLanguageCode,
            enableFallback: settingsVM.translationSettings.enableFallback
        )
    }

    // MARK: - OCR processing overlay

    private var ocrProcessingOverlay: some View {
        Color.black.opacity(0.45)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: kGreen))
                        Text("Analyse en cours…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .stroke(kGreen.opacity(0.3), lineWidth: 1))
                    )
                    .shadow(color: kGreen.opacity(0.2), radius: 10)

                    Button(action: { ocrVM.cancel() }) {
                        Text("Annuler")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white.opacity(0.1))
                                    .overlay(Capsule()
                                        .stroke(Color(red: 1, green: 0.4, blue: 0.4).opacity(0.35),
                                                lineWidth: 0.5))
                            )
                            .shadow(color: Color(red: 1, green: 0.4, blue: 0.4).opacity(0.4), radius: 8, y: 1)
                    }
                }
            )
    }
}

// MARK: - TabNavBar
// Observes the active WebViewModel so nav state stays in sync on tab switches.

private struct TabNavBar: View {

    @ObservedObject var webVM: WebViewModel
    let isInBrowser:  Bool
    let tabCount:     Int
    let geo:          GeometryProxy

    var onTapSearch:    () -> Void
    var onReload:       () -> Void
    var onStop:         () -> Void
    var onGoHome:       () -> Void
    var onShowSettings: () -> Void
    var onShowTabs:     () -> Void
    var onCollapse:     () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // URL / search display (tap → expands overlay)
            urlDisplayButton
                .padding(.horizontal, 6)

            // Reload / Stop
            if isInBrowser {
                if webVM.isLoading {
                    navBtn("xmark", action: onStop)
                } else {
                    navBtn("arrow.clockwise", action: onReload)
                }
            }

            // Home
            navBtn("house.fill", dim: !isInBrowser, action: onGoHome)

            // Settings
            navBtn("gear", action: onShowSettings)

            // Tab switcher — shows count badge
            tabCountButton

            // Collapse
            navBtn("chevron.down", action: onCollapse)
        }
        .padding(.horizontal, 8)
        .frame(width: geo.size.width - 16, height: 58)
        .background(glassBackground)
    }

    // MARK: - URL display button

    private var urlDisplayButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTapSearch()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Text(isInBrowser
                     ? (webVM.title.isEmpty ? webVM.urlString : webVM.title)
                     : "Rechercher ou entrer une URL…")
                    .font(.system(size: 13))
                    .foregroundColor(isInBrowser ? .white.opacity(0.85) : .white.opacity(0.3))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5))
        )
    }

    // MARK: - Tab count button

    private var tabCountButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onShowTabs()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white, lineWidth: 1.5)
                    .shadow(color: .white.opacity(0.9), radius: 6)
                    .shadow(color: .white.opacity(0.8), radius: 14)
                    .shadow(color: .white.opacity(0.55), radius: 28)
                    .frame(width: 22, height: 17)
                Text("\(tabCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.9), radius: 6)
                    .shadow(color: .white.opacity(0.8), radius: 14)
                    .shadow(color: .white.opacity(0.55), radius: 28)
            }
            .frame(width: 40, height: 58)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generic nav button

    private func navBtn(
        _ icon: String,
        dim: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard !dim else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(dim ? 0.2 : 1.0))
                .shadow(color: .white.opacity(dim ? 0 : 0.9), radius: 6)
                .shadow(color: .white.opacity(dim ? 0 : 0.8), radius: 14)
                .shadow(color: .white.opacity(dim ? 0 : 0.55), radius: 28)
                .frame(width: 40, height: 58)
        }
        .disabled(dim)
    }

    // MARK: - Glass background

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.15), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 16)
    }
}

// MARK: - UIView window snapshot for OCR

extension UIView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: ctx)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - SearchHistorySheet

struct SearchHistorySheet: View {
    let items:     [String]
    let onSelect:  (String) -> Void
    let onDelete:  (Int) -> Void
    let onClearAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.ignoresSafeArea()
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Aucun historique")
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            Button(action: { onSelect(item) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(kGreen)
                                    Text(item)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { onDelete(idx) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundColor(.white.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !items.isEmpty {
                        Button("Tout effacer") { onClearAll() }
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - FavoriteOnboardingSheet

struct FavoriteOnboardingSheet: View {
    let onChooseHome:    () -> Void
    let onChooseLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.ignoresSafeArea()
                VStack(spacing: 22) {
                    Text("Où ranger ce favori ?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Choisissez entre un accès rapide sur l'écran d'accueil ou l'organisation dans la Librairie (catégorie/webtoon).")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    VStack(spacing: 12) {
                        Button(action: onChooseHome) {
                            Text("Favori Accueil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.4), radius: 6)
                                .padding(.vertical, 12).frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.2), lineWidth: 1))
                                )
                        }
                        Button(action: onChooseLibrary) {
                            Text("Marque-page Librairie")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.vertical, 12).frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Ajouter aux favoris")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - FloatingBubbleButton

struct FloatingBubbleButton: View {
    @Binding var position: CGPoint
    let screenWidth: CGFloat
    let icon:        String
    var dimmed:      Bool = false
    let action:      () -> Void

    @GestureState private var drag: CGSize = .zero
    @State private var hasDragged = false

    var body: some View {
        Button {
            guard !hasDragged else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(dimmed ? 0.25 : 1.0))
                .shadow(color: .white.opacity(dimmed ? 0 : 0.9), radius: 6)
                .shadow(color: .white.opacity(dimmed ? 0 : 0.8), radius: 14)
                .shadow(color: .white.opacity(dimmed ? 0 : 0.55), radius: 28)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(drag == .zero ? 1 : 1.07)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: drag == .zero)
        .position(
            x: position.x + drag.width,
            y: position.y + drag.height
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .updating($drag) { value, state, _ in state = value.translation }
                .onChanged { _ in hasDragged = true }
                .onEnded { value in
                    let margin: CGFloat = 32
                    let screenH = UIScreen.main.bounds.height
                    let nx = max(margin, min(screenWidth - margin,
                                             position.x + value.translation.width))
                    let ny = max(margin + 50, min(screenH - margin - 50,
                                                  position.y + value.translation.height))
                    position = CGPoint(x: nx, y: ny)
                    // Reset on next tick — after any tap handler has already fired
                    DispatchQueue.main.async { hasDragged = false }
                }
        )
    }

}

// MARK: - SearchBarOverlay

private struct SearchBarOverlay: View {
    @Binding var text: String
    let searchHistory:    [String]
    let onSubmit:         () -> Void
    let onCancel:         () -> Void
    let onSelectHistory:  (String) -> Void

    @FocusState private var isFocused: Bool

    private var filteredHistory: [String] {
        guard !text.isEmpty else { return Array(searchHistory.prefix(6)) }
        return searchHistory
            .filter { $0.localizedCaseInsensitiveContains(text) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim background — tap to dismiss
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Search panel
            VStack(spacing: 0) {
                // History suggestions
                if !filteredHistory.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(filteredHistory, id: \.self) { item in
                            Button(action: { onSelectHistory(item) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.35))
                                        .frame(width: 20)
                                    Text(item)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: {
                                        text = item
                                    }) {
                                        Image(systemName: "arrow.up.left")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                            }
                            if item != filteredHistory.last {
                                Divider()
                                    .background(Color.white.opacity(0.07))
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(kGreen)

                    TextField("URL ou recherche…", text: $text)
                        .focused($isFocused)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .tint(kGreen)
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { onSubmit() }

                    if !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Button("Annuler") { onCancel() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [kGreen.opacity(0.5), kGreen.opacity(0.15)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: kGreen.opacity(0.15), radius: 16, y: -4)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: -2)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: filteredHistory.count)
        }
        .onAppear { isFocused = true }
    }
}

#Preview { ContentView() }
