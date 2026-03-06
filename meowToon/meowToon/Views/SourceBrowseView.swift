import SwiftUI

// This represents browsing a specific source (like Akuma)
struct SourceBrowseView: View {
    let sourceId: String
    let sourceName: String
    
    @State private var query = ""
    @State private var seriesList: [WebtoonSeries] = []
    @State private var isLoading = false
    
    // UI Layout: 3 columns for series
    let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(seriesList) { series in
                    NavigationLink(destination: SeriesDetailView(series: series)) {
                        ZStack(alignment: .bottomLeading) {
                            // Cover Image
                            if let surl = series.coverURL, let url = URL(string: surl) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                            .font(.largeTitle)
                                    )
                            }
                            
                            // Dark gradient overlay for text readability
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            
                            // Series Title Overlay
                            Text(series.title)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(8)
                        }
                        .aspectRatio(2/3, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle(sourceName)
        .searchable(text: $query, prompt: "Rechercher...")
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if seriesList.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Aucun résultat.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        isLoading = true
        Task {
            do {
                let source = SourceFactory.shared.getSource(for: sourceId)
                let results = try await source.fetchPopularSeries(page: 1)
                await MainActor.run {
                    self.seriesList = results
                    self.isLoading = false
                }
            } catch {
                print("Failed to load initial data: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
