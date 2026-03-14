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

    // Nav bar
    @State private var navExpanded      = true
    @State private var bubblePos        = loadBubblePos()
    @State private var isDraggingBubble = false

    // Floating OCR button
    @State private var ocrBtnPos = CGPoint(
        x: UIScreen.main.bounds.width  - 46,
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
                    FloatingOCRButton(position: $ocrBtnPos, screenWidth: geo.size.width) {
                        Task { await triggerOCR() }
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
        .confirmationDialog("Enregistrer en tant que…",
                            isPresented: $showBMChoice,
                            titleVisibility: .visible) {
            Button("⭐ Favori Accueil")         { addSiteFavorite() }
            Button("🔖 Marque-page Librairie") { showBMSheet = true }
            Button("Annuler", role: .cancel)   {}
        }
        .translationTask(ocrVM.translationConfig) { session in
            await ocrVM.performTranslation(
                session: session,
                fallback: settingsVM.translationSettings.enableFallback)
        }
    }

    // MARK: - Nav bar

    private func navBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 2) {
            // ← Back
            navBtn("chevron.left", dim: !isInBrowser || !webVM.canGoBack) {
                webVM.goBack()
            }
            // → Forward
            navBtn("chevron.right", dim: !isInBrowser || !webVM.canGoForward) {
                webVM.goForward()
            }

            // URL / Search field (flexible)
            urlField
                .padding(.horizontal, 4)

            // ↺ Reload / ✕ Stop — shown in browser only
            if isInBrowser {
                if webVM.isLoading {
                    navBtn("xmark", dim: false) { webVM.stop() }
                } else {
                    navBtn("arrow.clockwise", dim: false) { webVM.reload() }
                }

                // 🏠 Menu: home + bookmark actions
                Menu {
                    Button { goHome() } label: {
                        Label("Accueil", systemImage: "house")
                    }
                    Divider()
                    Button { handleBookmarkTap() } label: {
                        Label(isSiteFavorite ? "Retirer des favoris" : "Favori Accueil",
                              systemImage: isSiteFavorite ? "bookmark.slash" : "star")
                    }
                    Button { showBMSheet = true } label: {
                        Label("Marque-page Librairie", systemImage: "books.vertical")
                    }
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 32, height: 32)
                }
            }

            // 📚 Library
            navBtn("books.vertical.fill", dim: false) { showLibrary = true }

            // ⚙️ Settings
            navBtn("gear", dim: false) { showSettings = true }

            // ≡ Collapse
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    navExpanded = false
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: geo.size.width - 24, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.28)))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
    }

    // MARK: - URL / Search field

    private var urlField: some View {
        Group {
            if isEditingURL {
                TextField("URL ou recherche…", text: $urlBarText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .tint(kGreen)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { submitURL() }
            } else {
                Button(action: {
                    urlBarText = isInBrowser ? webVM.urlString : ""
                    isEditingURL = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
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
        .padding(.horizontal, 8).padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(isEditingURL ? kGreen.opacity(0.45) : Color.clear, lineWidth: 1))
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
            }
            .shadow(color: kGreen.opacity(0.2), radius: 8, y: 3)
            .shadow(color: .black.opacity(0.35), radius: 4)
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
    private func navBtn(_ icon: String, dim: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(dim ? 0.2 : 0.75))
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
            showBMChoice = true
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
            engine: settingsVM.translationSettings.engine,
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
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white.opacity(0.1))
                                    .overlay(Capsule()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                            )
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

#Preview { ContentView() }
