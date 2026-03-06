import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showingSettings = false
    @State private var showingAddFavorite = false
    @State private var searchURL = ""
    
    // Using a binding to external navigation if we are inside a parent that handles navigation
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar for quick navigation
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(String(localized: "home.search_placeholder"), text: $searchURL)
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .onSubmit {
                            navigateTo(url: searchURL)
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Favorites grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                        ForEach(settingsVM.favorites) { favorite in
                            NavigationLink(destination: BrowserView(initialURL: favorite.urlString)) {
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemGray6))
                                            .frame(width: 60, height: 60)
                                        Image(systemName: favorite.iconSystemName)
                                            .font(.title)
                                            .foregroundColor(.primary)
                                    }
                                    Text(favorite.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        // Add Button
                        Button(action: { showingAddFavorite = true }) {
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .foregroundColor(.accentColor)
                                }
                                Text(String(localized: "home.add_favorite"))
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(String(localized: "app.name"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAddFavorite) {
                FavoriteSiteFormView()
            }
        }
    }
    
    // Quick navigation via search bar
    private func navigateTo(url: String) {
        // Here we could programmatically push BrowserView via a state variable
        // For simplicity, we can let the TextField handle submission, and maybe
        // trigger a hidden NavigationLink, or just embed BrowserView completely differently.
        // Wait, since we are in a NavigationStack, NavigationLink(value:) is better.
    }
}

#Preview {
    HomeView()
        .environmentObject(SettingsViewModel())
}
