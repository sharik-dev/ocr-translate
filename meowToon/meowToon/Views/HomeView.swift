import SwiftUI

private let kGreen  = Color(red: 0.12, green: 0.92, blue: 0.45)
private let kDarkBG = Color(red: 0.02, green: 0.06, blue: 0.02)

/// Home content — favorites grid only.
/// Navigation (search, browser) is handled by ContentView's persistent nav bar.
struct HomeContent: View {
    @EnvironmentObject var settingsVM:    SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigator:     AppNavigator
    @State private var showingAddFavorite = false

    private var siteFavorites: [FavoriteSite] {
        settingsVM.favorites.filter { $0.type == .site }
    }

    var body: some View {
        ZStack {
            kDarkBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Title
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("meowToon")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.white, kGreen.opacity(0.8)],
                                                   startPoint: .leading, endPoint: .trailing))
                            Text("Accès rapide à vos sites")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Favorites grid
                    favoritesSection
                }
                .padding(.bottom, 80) // room for persistent nav bar
            }
        }
        .sheet(isPresented: $showingAddFavorite) {
            FavoriteSiteFormView()
                .environmentObject(settingsVM)
                .environmentObject(libraryManager)
        }
    }

    // MARK: - Favorites grid

    @ViewBuilder
    private var favoritesSection: some View {
        if siteFavorites.isEmpty {
            VStack(spacing: 16) {
                addTileButton
                Text("Ajoutez vos premiers favoris\npour accéder rapidement à vos sites.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("ACCÈS RAPIDE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 16)], spacing: 20) {
                    ForEach(siteFavorites) { fav in
                        Button { navigator.navigate(to: fav.urlString) } label: {
                            favoriteTile(fav)
                        }
                    }
                    addTileButton
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func favoriteTile(_ fav: FavoriteSite) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(LinearGradient(
                        colors: [kGreen.opacity(0.28), Color.green.opacity(0.18)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .frame(width: 62, height: 62)
                FaviconView(urlString: fav.urlString, size: 36)
            }
            .shadow(color: kGreen.opacity(0.2), radius: 8)

            Text(fav.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var addTileButton: some View {
        Button(action: { showingAddFavorite = true }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(kGreen.opacity(0.4), lineWidth: 1))
                        .frame(width: 62, height: 62)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(kGreen)
                }
                .shadow(color: kGreen.opacity(0.15), radius: 6)

                Text("Ajouter")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(kGreen.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    HomeContent()
        .environmentObject(SettingsViewModel())
        .environmentObject(LibraryManager())
        .environmentObject(AppNavigator())
}
