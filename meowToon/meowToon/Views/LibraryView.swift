import SwiftUI


// MARK: - Root library view (categories)

struct LibraryView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showAddCategory  = false
    @State private var newCategoryName  = ""
    @State private var newCategoryEmoji = "📂"
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.ignoresSafeArea()

                if libraryManager.categories.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .navigationTitle("Librairie")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchQuery, prompt: "Rechercher…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddCategory = true } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.white.opacity(0.75))
                            .shadow(color: .white.opacity(0.5), radius: 5)
                    }
                }
            }
            .alert("Nouvelle catégorie", isPresented: $showAddCategory) {
                TextField("Nom", text: $newCategoryName)
                TextField("Emoji", text: $newCategoryEmoji)
                Button("Créer") {
                    let emoji = newCategoryEmoji.isEmpty ? "📂" : newCategoryEmoji
                    libraryManager.addCategory(name: newCategoryName, emoji: emoji)
                    newCategoryName = ""; newCategoryEmoji = "📂"
                }
                .disabled(newCategoryName.isEmpty)
                Button("Annuler", role: .cancel) {}
            } message: { Text("Donnez un nom et un emoji à votre catégorie.") }
        }
    }

    // MARK: - Category list

    private var categoryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredCategories) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        categoryRow(category)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            if let i = libraryManager.categories.firstIndex(where: { $0.id == category.id }) {
                                libraryManager.removeCategory(at: IndexSet(integer: i))
                            }
                        } label: { Label("Supprimer", systemImage: "trash") }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private var filteredCategories: [LibraryCategory] {
        guard !searchQuery.isEmpty else { return libraryManager.categories }
        return libraryManager.categories.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.webtoons.contains { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    private func categoryRow(_ cat: LibraryCategory) -> some View {
        HStack(spacing: 14) {
            Text(cat.emoji).font(.system(size: 30)).frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(cat.name)
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text("\(cat.webtoons.count) webtoon\(cat.webtoons.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.22))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 22) {
            Text("📚").font(.system(size: 56))
                .shadow(color: .white.opacity(0.2), radius: 8)
            VStack(spacing: 8) {
                Text("Librairie vide").font(.title2.bold()).foregroundColor(.white)
                Text("Créez une catégorie pour organiser\nvos webtoons et marque-pages.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            Button { showAddCategory = true } label: {
                Label("Créer une catégorie", systemImage: "folder.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .white.opacity(0.4), radius: 5)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                    )
                    .shadow(color: .white.opacity(0.1), radius: 10)
            }
        }
    }
}

// MARK: - Category detail (webtoons list)

struct CategoryDetailView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    let category: LibraryCategory

    @State private var showAddWebtoon  = false
    @State private var newWebtoonName  = ""
    @State private var newWebtoonURL   = ""

    private var liveCategory: LibraryCategory? {
        libraryManager.categories.first { $0.id == category.id }
    }

    var body: some View {
        ZStack {
            kDarkBG.ignoresSafeArea()

            if let cat = liveCategory, !cat.webtoons.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(cat.webtoons) { webtoon in
                            NavigationLink(destination: WebtoonDetailView(
                                categoryID: cat.id, webtoon: webtoon)) {
                                webtoonRow(webtoon)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    libraryManager.removeWebtoon(id: webtoon.id, from: cat.id)
                                } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 14) {
                    Text("Aucun webtoon").font(.headline).foregroundColor(.white)
                    Text("Ajoutez des webtoons à cette catégorie.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .navigationTitle("\(liveCategory?.emoji ?? "") \(liveCategory?.name ?? category.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddWebtoon = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white.opacity(0.75))
                        .shadow(color: .white.opacity(0.5), radius: 5)
                }
            }
        }
        .alert("Nouveau webtoon", isPresented: $showAddWebtoon) {
            TextField("Titre", text: $newWebtoonName)
            TextField("URL du site (optionnel)", text: $newWebtoonURL)
            Button("Ajouter") {
                libraryManager.addWebtoon(name: newWebtoonName, siteURL: newWebtoonURL, to: category.id)
                newWebtoonName = ""; newWebtoonURL = ""
            }
            .disabled(newWebtoonName.isEmpty)
            Button("Annuler", role: .cancel) {}
        }
    }

    private func webtoonRow(_ w: LibraryWebtoon) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                Image(systemName: w.iconName)
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.8))
                    .shadow(color: .white.opacity(0.5), radius: 4)
            }
            .shadow(color: .black.opacity(0.3), radius: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(w.name)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text("\(w.bookmarks.count) marque-page\(w.bookmarks.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.22))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
    }
}

// MARK: - Webtoon detail (bookmarks, newest first)

struct WebtoonDetailView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigator:      AppNavigator
    @Environment(\.dismiss) private var dismiss
    let categoryID: UUID
    let webtoon:    LibraryWebtoon

    private var liveWebtoon: LibraryWebtoon? {
        libraryManager.categories
            .first(where: { $0.id == categoryID })?
            .webtoons.first(where: { $0.id == webtoon.id })
    }

    var body: some View {
        ZStack {
            kDarkBG.ignoresSafeArea()

            if let w = liveWebtoon, !w.bookmarks.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(w.bookmarks) { bm in
                            Button {
                                navigator.navigate(to: bm.url)
                                dismiss()
                            } label: {
                                bookmarkRow(bm)
                            }
                            .contextMenu {
                                Button {
                                    navigator.navigate(to: bm.url)
                                    dismiss()
                                } label: { Label("Ouvrir", systemImage: "safari") }
                                Button(role: .destructive) {
                                    libraryManager.removeBookmark(
                                        id: bm.id, from: webtoon.id, in: categoryID)
                                } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Aucun marque-page").font(.headline).foregroundColor(.white)
                    Text("Sauvegardez des pages depuis le navigateur.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }
            }
        }
        .navigationTitle(liveWebtoon?.name ?? webtoon.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private func bookmarkRow(_ bm: WebBookmark) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .white.opacity(0.5), radius: 4)
                .font(.system(size: 16))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(bm.title.isEmpty ? bm.url : bm.title)
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if !bm.note.isEmpty {
                        Text(bm.note)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    Text(bm.relativeDate)
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.2))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

