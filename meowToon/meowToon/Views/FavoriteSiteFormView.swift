import SwiftUI

struct FavoriteSiteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM:     SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager

    @State private var favoriteType:       FavoriteType = .webtoon
    @State private var urlString:          String = ""
    @State private var name:               String = ""
    @State private var selectedCategoryID: UUID?  = nil
    @State private var isCreatingNewCat:   Bool   = false
    @State private var newCategoryName:    String = ""
    @State private var nameWasAutoFilled:  Bool   = false

    private var isValid: Bool {
        let u = urlString.trimmingCharacters(in: .whitespaces)
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty && !n.isEmpty else { return false }
        if favoriteType == .webtoon {
            return selectedCategoryID != nil || isCreatingNewCat
        }
        return true
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
                        .onChange(of: favoriteType) { _, _ in autoSelectCategory() }

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

                        // ── Catégorie (webtoon seulement) ────────────────────
                        if favoriteType == .webtoon { inputSection(label: "CATÉGORIE") {
                            VStack(spacing: 0) {
                                ForEach(libraryManager.categories) { cat in
                                    Button {
                                        selectedCategoryID = cat.id
                                        isCreatingNewCat   = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(cat.emoji).font(.system(size: 18))
                                            Text(cat.name)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                            Spacer()
                                            if selectedCategoryID == cat.id {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(kGreen)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 13)
                                        .background(selectedCategoryID == cat.id ? kGreen.opacity(0.08) : .clear)
                                    }
                                    if cat.id != libraryManager.categories.last?.id {
                                        Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)
                                    }
                                }

                                if !libraryManager.categories.isEmpty {
                                    Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)
                                }

                                // Nouvelle catégorie
                                Button {
                                    isCreatingNewCat   = true
                                    selectedCategoryID = nil
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("Nouvelle catégorie")
                                            .font(.system(size: 15))
                                            .foregroundColor(isCreatingNewCat ? kGreen : .white.opacity(0.55))
                                        Spacer()
                                        if isCreatingNewCat {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(kGreen)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 13)
                                    .background(isCreatingNewCat ? kGreen.opacity(0.08) : .clear)
                                }

                                if isCreatingNewCat {
                                    Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)
                                    TextField("Nom (ex : Seinen, Shonen…)", text: $newCategoryName)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .tint(kGreen)
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                            }
                        } } // end if webtoon + inputSection
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
            .onAppear { autoSelectCategory() }
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

    private func autoSelectCategory() {
        if selectedCategoryID == nil {
            if let first = libraryManager.categories.first {
                selectedCategoryID = first.id
            } else {
                isCreatingNewCat = true
            }
        }
    }

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
            if isCreatingNewCat {
                let catName = newCategoryName.trimmingCharacters(in: .whitespaces)
                libraryManager.addCategory(name: catName.isEmpty ? "Mes webtoons" : catName)
                if let newCat = libraryManager.categories.last {
                    libraryManager.addWebtoon(name: trimName, siteURL: url, to: newCat.id)
                }
            } else if let catID = selectedCategoryID {
                libraryManager.addWebtoon(name: trimName, siteURL: url, to: catID)
            }
        }
        dismiss()
    }
}

#Preview {
    FavoriteSiteFormView()
        .environmentObject(SettingsViewModel())
        .environmentObject(LibraryManager())
}
