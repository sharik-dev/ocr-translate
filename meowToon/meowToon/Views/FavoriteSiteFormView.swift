import SwiftUI

private let kGreen  = Color(red: 0.12, green: 0.92, blue: 0.45)
private let kDarkBG = Color(red: 0.02, green: 0.06, blue: 0.02)

struct FavoriteSiteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM:    SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager

    @State private var name:           String = ""
    @State private var urlString:      String = ""
    @State private var iconSystemName: String = "globe"
    @State private var favoriteType:   FavoriteType = .site

    let availableIcons = [
        "globe", "book", "books.vertical", "rectangle.stack",
        "star", "heart", "newspaper", "link", "safari",
        "play.circle", "gamecontroller", "music.note", "photo", "tv"
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !urlString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Type picker
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("TYPE")
                            glassCard {
                                HStack(spacing: 0) {
                                    ForEach(FavoriteType.allCases, id: \.self) { t in
                                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { favoriteType = t } }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: t.icon)
                                                    .font(.system(size: 14))
                                                Text(t == .site ? "Site (Accueil)" : "Webtoon (Librairie)")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundColor(favoriteType == t ? .black : .white.opacity(0.5))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 11)
                                            .background(
                                                favoriteType == t
                                                    ? LinearGradient(colors: [kGreen, .cyan], startPoint: .leading, endPoint: .trailing)
                                                    : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing)
                                            )
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        // Name & URL fields
                        glassCard {
                            VStack(spacing: 0) {
                                fieldRow(placeholder: "Nom",                 text: $name,      icon: "tag",  keyboard: .default)
                                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)
                                fieldRow(placeholder: "https://example.com", text: $urlString, icon: "link", keyboard: .URL)
                            }
                        }

                        // Icon picker — only for Site type
                        if favoriteType == .site {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionHeader("ICÔNE")
                                glassCard {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                                        ForEach(availableIcons, id: \.self) { icon in
                                            Button(action: { iconSystemName = icon }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(iconSystemName == icon
                                                              ? LinearGradient(colors: [kGreen.opacity(0.55), Color.green.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                              : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                        .overlay(Circle().stroke(
                                                            iconSystemName == icon ? kGreen.opacity(0.6) : Color.white.opacity(0.08),
                                                            lineWidth: 1))
                                                        .frame(width: 50, height: 50)
                                                    Image(systemName: icon)
                                                        .font(.system(size: 20, weight: .medium))
                                                        .foregroundColor(iconSystemName == icon ? .white : .white.opacity(0.5))
                                                }
                                                .shadow(color: iconSystemName == icon ? kGreen.opacity(0.45) : .clear, radius: 10)
                                                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: iconSystemName)
                                            }
                                        }
                                    }
                                    .padding(16)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .navigationTitle(favoriteType == .site ? "Nouveau favori" : "Nouveau webtoon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.white.opacity(0.55))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!isValid)
                        .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .leading, endPoint: .trailing))
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Save

    private func save() {
        let trimName = name.trimmingCharacters(in: .whitespaces)
        var url = urlString.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") { url = "https://" + url }

        switch favoriteType {
        case .site:
            settingsVM.addFavorite(FavoriteSite(
                name: trimName, urlString: url,
                iconSystemName: iconSystemName, type: .site))
        case .webtoon:
            libraryManager.quickAddWebtoon(name: trimName, siteURL: url)
        }
        dismiss()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.38))
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.025)))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private func fieldRow(placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 24)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .tint(kGreen)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

#Preview {
    FavoriteSiteFormView()
        .environmentObject(SettingsViewModel())
        .environmentObject(LibraryManager())
}
