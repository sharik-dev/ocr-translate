import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "settings.ocr_enabled"), isOn: $settingsVM.translationSettings.isOCREnabled)
                    
                    Picker(String(localized: "settings.target_language"), selection: $settingsVM.translationSettings.targetLanguageCode) {
                        ForEach(TranslationSettings.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.ocr_section"))
                }
                
                Section {
                    List {
                        ForEach(settingsVM.favorites) { favorite in
                            HStack {
                                Image(systemName: favorite.iconSystemName)
                                    .foregroundStyle(.tint)
                                Text(favorite.name)
                            }
                        }
                        .onDelete(perform: settingsVM.removeFavorite)
                        .onMove(perform: settingsVM.moveFavorite)
                    }
                } header: {
                    Text(String(localized: "settings.favorites_section"))
                }
                
                Section {
                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "settings.about"))
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "done")) {
                        settingsVM.saveTranslationSettings()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
}
