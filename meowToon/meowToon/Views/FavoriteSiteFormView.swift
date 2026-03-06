import SwiftUI

struct FavoriteSiteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM: SettingsViewModel
    
    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var iconSystemName: String = "globe"
    
    let availableIcons = ["globe", "book", "books.vertical", "rectangle.stack", "star", "heart", "newspaper"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "favorite.site_name"), text: $name)
                    TextField(String(localized: "favorite.url_placeholder"), text: $urlString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text(String(localized: "favorite.icon"))) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(iconSystemName == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    iconSystemName = icon
                                }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "favorite.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) {
                        var finalURL = urlString
                        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
                            finalURL = "https://" + finalURL
                        }
                        let newFav = FavoriteSite(name: name, urlString: finalURL, iconSystemName: iconSystemName)
                        settingsVM.addFavorite(newFav)
                        dismiss()
                    }
                    .disabled(name.isEmpty || urlString.isEmpty)
                }
            }
        }
    }
}
