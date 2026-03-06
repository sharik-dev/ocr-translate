import SwiftUI

enum LibraryTab {
    case favoris, sources
}

struct LibraryView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var extensionManager: ExtensionManager
    @State private var searchQuery = ""
    @State private var selectedTab: LibraryTab = .favoris
    
    var filteredSeries: [WebtoonSeries] {
        if searchQuery.isEmpty {
            return libraryManager.savedSeries
        } else {
            return libraryManager.savedSeries.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    var filteredSources: [SourceDescriptor] {
        if searchQuery.isEmpty {
            return extensionManager.installedSources
        } else {
            return extensionManager.installedSources.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tabs", selection: $selectedTab) {
                    Text("Favoris").tag(LibraryTab.favoris)
                    Text("Sources").tag(LibraryTab.sources)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Group {
                    if selectedTab == .favoris {
                        if libraryManager.savedSeries.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text("Votre bibliothèque est vide")
                                    .font(.headline)
                                Text("Allez dans vos sources pour trouver et ajouter de nouvelles séries.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        } else if filteredSeries.isEmpty {
                            Text("Aucune série ne correspond à la recherche.")
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                                    ForEach(filteredSeries) { series in
                                        NavigationLink(destination: SeriesDetailView(series: series)) {
                                            VStack(alignment: .leading) {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .aspectRatio(2/3, contentMode: .fit)
                                                    .cornerRadius(8)
                                                    .overlay(
                                                        Text("Cover")
                                                            .foregroundColor(.secondary)
                                                    )
                                                
                                                Text(series.title)
                                                    .font(.caption)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    } else {
                        // SOURCES TAB
                        if extensionManager.installedSources.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                Image(systemName: "puzzlepiece")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text("Aucune source installée")
                                    .font(.headline)
                                Text("Allez dans l'onglet Extensions pour en installer.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(filteredSources) { source in
                                    NavigationLink(destination: SourceBrowseView(sourceId: source.id, sourceName: source.name)) {
                                        HStack {
                                            Text(source.name)
                                                .font(.headline)
                                            Spacer()
                                            Text(source.lang.uppercased())
                                                .font(.caption2).bold()
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    }
                }
            }
            .navigationTitle("Bibliothèque")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Rechercher...")
        }
    }
}

#Preview {
    LibraryView()
}
