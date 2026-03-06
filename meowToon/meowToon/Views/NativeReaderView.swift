import SwiftUI
import Combine
import Translation
import Translation

struct NativeReaderView: View {
    let sourceId: String // Inject the source Id required for fetching
    let chapter: WebtoonChapter
    
    @EnvironmentObject var settingsVM: SettingsViewModel
    
    @State private var pageURLs: [URL] = []
    @State private var isLoading = false
    
    @State private var readerSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Main Reader
            GeometryReader { geo in
                let mainContent = ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading {
                            ProgressView()
                                .padding(100)
                        } else {
                            ForEach(pageURLs, id: \.self) { url in
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    } else if phase.error != nil {
                                        VStack {
                                            Image(systemName: "exclamationmark.triangle")
                                            Text("Failed to load")
                                        }
                                        .frame(height: 300)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.gray.opacity(0.2))
                                    } else {
                                        ProgressView()
                                            .frame(height: 300)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.gray.opacity(0.1))
                                    }
                                }
                            }
                        }
                    }
                }
                
                mainContent
                    .onAppear {
                        readerSize = geo.size
                    }
                    .onChange(of: geo.size) { _, newSize in
                        readerSize = newSize
                    }
            }
        }
        .navigationTitle(chapter.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPages()
        }
    }
    
    private func loadPages() {
        isLoading = true
        Task {
            do {
                let source = SourceFactory.shared.getSource(for: sourceId)
                let urls = try await source.fetchPageList(for: chapter)
                await MainActor.run {
                    self.pageURLs = urls
                    self.isLoading = false
                }
            } catch {
                print("Failed to load pages: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
