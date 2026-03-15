import SwiftUI
import Translation

private let kGreen  = Color(red: 0.12, green: 0.92, blue: 0.45)
private let kDarkBG = Color(red: 0.02, green: 0.06, blue: 0.02)

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
    @StateObject private var webVM          = WebViewModel()
    @StateObject private var navigator      = AppNavigator()

    // Browser state
    @State private var isInBrowser  = false
    @State private var urlBarText   = ""
    @State private var isEditingURL = false

    // Sheets / dialogs
    @State private var showLibrary  = false
    @State private var showSettings = false
    @State private var showBMChoice = false
    @State private var showBMSheet  = false
    @State private var showFavOnboarding = false
    @AppStorage("didSeeFavOnboarding") private var didSeeFavOnboarding: Bool = false

    @State private var showHistory = false
    @State private var searchHistory: [String] = UserDefaults.standard.stringArray(forKey: "search.history") ?? []

    // Nav bar
    @State private var navExpanded      = true
    @State private var bubblePos        = loadBubblePos()
    @State private var isDraggingBubble = false

    // Floating OCR button
    @State private var ocrBtnPos = CGPoint(
        x: UIScreen.main.bounds.width  - 46,
        y: UIScreen.main.bounds.height - 200
    )
    @State private var favBtnPos = CGPoint(
        x: 60,
        y: UIScreen.main.bounds.height - 200
    )

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                kDarkBG.ignoresSafeArea()

                // ── WebView — always in hierarchy, invisible on home ───────
                WebViewContainer(viewModel: webVM,
                                 isAdBlockEnabled: settingsVM.isAdBlockEnabled)
                    .ignoresSafeArea()
                    .opacity(isInBrowser ? 1 : 0)
                    .allowsHitTesting(isInBrowser)

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

                // ── Floating OCR button ───────────────────────────────────
                if settingsVM.translationSettings.isOCREnabled && !ocrVM.isProcessing {
                    FloatingBubbleButton(position: $ocrBtnPos, screenWidth: geo.size.width, icon: "text.viewfinder", gradient: LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                        Task { await triggerOCR() }
                    }
                }

                // ── Floating Favorite button ─────────────────────────────
                if isInBrowser && !webVM.urlString.isEmpty {
                    FloatingBubbleButton(position: $favBtnPos, screenWidth: geo.size.width, icon: isSiteFavorite ? "bookmark.fill" : "bookmark", gradient: LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                        handleBookmarkTap()
                    }
                }

                // ── Persistent nav bar ────────────────────────────────────
                if navExpanded {
                    VStack {
                        Spacer()
                        navBar(geo: geo)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // ── Collapsed draggable bubble ────────────────────────────
                if !navExpanded {
                    navBubble
                        .position(bubblePos)
                        .gesture(bubbleDrag(geo: geo))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }

                CaptchaResolverView()
                    .environmentObject(settingsVM)
                    .environmentObject(libraryManager)
                    .environmentObject(ocrVM)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: navExpanded)
            .animation(.easeInOut(duration: 0.2), value: isInBrowser)
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
            AddBookmarkSheet(pageTitle: webVM.title, pageURL: webVM.urlString)
                .environmentObject(libraryManager)
        }
        .sheet(isPresented: $showHistory) {
            SearchHistorySheet(items: searchHistory, onSelect: { item in
                urlBarText = item
                submitURL()
                showHistory = false
            }, onDelete: { index in
                searchHistory.remove(at: index)
                UserDefaults.standard.set(searchHistory, forKey: "search.history")
            }, onClearAll: {
                searchHistory.removeAll()
                UserDefaults.standard.set(searchHistory, forKey: "search.history")
            })
        }
        .sheet(isPresented: $showFavOnboarding) {
            FavoriteOnboardingSheet(onChooseHome: {
                didSeeFavOnboarding = true
                showFavOnboarding = false
                showBMChoice = true
            }, onChooseLibrary: {
                didSeeFavOnboarding = true
                showFavOnboarding = false
                showBMSheet = true
            })
        }
        .confirmationDialog("Enregistrer en tant que…",
                            isPresented: $showBMChoice,
                            titleVisibility: .visible) {
            Button("⭐ Favori Accueil")         { addSiteFavorite() }
            Button("🔖 Marque-page Librairie") { showBMSheet = true }
            Button("Annuler", role: .cancel)   {}
        }
        // Vue cachée qui héberge le .translationTask.
        // À chaque appui, run() appelle invalidate() sur la config existante →
        // version++ → config ≠ ancienne → .translationTask reçoit une session fraîche.
        .translationTask(ocrVM.translationConfig) { session in
            await ocrVM.performTranslation(session: session)
        }
    }

    // MARK: - Nav bar

    private func navBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 2) {
            // URL / Search field (flexible)
            urlField
                .padding(.horizontal, 4)

            // ↺ Reload / ✕ Stop — shown in browser only
            if isInBrowser {
                if webVM.isLoading {
                    navBtn("xmark", dim: false,
                           glowColor: Color(red: 1, green: 0.3, blue: 0.25)) { webVM.stop() }
                } else {
                    navBtn("arrow.clockwise", dim: false,
                           glowColor: Color(red: 0.25, green: 0.7, blue: 1)) { webVM.reload() }
                }
            }

            // 📚 Library — green glow
            navBtn("books.vertical.fill", dim: false, glowColor: kGreen) { showLibrary = true }

            // ⚙️ Settings — amber glow
            navBtn("gear", dim: false,
                   glowColor: Color(red: 1, green: 0.78, blue: 0.2)) { showSettings = true }

            // ↙ Collapse — soft rose glow
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    navExpanded = false
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .shadow(color: Color(red: 1, green: 0.4, blue: 0.6).opacity(0.55), radius: 6,  y: 1)
                    .shadow(color: Color(red: 1, green: 0.4, blue: 0.6).opacity(0.25), radius: 14, y: 2)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: geo.size.width - 24, height: 46)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.28)))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(isEditingURL ? kGreen.opacity(0.6) : Color.clear, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
    }

    // MARK: - URL / Search field

    private var urlField: some View {
        Group {
            if isEditingURL {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    TextField("URL ou recherche…", text: $urlBarText)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .tint(kGreen)
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { submitURL() }
                    if !urlBarText.isEmpty {
                        Button(action: { urlBarText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            } else {
                Button(action: {
                    urlBarText = isInBrowser ? webVM.urlString : ""
                    isEditingURL = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                        Text(isInBrowser
                             ? (webVM.title.isEmpty ? webVM.urlString : webVM.title)
                             : "Rechercher ou entrer une URL…")
                            .font(.system(size: 12))
                            .foregroundColor(isInBrowser ? .white.opacity(0.85) : .white.opacity(0.3))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(isEditingURL ? kGreen.opacity(0.6) : Color.clear, lineWidth: 1))
        )
    }

    // MARK: - Collapsed bubble

    private var navBubble: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                navExpanded = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.black.opacity(0.45)))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    .frame(width: 50, height: 50)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(kGreen)
                    .shadow(color: kGreen.opacity(0.8), radius: 8,  y: 1)
                    .shadow(color: kGreen.opacity(0.4), radius: 18, y: 2)
            }
            .shadow(color: kGreen.opacity(0.25), radius: 10, y: 3)
            .shadow(color: .black.opacity(0.4),  radius: 4)
        }
        .scaleEffect(isDraggingBubble ? 1.08 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDraggingBubble)
    }

    private func bubbleDrag(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                isDraggingBubble = true
                bubblePos = v.location
            }
            .onEnded { v in
                isDraggingBubble = false
                let margin: CGFloat = 32
                let snapX = v.location.x < geo.size.width / 2
                    ? margin : geo.size.width - margin
                let clampedY = min(max(v.location.y, 60), geo.size.height - 60)
                let final = CGPoint(x: snapX, y: clampedY)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    bubblePos = final
                }
                saveBubblePos(final)
            }
    }

    // MARK: - Nav helpers

    @ViewBuilder
    private func navBtn(_ icon: String, dim: Bool,
                        glowColor: Color = kGreen,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(dim ? 0.25 : 0.92))
                // double-layer glow for a soft halo
                .shadow(color: glowColor.opacity(dim ? 0 : 0.65), radius: 6,  y: 1)
                .shadow(color: glowColor.opacity(dim ? 0 : 0.30), radius: 14, y: 2)
                .frame(width: 32, height: 32)
        }
        .disabled(dim)
    }

    private var isSiteFavorite: Bool {
        settingsVM.favorites.contains { $0.urlString == webVM.urlString && $0.type == .site }
    }

    private func loadURL(_ raw: String) {
        isEditingURL = false
        withAnimation { isInBrowser = true }
        webVM.load(urlString: raw)
        urlBarText = ""
    }

    private func goHome() {
        isEditingURL = false
        withAnimation { isInBrowser = false }
        urlBarText = ""
    }

    private func submitURL() {
        let text = urlBarText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { isEditingURL = false; return }
        // Save to history (unique, most recent first, max 50)
        if let existing = searchHistory.firstIndex(where: { $0.caseInsensitiveCompare(text) == .orderedSame }) {
            searchHistory.remove(at: existing)
        }
        searchHistory.insert(text, at: 0)
        if searchHistory.count > 50 { searchHistory.removeLast(searchHistory.count - 50) }
        UserDefaults.standard.set(searchHistory, forKey: "search.history")
        loadURL(text)
    }

    private func handleBookmarkTap() {
        let url = webVM.urlString
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
        let url  = webVM.urlString
        let name = webVM.title.isEmpty ? url : webVM.title
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
            .overlay(                VStack(spacing: 16) {
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
                                        .stroke(Color(red: 1, green: 0.4, blue: 0.4).opacity(0.35), lineWidth: 0.5))
                            )
                            .shadow(color: Color(red: 1, green: 0.4, blue: 0.4).opacity(0.4), radius: 8, y: 1)
                    }
                }
            )
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

