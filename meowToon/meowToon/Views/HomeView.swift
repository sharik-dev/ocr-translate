import SwiftUI

private let hBG     = Color(white: 0.07)
private let hCard   = Color(white: 0.11)
private let hBorder = Color.white.opacity(0.08)
private let hText   = Color.white.opacity(0.82)
private let hSub    = Color.white.opacity(0.38)
private let hAccent = Color(red: 0.0, green: 0.835, blue: 0.392)

enum WebtoonSort: String, CaseIterable {
    case nameAZ  = "A → Z"
    case nameZA  = "Z → A"
    case recent  = "Récent"
}

struct HomeContent: View {
    @EnvironmentObject var settingsVM:     SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigator:      AppNavigator

    @State private var showingAddFavorite  = false
    @State private var webtoonDetail:      WebtoonDetailItem? = nil
    @State private var selectedCategoryID: UUID?              = nil   // nil = Tous
    @State private var sortOrder:          WebtoonSort        = .nameAZ
    @State private var showSortMenu        = false

    private struct WebtoonDetailItem: Identifiable {
        let id = UUID()
        let webtoon:    LibraryWebtoon
        let categoryID: UUID
    }

    // Webtoons filtrés + triés
    private var filteredWebtoons: [(webtoon: LibraryWebtoon, categoryID: UUID)] {
        let all: [(webtoon: LibraryWebtoon, categoryID: UUID)]
        if let catID = selectedCategoryID {
            all = libraryManager.categories
                .filter { $0.id == catID }
                .flatMap { cat in cat.webtoons.map { ($0, cat.id) } }
        } else {
            all = libraryManager.categories
                .flatMap { cat in cat.webtoons.map { ($0, cat.id) } }
        }
        switch sortOrder {
        case .nameAZ:  return all.sorted { $0.webtoon.name < $1.webtoon.name }
        case .nameZA:  return all.sorted { $0.webtoon.name > $1.webtoon.name }
        case .recent:  return all.sorted {
            ($0.webtoon.bookmarks.first?.savedAt ?? .distantPast) >
            ($1.webtoon.bookmarks.first?.savedAt ?? .distantPast)
        }
        }
    }

    var body: some View {
        GeometryReader { geo in
        ZStack {
            hBG.ignoresSafeArea()

            // Halo décoratif
            VStack {
                Ellipse()
                    .fill(RadialGradient(
                        colors: [hAccent.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: 220
                    ))
                    .frame(width: 420, height: 280)
                    .offset(x: 60, y: -60)
                    .blur(radius: 30)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("meowToon")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(hText)
                                .shadow(color: .white.opacity(0.35), radius: 8)
                                .shadow(color: .white.opacity(0.15), radius: 20)
                            Text("Votre espace webtoon")
                                .font(.system(size: 13))
                                .foregroundColor(hSub)
                        }
                        Spacer()
                        Text("✦")
                            .font(.system(size: 22))
                            .foregroundColor(hAccent.opacity(0.35))
                            .shadow(color: hAccent.opacity(0.2), radius: 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                    // Ligne décorative
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.12), hAccent.opacity(0.08), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 26)

                    // ── Accès rapide (sites) ───────────────────────────────
                    siteSection
                        .padding(.bottom, 32)

                    // ── Séparateur ────────────────────────────────────────
                    HStack(spacing: 8) {
                        Rectangle().fill(hBorder).frame(height: 1)
                        Text("·").foregroundColor(hAccent.opacity(0.25)).font(.system(size: 12))
                        Rectangle().fill(hBorder).frame(height: 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // ── Webtoons ──────────────────────────────────────────
                    webtoonSection(width: geo.size.width)
                        .padding(.bottom, 110)
                }
            }
        }
        } // GeometryReader
        .sheet(isPresented: $showingAddFavorite) {
            FavoriteSiteFormView()
                .environmentObject(settingsVM)
                .environmentObject(libraryManager)
        }
        .sheet(item: $webtoonDetail) { item in
            NavigationStack {
                WebtoonDetailView(categoryID: item.categoryID, webtoon: item.webtoon)
                    .environmentObject(libraryManager)
                    .environmentObject(navigator)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Accès rapide

    @ViewBuilder
    private var siteSection: some View {
        let sites = settingsVM.favorites.filter { $0.type == .site }
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "ACCÈS RAPIDE") {
                Button(action: { showingAddFavorite = true }) {
                    Text("Ajouter")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .shadow(color: .white.opacity(0.3), radius: 5)
                }
            }

            if sites.isEmpty {
                emptyState(
                    icon: "star",
                    message: "Ajoutez vos sites favoris\npour un accès rapide.",
                    action: { showingAddFavorite = true },
                    actionLabel: "Ajouter un site"
                )
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(sites) { fav in
                            Button { navigator.navigate(to: fav.urlString) } label: {
                                favoriteTile(fav)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    if let i = settingsVM.favorites.firstIndex(where: { $0.id == fav.id }) {
                                        settingsVM.removeFavorite(at: IndexSet(integer: i))
                                    }
                                } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                        addTileButton
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func favoriteTile(_ fav: FavoriteSite) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(hCard)
                    .overlay(Circle().stroke(hBorder, lineWidth: 1))
                    .frame(width: 60, height: 60)
                FaviconView(urlString: fav.urlString, size: 34)
            }
            .shadow(color: .white.opacity(0.1), radius: 8)
            Text(fav.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .shadow(color: .white.opacity(0.2), radius: 5)
                .lineLimit(1).frame(width: 68)
        }
    }

    private var addTileButton: some View {
        Button(action: { showingAddFavorite = true }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundColor(.white.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Text("+")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white.opacity(0.35))
                        .shadow(color: .white.opacity(0.25), radius: 5)
                }
                Text("Ajouter")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1).frame(width: 68)
            }
        }
    }

