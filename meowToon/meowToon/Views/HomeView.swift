import SwiftUI

private let hBG     = Color(white: 0.07)
private let hCard   = Color(white: 0.12)
private let hBorder = Color.white.opacity(0.08)
private let hText   = Color.white.opacity(0.88)
private let hSub    = Color.white.opacity(0.38)
private let hAccent = Color.white.opacity(0.55)

enum WebtoonSort: String, CaseIterable {
    case nameAZ = "A → Z"
    case nameZA = "Z → A"
    case recent = "Récent"
}

struct HomeContent: View {
    @EnvironmentObject var settingsVM:     SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigator:      AppNavigator

    @State private var showingAdd          = false
    @State private var webtoonDetail:      WebtoonDetailItem? = nil
    @State private var selectedCategoryID: UUID?              = nil
    @State private var sortOrder:          WebtoonSort        = .nameAZ

    private struct WebtoonDetailItem: Identifiable {
        let id = UUID(); let webtoon: LibraryWebtoon; let categoryID: UUID?
    }

    private var filteredWebtoons: [(webtoon: LibraryWebtoon, categoryID: UUID?)] {
        let all: [(webtoon: LibraryWebtoon, categoryID: UUID?)]
        if let id = selectedCategoryID {
            all = libraryManager.categories.filter { $0.id == id }
                .flatMap { c in c.webtoons.map { ($0, Optional(c.id)) } }
        } else {
            let categorized = libraryManager.categories
                .flatMap { c in c.webtoons.map { ($0, Optional(c.id)) } }
            let uncategorized = libraryManager.uncategorizedWebtoons
                .map { ($0, UUID?.none) }
            all = categorized + uncategorized
        }
        switch sortOrder {
        case .nameAZ: return all.sorted { $0.webtoon.name < $1.webtoon.name }
        case .nameZA: return all.sorted { $0.webtoon.name > $1.webtoon.name }
        case .recent: return all.sorted {
            ($0.webtoon.bookmarks.first?.savedAt ?? .distantPast) >
            ($1.webtoon.bookmarks.first?.savedAt ?? .distantPast)
        }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            hBG.ignoresSafeArea()

            // Halo déco
            Ellipse()
                .fill(RadialGradient(colors: [Color.white.opacity(0.04), .clear],
                                     center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 380, height: 240)
                .offset(x: 80, y: -40)
                .blur(radius: 40)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ────────────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("meowToon")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(hText)
                                .shadow(color: .white.opacity(0.3), radius: 8)
                            Text("Votre espace webtoon")
                                .font(.system(size: 13))
                                .foregroundColor(hSub)
                        }
                        Spacer(minLength: 0)
                        Text("✦")
                            .font(.system(size: 20))
                            .foregroundColor(hAccent.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                    // Ligne déco
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.1), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1).padding(.horizontal, 20).padding(.bottom, 22)

                    // ── Accès rapide ──────────────────────────────────────
                    siteSectionView
                        .padding(.bottom, 28)

                    // ── Séparateur ────────────────────────────────────────
                    HStack(spacing: 6) {
                        Rectangle().fill(hBorder).frame(height: 1)
                        Text("·").foregroundColor(hAccent.opacity(0.3)).font(.system(size: 11))
                        Rectangle().fill(hBorder).frame(height: 1)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 22)

                    // ── Webtoons ──────────────────────────────────────────
                    webtoonSectionView
                        .padding(.bottom, 120)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            FavoriteSiteFormView()
                .environmentObject(settingsVM)
                .environmentObject(libraryManager)
        }
        .sheet(item: $webtoonDetail) { item in
            NavigationStack {
                WebtoonDetailView(categoryID: item.categoryID ?? UUID(), webtoon: item.webtoon)
                    .environmentObject(libraryManager)
                    .environmentObject(navigator)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Accès rapide

    @ViewBuilder
    private var siteSectionView: some View {
        let sites = settingsVM.favorites.filter { $0.type == .site }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACCÈS RAPIDE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.28))
                    .tracking(1.5)
                Spacer(minLength: 8)
                Button { showingAdd = true } label: {
                    Text("Ajouter")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(sites) { fav in
                        Button { navigator.navigate(to: fav.urlString) } label: {
                            VStack(spacing: 7) {
                                ZStack {
                                    Circle().fill(hCard)
                                        .overlay(Circle().stroke(hBorder, lineWidth: 1))
                                        .frame(width: 56, height: 56)
                                    FaviconView(urlString: fav.urlString, size: 32)
                                }
                                .shadow(color: .white.opacity(0.08), radius: 6)
                                Text(fav.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                                    .frame(width: 60)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                if let i = settingsVM.favorites.firstIndex(where: { $0.id == fav.id }) {
                                    settingsVM.removeFavorite(at: IndexSet(integer: i))
                                }
                            } label: { Label("Supprimer", systemImage: "trash") }
                        }
                    }
                    // Bouton ajouter
                    Button { showingAdd = true } label: {
                        VStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundColor(.white.opacity(0.16))
                                    .frame(width: 56, height: 56)
                                Text("+").font(.system(size: 20, weight: .light))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            Text("Ajouter").font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.25))
                                .frame(width: 60)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Webtoons

    @ViewBuilder
    private var webtoonSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Titre + tri
            HStack {
                Text("MES WEBTOONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.28))
                    .tracking(1.5)
                Spacer(minLength: 8)
                Menu {
                    ForEach(WebtoonSort.allCases, id: \.self) { s in
                        Button {
                            withAnimation { sortOrder = s }
                        } label: {
                            HStack {
                                Text(s.rawValue)
                                if sortOrder == s { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .medium))
                        Text(sortOrder.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 20)

            // Filtres catégorie (avec suppression)
            if !libraryManager.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(id: nil, label: "Tous", emoji: nil)
                        ForEach(libraryManager.categories) { cat in
                            categoryChip(id: cat.id, label: cat.name, emoji: cat.emoji)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let idx = libraryManager.categories.firstIndex(where: { $0.id == cat.id }) {
                                            if selectedCategoryID == cat.id { selectedCategoryID = nil }
                                            libraryManager.removeCategory(at: IndexSet(integer: idx))
                                        }
                                    } label: { Label("Supprimer la catégorie", systemImage: "trash") }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Grille portrait style Webtoon
            if filteredWebtoons.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                        .shadow(color: .white.opacity(0.3), radius: 8)
                    Text(libraryManager.categories.isEmpty
                         ? "Ajoutez votre premier webtoon."
                         : "Aucun webtoon dans cette catégorie.")
                        .font(.system(size: 13))
                        .foregroundColor(hSub)
                        .multilineTextAlignment(.center)
                    Button { showingAdd = true } label: {
                        Text("Ajouter un webtoon")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .shadow(color: .white.opacity(0.3), radius: 5)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(hCard)
                                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .padding(.horizontal, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(hCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(hBorder, lineWidth: 1)))
                .padding(.horizontal, 20)
            } else {
                // 3 colonnes, covers portrait
                let cols = [GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(filteredWebtoons, id: \.webtoon.id) { item in
                        WebtoonCard(
                            webtoon:    item.webtoon,
                            categoryID: item.categoryID,
                            categories: libraryManager.categories,
                            onOpenURL:  { url in navigator.navigate(to: url) },
                            onShowDetail: {
                                webtoonDetail = WebtoonDetailItem(
                                    webtoon: item.webtoon, categoryID: item.categoryID)
                            },
                            onDelete: {
                                if let catID = item.categoryID {
                                    libraryManager.removeWebtoon(id: item.webtoon.id, from: catID)
                                } else {
                                    libraryManager.removeUncategorizedWebtoon(id: item.webtoon.id)
                                }
                            },
                            onMoveToCategory: { catID in
                                libraryManager.moveWebtoon(id: item.webtoon.id, toCategoryID: catID)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.2), value: selectedCategoryID)
                .animation(.easeInOut(duration: 0.2), value: sortOrder)
            }
        }
    }

    // MARK: - Category chip

    private func categoryChip(id: UUID?, label: String, emoji: String?) -> some View {
        let selected = selectedCategoryID == id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                selectedCategoryID = id
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .white.opacity(0.45))
                .shadow(color: selected ? .white.opacity(0.45) : .clear, radius: 5)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule()
                    .fill(selected ? Color.white.opacity(0.13) : hCard)
                    .overlay(Capsule().stroke(selected ? .white.opacity(0.28) : hBorder,
                                              lineWidth: selected ? 1 : 0.8)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WebtoonCard (portrait Webtoon-app style)

private struct WebtoonCard: View {
    let webtoon:          LibraryWebtoon
    let categoryID:       UUID?
    let categories:       [LibraryCategory]
    let onOpenURL:        (String) -> Void
    let onShowDetail:     () -> Void
    let onDelete:         () -> Void
    let onMoveToCategory: (UUID) -> Void

    private var categoryName: String {
        guard let id = categoryID else { return "" }
        return categories.first(where: { $0.id == id })?.name ?? ""
    }

    private var coverGradient: LinearGradient {
        let raw = webtoon.name.unicodeScalars.reduce(0) { $0 &+ $1.value }
        let h   = Double(raw % 256) / 255.0
        return LinearGradient(colors: [
            Color(hue: h,               saturation: 0.35, brightness: 0.28),
            Color(hue: (h + 0.15).truncatingRemainder(dividingBy: 1), saturation: 0.28, brightness: 0.18)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Button {
            guard !webtoon.siteURL.isEmpty else { onShowDetail(); return }
            onOpenURL(webtoon.siteURL)
        } label: {
            VStack(alignment: .leading, spacing: 0) {

                // Cover portrait
                ZStack(alignment: .bottomLeading) {
                    coverGradient
                    FaviconView(urlString: webtoon.siteURL, size: 34).opacity(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Gradient overlay bas
                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                   startPoint: .center, endPoint: .bottom)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(2/3, contentMode: .fit)
                .clipped()

                // Infos sous la cover
                VStack(alignment: .leading, spacing: 2) {
                    Text(webtoon.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(hText)
                        .lineLimit(2)
                        .shadow(color: .white.opacity(0.2), radius: 4)

                    if !categoryName.isEmpty {
                        Text(categoryName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 10).fill(hCard)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(hBorder, lineWidth: 0.8)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
        .contextMenu {
            if !webtoon.siteURL.isEmpty {
                Button { onOpenURL(webtoon.siteURL) } label: { Label("Ouvrir", systemImage: "globe") }
            }
            if let bm = webtoon.bookmarks.first {
                Button { onOpenURL(bm.url) } label: { Label("Reprendre", systemImage: "play.fill") }
            }
            Button { onShowDetail() } label: { Label("Marque-pages", systemImage: "bookmark") }
            if categoryID == nil && !categories.isEmpty {
                Menu {
                    ForEach(categories) { cat in
                        Button { onMoveToCategory(cat.id) } label: {
                            Text(cat.name)
                        }
                    }
                } label: { Label("Ajouter à une catégorie", systemImage: "folder.badge.plus") }
            }
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
