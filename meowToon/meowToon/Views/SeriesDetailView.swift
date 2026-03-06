import SwiftUI

struct SeriesDetailView: View {
    let series: WebtoonSeries
    
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var chapters: [WebtoonChapter] = []
    @State private var isLoading = false
    
    // Dummy Cover Color
    let coverColor = Color.accentColor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Header with Blurred Background
                ZStack(alignment: .bottom) {
                    // Blurred background
                    coverColor
                        .opacity(0.6)
                        .frame(height: 300)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color(UIColor.systemBackground)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    HStack(alignment: .bottom, spacing: 16) {
                        // Poster image
                        if let surl = series.coverURL, let url = URL(string: surl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 150)
                                        .cornerRadius(12)
                                        .shadow(radius: 5)
                                } else {
                                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 150)
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 150)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .overlay(Text("Cover").foregroundColor(.secondary))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(series.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Text(series.author ?? "Unknown Author")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(series.status ?? "Ongoing")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                                    .foregroundColor(.accentColor)
                                
                                Text("Action") // Mock genre
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // MARK: - Actions & Description
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        let isSaved = libraryManager.isSaved(series: series)
                        Button(action: {
                            withAnimation {
                                libraryManager.toggleSave(series: series)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: isSaved ? "heart.fill" : "heart")
                                    .font(.title2)
                                Text("Favori")
                                    .font(.caption)
                            }
                            .foregroundColor(isSaved ? .red : .primary)
                        }
                        
                        Button(action: {
                            // Resume reading
                        }) {
                            Text("Lire Chapitre 1")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                        }
                    }
                    .padding(.horizontal)
                    
                    Text(series.description ?? "Aucune description disponible pour cette série.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .lineSpacing(4)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // MARK: - Chapter List
                    HStack {
                        Text("\(chapters.count) Chapitres")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(chapters) { chapter in
                                NavigationLink(destination: NativeReaderView(sourceId: series.sourceId, chapter: chapter)) {
                                    HStack(spacing: 16) {
                                        // Chapter Thumbnail Placeholder
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 80, height: 60)
                                            .cornerRadius(6)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(chapter.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            Text(chapter.dateUpload?.formatted(date: .abbreviated, time: .omitted) ?? "Date inconnue")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.systemBackground))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChapters()
        }
    }
    
    private func loadChapters() {
        isLoading = true
        Task {
            do {
                let source = SourceFactory.shared.getSource(for: series.sourceId)
                let results = try await source.fetchChapters(for: series)
                await MainActor.run {
                    self.chapters = results
                    self.isLoading = false
                }
            } catch {
                print("Failed to load chapters: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