struct SearchHistorySheet: View {
    let items: [String]
    let onSelect: (String) -> Void
    let onDelete: (Int) -> Void
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

struct FavoriteOnboardingSheet: View {
    let onChooseHome: () -> Void
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
                            HStack { Image(systemName: "star.fill"); Text("Favori Accueil") }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.vertical, 12).frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [kGreen, .cyan], startPoint: .leading, endPoint: .trailing)))
                        }
                        Button(action: onChooseLibrary) {
                            HStack { Image(systemName: "books.vertical"); Text("Marque-page Librairie") }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(kGreen)
                                .padding(.vertical, 12).frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(kGreen.opacity(0.25), lineWidth: 1))
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

struct FloatingBubbleButton: View {
    @Binding var position: CGPoint
    let screenWidth: CGFloat
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    // @GestureState resets itself to .zero on gesture end — no manual cleanup needed.
    // All drag-position math stays local; the parent binding is only written once on release.
    @GestureState private var dragTranslation: CGSize = .zero

    private var isDragging: Bool {
        dragTranslation.width != 0 || dragTranslation.height != 0
    }

    private var ghostCenter: CGPoint {
        CGPoint(x: position.x + dragTranslation.width,
                y: position.y + dragTranslation.height)
    }

    var body: some View {
        // Color.clear fills the parent ZStack so absolute .position() coordinates
        // are relative to the full screen, exactly like the original implementation.
        ZStack {
            Color.clear.allowsHitTesting(false)

            // ── Ghost (lightweight — shown only while dragging) ───────────
            if isDragging {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(gradient)
                        .shadow(color: .white.opacity(0.5), radius: 6)
                }
                .position(ghostCenter)
                .allowsHitTesting(false)
            }

            // ── Real button — dims while ghost is active ──────────────────
            Button(action: { if !isDragging { action() } }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.black.opacity(0.35)))
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(gradient)
                        .shadow(color: Color(red: 0.12, green: 0.92, blue: 0.45).opacity(0.7), radius: 8)
                        .shadow(color: Color(red: 0.12, green: 0.92, blue: 0.45).opacity(0.3), radius: 18)
                }
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
            }
            .position(position)
            .opacity(isDragging ? 0.22 : 1)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    // .updating keeps all state inside GestureState — zero allocations per frame
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let margin: CGFloat = 32
                        let screenH = UIScreen.main.bounds.height
                        let nx = max(margin, min(screenWidth - margin,
                                                 position.x + value.translation.width))
                        let ny = max(margin + 50, min(screenH - margin - 50,
                                                      position.y + value.translation.height))
                        // Single binding write → single parent re-render
                        position = CGPoint(x: nx, y: ny)
                    }
            )
        }
    }
}

#Preview { ContentView() }
