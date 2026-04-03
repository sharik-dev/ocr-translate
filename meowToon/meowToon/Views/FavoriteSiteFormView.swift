import SwiftUI

struct FavoriteSiteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM:     SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager

    @State private var favoriteType:      FavoriteType = .webtoon
    @State private var urlString:         String = ""
    @State private var name:              String = ""
    @State private var nameWasAutoFilled: Bool   = false

    private var isValid: Bool {
        let u = urlString.trimmingCharacters(in: .whitespaces)
        let n = name.trimmingCharacters(in: .whitespaces)
        return !u.isEmpty && !n.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // ── Type Site / Webtoon ──────────────────────────────
                        Picker("", selection: $favoriteType) {
                            Text("Accès rapide").tag(FavoriteType.site)
                            Text("Webtoon").tag(FavoriteType.webtoon)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: favoriteType) { _, _ in }

                        // ── URL ─────────────────────────────────────────────
                        inputSection(label: "LIEN") {
                            TextField("https://…", text: $urlString)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .tint(kGreen)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        .onChange(of: urlString) { _, newURL in
                            if nameWasAutoFilled || name.isEmpty {
                                let extracted = extractTitle(from: newURL)
                                if !extracted.isEmpty {
                                    name             = extracted
                                    nameWasAutoFilled = true
                                }
                            }
                        }

                        // ── Nom ─────────────────────────────────────────────
                        inputSection(label: "NOM") {
                            TextField("Nom affiché", text: $name)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .tint(kGreen)
                                .onChange(of: name) { _, _ in nameWasAutoFilled = false }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                        }

                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .navigationTitle(favoriteType == .site ? "Accès rapide" : "Ajouter un webtoon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.white.opacity(0.55))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!isValid)
                        .foregroundStyle(isValid
                            ? LinearGradient(colors: [kGreen, kGreen.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers UI

    private func inputSection<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.38))
                .tracking(1.0)
                .padding(.horizontal, 4)
            content()
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.025)))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
    }

    // MARK: - Logic

    private func extractTitle(from rawURL: String) -> String {
        var urlStr = rawURL.trimmingCharacters(in: .whitespaces)
        if !urlStr.hasPrefix("http") { urlStr = "https://" + urlStr }
        guard let url = URL(string: urlStr) else { return "" }
        let paths = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        for comp in paths.reversed() {
            let noExt   = (comp.components(separatedBy: "?").first ?? comp).components(separatedBy: ".").first ?? comp
            let cleaned = noExt.replacingOccurrences(of: "-", with: " ")
                               .replacingOccurrences(of: "_", with: " ")
                               .trimmingCharacters(in: .whitespaces)
            let isNumeric = cleaned.split(separator: " ").allSatisfy { $0.allSatisfy(\.isNumber) }
            if cleaned.count > 2 && !isNumeric {
                return cleaned.split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                    .joined(separator: " ")
            }
        }
        if let host = url.host?.lowercased() {
            let stripped = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            let part = stripped.components(separatedBy: ".").first ?? stripped
            return part.prefix(1).uppercased() + part.dropFirst()
        }
        return ""
    }

    private func save() {
        var url = urlString.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") { url = "https://" + url }
        let trimName = name.trimmingCharacters(in: .whitespaces)

        switch favoriteType {
        case .site:
            settingsVM.addFavorite(FavoriteSite(name: trimName, urlString: url, type: .site))
        case .webtoon:
            libraryManager.quickAddWebtoon(name: trimName, siteURL: url)
        }
        dismiss()
    }
}

#Preview {
    FavoriteSiteFormView()
        .environmentObject(SettingsViewModel())
        .environmentObject(LibraryManager())
}
