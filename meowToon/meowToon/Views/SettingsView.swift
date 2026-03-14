import SwiftUI

private let kGreen  = Color(red: 0.12, green: 0.92, blue: 0.45)
private let kDarkBG = Color(red: 0.02, green: 0.06, blue: 0.02)

struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var ocrVM: OCRViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                kDarkBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {

                        // ── Navigation ──────────────────────────────────
                        sectionHeader("Navigation")
                        glassCard {
                            toggleRow(
                                label: "Bloqueur de publicités",
                                icon:  "shield.fill",
                                description: "Bloque les réseaux publicitaires connus",
                                isOn: $settingsVM.isAdBlockEnabled
                            ) { settingsVM.saveAdBlock() }
                        }

                        // ── Traducteur ──────────────────────────────────
                        sectionHeader("Traducteur OCR")
                        glassCard {
                            VStack(spacing: 0) {
                                toggleRow(
                                    label: "Afficher le bouton de traduction",
                                    icon:  "text.viewfinder",
                                    description: "Bouton flottant pour analyser l'écran",
                                    isOn: $settingsVM.translationSettings.isOCREnabled
                                ) { settingsVM.saveTranslationSettings() }

                                dividerLine

                                languagePickerRow

                                dividerLine

                                engineSection
                            }
                        }

                        // ── Favoris ─────────────────────────────────────
                        if !settingsVM.favorites.isEmpty {
                            sectionHeader("Favoris enregistrés")
                            glassCard {
                                ForEach(Array(settingsVM.favorites.enumerated()), id: \.element.id) { idx, fav in
                                    VStack(spacing: 0) {
                                        if idx > 0 { dividerLine }
                                        HStack(spacing: 12) {
                                            Image(systemName: fav.iconSystemName)
                                                .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 26)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(fav.name)
                                                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                                                Text(fav.urlString)
                                                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.38)).lineLimit(1)
                                            }
                                            Spacer()
                                            Button {
                                                settingsVM.removeFavorite(at: IndexSet(integer: idx))
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.red.opacity(0.65))
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 11)
                                    }
                                }
                            }
                        }

                        // ── À propos ────────────────────────────────────
                        sectionHeader("À propos")
                        glassCard {
                            HStack {
                                Text("Version").font(.system(size: 14)).foregroundColor(.white.opacity(0.65))
                                Spacer()
                                Text("1.0.0").font(.system(size: 14)).foregroundColor(.white.opacity(0.32))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        settingsVM.saveAll()
                        dismiss()
                    }
                    .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .leading, endPoint: .trailing))
                    .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Language picker

    private var languagePickerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("Langue cible").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Text("Langue de traduction").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Picker("", selection: $settingsVM.translationSettings.targetLanguageCode) {
                ForEach(TranslationSettings.availableLanguages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .pickerStyle(.menu)
            .tint(kGreen)
            .onChange(of: settingsVM.translationSettings.targetLanguageCode) { _, _ in
                ocrVM.invalidateSession()
                settingsVM.saveTranslationSettings()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    // MARK: - Engine section

    private var engineSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26)
                Text("Moteur de traduction")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            engineRow(.google)
            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
            engineRow(.myMemory)
            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
            engineRow(.apple)

            dividerLine
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(kGreen.opacity(0.7))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moteur de secours")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                    Text("Active un moteur alternatif si le principal échoue")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Toggle("", isOn: $settingsVM.translationSettings.enableFallback)
                    .labelsHidden().tint(kGreen)
                    .onChange(of: settingsVM.translationSettings.enableFallback) { _, _ in
                        settingsVM.saveTranslationSettings()
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .disabled(settingsVM.translationSettings.engine == .myMemory)
            .opacity(settingsVM.translationSettings.engine == .myMemory ? 0.4 : 1)
        }
    }

    private func engineRow(_ engine: TranslationEngine) -> some View {
        Button(action: {
            settingsVM.translationSettings.engine = engine
            if engine == .myMemory { settingsVM.translationSettings.enableFallback = false }
            settingsVM.saveTranslationSettings()
        }) {
            HStack(spacing: 12) {
                Image(systemName: settingsVM.translationSettings.engine == engine
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(settingsVM.translationSettings.engine == engine ? kGreen : .white.opacity(0.3))
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(engine.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable builders

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.38))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.025)))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func toggleRow(
        label: String,
        icon: String,
        description: String,
        isOn: Binding<Bool>,
        onChange: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LinearGradient(colors: [kGreen, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Text(description).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden().tint(kGreen)
                .onChange(of: isOn.wrappedValue) { _, _ in onChange() }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private var dividerLine: some View {
        Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 16)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(OCRViewModel())
}
