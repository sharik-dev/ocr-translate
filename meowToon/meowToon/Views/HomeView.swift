import SwiftUI

private let hBG     = Color(white: 0.07)
private let hCard   = Color(white: 0.12)
private let hBorder = Color.white.opacity(0.08)
private let hText   = Color.white.opacity(0.88)
private let hSub    = Color.white.opacity(0.38)
private let hAccent = Color.white.opacity(0.55)

// MARK: - Group model

private struct FavoriteGroup: Identifiable {
    let host: String       // normalized host (no www.)
    let favorites: [FavoriteSite]
    var id: String { host.isEmpty ? UUID().uuidString : host }
    /// Most recent first (we assume favorites are appended in chronological order)
    var sortedFavorites: [FavoriteSite] { favorites.reversed() }
    /// URL string used to fetch a representative favicon
    var representativeURL: String { favorites.first?.urlString ?? "" }
}

private func normalizedHost(_ urlString: String) -> String {
    guard let host = URL(string: urlString)?.host?.lowercased() else { return urlString }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
}

// MARK: - HomeContent

struct HomeContent: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var navigator:  AppNavigator

    @State private var showingAdd: Bool = false
    @State private var openedGroup: FavoriteGroup? = nil

    private var sites: [FavoriteSite] {
        settingsVM.favorites.filter { $0.type == .site }
    }

    private var groups: [FavoriteGroup] {
        let dict = Dictionary(grouping: sites) { normalizedHost($0.urlString) }
        return dict.map { FavoriteGroup(host: $0.key, favorites: $0.value) }
            // Sites with more favorites first, then alpha
            .sorted {
                if $0.favorites.count != $1.favorites.count {
                    return $0.favorites.count > $1.favorites.count
                }
                return $0.host < $1.host
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
                            Text("Votre navigateur")
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

                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.1), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1).padding(.horizontal, 20).padding(.bottom, 22)

                    // ── Favoris ───────────────────────────────────────────
                    favoritesSection
                        .padding(.bottom, 120)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            FavoriteSiteFormView()
                .environmentObject(settingsVM)
        }
        .sheet(item: $openedGroup) { group in
            FavoriteGroupDetailView(group: group) { fav in
                navigator.navigate(to: fav.urlString)
                openedGroup = nil
            } onDelete: { fav in
                if let i = settingsVM.favorites.firstIndex(where: { $0.id == fav.id }) {
                    settingsVM.removeFavorite(at: IndexSet(integer: i))
                }
            }
            .environmentObject(settingsVM)
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Favorites grid

    @ViewBuilder
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("FAVORIS")
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

            if groups.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(.white.opacity(0.25))
                    Text("Aucun favori pour l'instant.\nAppuyez sur 🔖 pendant la navigation.")
                        .font(.system(size: 13))
                        .foregroundColor(hSub)
                        .multilineTextAlignment(.center)
                    Button { showingAdd = true } label: {
                        Text("Ajouter manuellement")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(hCard)
                                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
                .padding(.horizontal, 20)
            } else {
                let cols = [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(groups) { group in
                        if group.favorites.count > 1 {
                            // Folder card — multiple bookmarks for this site
                            FolderCard(group: group) {
                                openedGroup = group
                            } onDeleteAll: {
                                let ids = Set(group.favorites.map(\.id))
                                let indexes = IndexSet(
                                    settingsVM.favorites.enumerated()
                                        .filter { ids.contains($0.element.id) }
                                        .map(\.offset)
                                )
                                settingsVM.removeFavorite(at: indexes)
                            }
                        } else if let fav = group.favorites.first {
                            // Single card — single bookmark
                            FavoriteCard(fav: fav) {
                                navigator.navigate(to: fav.urlString)
                            } onDelete: {
                                if let i = settingsVM.favorites.firstIndex(where: { $0.id == fav.id }) {
                                    settingsVM.removeFavorite(at: IndexSet(integer: i))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: groups.count)
            }
        }
    }
}

// MARK: - FavoriteCard (single)

private struct FavoriteCard: View {
    let fav:      FavoriteSite
    let onOpen:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if let data = fav.thumbnailData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        let h = Double(fav.name.unicodeScalars.reduce(0) { $0 &+ $1.value } % 256) / 255.0
                        LinearGradient(colors: [
                            Color(hue: h, saturation: 0.35, brightness: 0.28),
                            Color(hue: (h + 0.15).truncatingRemainder(dividingBy: 1),
                                  saturation: 0.28, brightness: 0.18)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)

                        FaviconView(urlString: fav.urlString, size: 32)
                            .opacity(0.75)
                    }

                    LinearGradient(colors: [.clear, .black.opacity(0.5)],
                                   startPoint: .center, endPoint: .bottom)

                    VStack {
                        Spacer()
                        HStack {
                            FaviconView(urlString: fav.urlString, size: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 2, contentMode: .fit)
                .clipped()

                VStack(alignment: .leading, spacing: 2) {
                    Text(fav.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(hText)
                        .lineLimit(1)
                    if let host = URL(string: fav.urlString)?.host {
                        Text(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("favoriteCard")
        .background(RoundedRectangle(cornerRadius: 12).fill(hCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(hBorder, lineWidth: 0.8)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
        .contextMenu {
            Button(action: onOpen) { Label("Ouvrir", systemImage: "globe") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Supprimer", systemImage: "trash") }
        }
    }
}

// MARK: - FolderCard (multiple bookmarks from same site)

private struct FolderCard: View {
    let group:        FavoriteGroup
    let onOpen:       () -> Void
    let onDeleteAll:  () -> Void

    private var topThumb: Data? { group.sortedFavorites.first?.thumbnailData }
    private var midThumb: Data? { group.sortedFavorites.dropFirst().first?.thumbnailData ?? topThumb }
    private var botThumb: Data? { group.sortedFavorites.dropFirst(2).first?.thumbnailData ?? midThumb }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Stacked thumbnails ──────────────────────────────────
                ZStack {
                    // Card 3 (back) — offset & rotated slightly
                    stackedThumb(data: botThumb, xOffset: 6, yOffset: -3, rotation: 4, opacity: 0.5)
                    // Card 2 (middle)
                    stackedThumb(data: midThumb, xOffset: -4, yOffset: -2, rotation: -3, opacity: 0.75)
                    // Card 1 (front)
                    stackedThumb(data: topThumb, xOffset: 0, yOffset: 0, rotation: 0, opacity: 1.0)

                    // Bottom-left favicon badge
                    VStack {
                        Spacer()
                        HStack {
                            FaviconView(urlString: group.representativeURL, size: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                            Spacer()
                        }
                    }

                    // Count badge (top-right)
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "square.stack.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(group.favorites.count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                            )
                            .padding(6)
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 2, contentMode: .fit)
                .clipped()
                .padding(.top, 4)

                // Site name + count
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.host)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(hText)
                        .lineLimit(1)
                    Text("\(group.favorites.count) favoris")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 12).fill(hCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(hBorder, lineWidth: 0.8)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .contextMenu {
            Button(action: onOpen) { Label("Ouvrir les favoris", systemImage: "square.stack") }
            Divider()
            Button(role: .destructive, action: onDeleteAll) {
                Label("Tout supprimer", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func stackedThumb(data: Data?,
                              xOffset: CGFloat,
                              yOffset: CGFloat,
                              rotation: Double,
                              opacity: Double) -> some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.08)
                if let data, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    let h = Double(group.host.unicodeScalars.reduce(0) { $0 &+ $1.value } % 256) / 255.0
                    LinearGradient(colors: [
                        Color(hue: h, saturation: 0.35, brightness: 0.28),
                        Color(hue: (h + 0.15).truncatingRemainder(dividingBy: 1),
                              saturation: 0.28, brightness: 0.18)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.4)],
                               startPoint: .center, endPoint: .bottom)
            }
            .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.92)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.15), lineWidth: 0.8)
            )
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .opacity(opacity)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - FavoriteGroupDetailView (sheet — list of all favorites for a domain)

private struct FavoriteGroupDetailView: View {
    let group:     FavoriteGroup
    let onOpen:    (FavoriteSite) -> Void
    let onDelete:  (FavoriteSite) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.opacity(0.4).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // Header
                        HStack(spacing: 10) {
                            FaviconView(urlString: group.representativeURL, size: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.host)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("\(group.favorites.count) favori\(group.favorites.count > 1 ? "s" : "")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        // Favorites
                        ForEach(group.sortedFavorites) { fav in
                            FavoriteRow(fav: fav, onTap: { onOpen(fav) }, onDelete: { onDelete(fav) })
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct FavoriteRow: View {
    let fav:      FavoriteSite
    let onTap:    () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Color(white: 0.10)
                    if let data = fav.thumbnailData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        FaviconView(urlString: fav.urlString, size: 22).opacity(0.6)
                    }
                }
                .frame(width: 80, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 0.6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(fav.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(fav.urlString)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 0.8))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(action: onTap) { Label("Ouvrir", systemImage: "globe") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Supprimer", systemImage: "trash") }
        }
    }
}

#Preview {
    HomeContent()
        .environmentObject(SettingsViewModel())
        .environmentObject(AppNavigator())
}