    // MARK: - Webtoons

    @ViewBuilder
    private func webtoonSection(width: CGFloat) -> some View {
        let colCount = width > 600 ? 3 : 2
        let spacing: CGFloat = 12
        let cardW = (width - 32 - spacing * CGFloat(colCount - 1)) / CGFloat(colCount)
        let columns = Array(repeating: GridItem(.fixed(cardW), spacing: spacing), count: colCount)

        VStack(alignment: .leading, spacing: 0) {

            // Header : titre + bouton tri
            HStack {
                Text("MES WEBTOONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.28))
                    .tracking(1.6)
                Spacer()
                // Bouton tri
                Menu {
                    ForEach(WebtoonSort.allCases, id: \.self) { s in
                        Button(action: { sortOrder = s }) {
                            HStack {
                                Text(s.rawValue)
                                if sortOrder == s { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .medium))
                        Text(sortOrder.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .shadow(color: .white.opacity(0.25), radius: 5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Filtres catégorie
            if !libraryManager.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(id: nil, label: "Tous")
                        ForEach(libraryManager.categories) { cat in
                            categoryChip(id: cat.id, label: "\(cat.emoji) \(cat.name)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
            }

            // Grille
            if filteredWebtoons.isEmpty {
                emptyState(
                    icon: "books.vertical",
                    message: libraryManager.categories.isEmpty
                        ? "Ajoutez votre premier webtoon."
                        : "Aucun webtoon dans cette catégorie.",
                    action: { showingAddFavorite = true },
                    actionLabel: "Ajouter un webtoon"
                )
                .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filteredWebtoons, id: \.webtoon.id) { item in
                        WebtoonCard(
                            webtoon:    item.webtoon,
                            categoryID: item.categoryID,
                            onOpenURL:  { url in navigator.navigate(to: url) },
                            onShowDetail: {
                                webtoonDetail = WebtoonDetailItem(
                                    webtoon: item.webtoon, categoryID: item.categoryID)
                            },
                            onDelete: {
                                libraryManager.removeWebtoon(id: item.webtoon.id, from: item.categoryID)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedCategoryID)
                .animation(.easeInOut(duration: 0.2), value: sortOrder)
            }
        }
    }

    private func categoryChip(id: UUID?, label: String) -> some View {
        let isSelected = selectedCategoryID == id
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategoryID = id
            }
        }) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                .shadow(color: isSelected ? .white.opacity(0.5) : .clear, radius: 6)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.12) : hCard)
                        .overlay(Capsule().stroke(
                            isSelected ? .white.opacity(0.3) : hBorder,
                            lineWidth: isSelected ? 1 : 0.8
                        ))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader<T: View>(title: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.28))
                .tracking(1.6)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
    }

    private func emptyState(icon: String, message: String, action: @escaping () -> Void, actionLabel: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.white.opacity(0.4))
                .shadow(color: .white.opacity(0.4), radius: 8)
                .shadow(color: .white.opacity(0.18), radius: 20)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(hSub)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(actionLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .shadow(color: .white.opacity(0.35), radius: 6)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(hCard)
                        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(hCard)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(hBorder, lineWidth: 1))
        )
    }
}

// MARK: - WebtoonCard

private struct WebtoonCard: View {
    let webtoon:      LibraryWebtoon
    let categoryID:   UUID
    let onOpenURL:    (String) -> Void
    let onShowDetail: () -> Void
    let onDelete:     () -> Void

    private var coverGradient: LinearGradient {
        let raw = webtoon.name.unicodeScalars.reduce(0) { $0 &+ $1.value }
        let hue = Double(raw % 256) / 255.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.2, brightness: 0.22),
                Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1.0), saturation: 0.15, brightness: 0.16)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var lastRead: String? {
        guard let bm = webtoon.bookmarks.first else { return nil }
        return bm.note.isEmpty ? bm.title : bm.note
    }

    var body: some View {
        Button(action: {
            guard !webtoon.siteURL.isEmpty else { onShowDetail(); return }
            onOpenURL(webtoon.siteURL)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    coverGradient
                    FaviconView(urlString: webtoon.siteURL, size: 38).opacity(0.75)
                }
                .frame(maxWidth: .infinity).frame(height: 100).clipped()

                VStack(alignment: .leading, spacing: 3) {
                    Text(webtoon.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(hText)
                        .shadow(color: .white.opacity(0.3), radius: 5)
                        .shadow(color: .white.opacity(0.12), radius: 12)
                        .lineLimit(2)
                    if let last = lastRead {
                        Text(last)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(hAccent.opacity(0.55))
                            .lineLimit(1)
                    } else {
                        Text("Aucun marque-page")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
            }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(hCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(hBorder, lineWidth: 0.8))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
        .contextMenu {
            if !webtoon.siteURL.isEmpty {
                Button { onOpenURL(webtoon.siteURL) } label: { Label("Ouvrir", systemImage: "globe") }
            }
            if let bm = webtoon.bookmarks.first {
                Button { onOpenURL(bm.url) } label: { Label("Reprendre", systemImage: "play.fill") }
            }
            Button { onShowDetail() } label: { Label("Marque-pages", systemImage: "bookmark") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Supprimer", systemImage: "trash") }
        }
    }
}

#Preview {
    HomeContent()
        .environmentObject(SettingsViewModel())
        .environmentObject(LibraryManager())
        .environmentObject(AppNavigator())
}
