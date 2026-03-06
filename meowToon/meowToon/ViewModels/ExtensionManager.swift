import Foundation
import Combine

class ExtensionManager: ObservableObject {
    @Published var availableExtensions: [RepoExtension] = []
    @Published var isLoadingRepo: Bool = false
    @Published var errorMessage: String?
    
    // The list of "installed" / active sources
    @Published var installedSources: [SourceDescriptor] = []
    
    @Published var customRepoURL: String = UserDefaults.standard.string(forKey: "meowToon.repoURL") ?? "" {
        didSet {
            UserDefaults.standard.set(customRepoURL, forKey: "meowToon.repoURL")
            availableExtensions = [] // Clear existing when URL changes
        }
    }
    
    private let installedSourcesKey = "meowToon.installedSources"
    
    init() {
        loadInstalledSources()
    }
    
    // MARK: - Repo Fetching
    
    @MainActor
    func fetchRepository() async {
        guard let url = URL(string: customRepoURL), !customRepoURL.isEmpty else {
            self.errorMessage = "Veuillez entrer une URL de repository valide."
            return
        }
        
        isLoadingRepo = true
        errorMessage = nil
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([RepoExtension].self, from: data)
            
            // Filter or process the extensions as needed
            self.availableExtensions = decoded
            
        } catch {
            self.errorMessage = "Failed to fetch extensions: \(error.localizedDescription)"
            print("Repo Fetch Error: \(error)")
        }
        
        isLoadingRepo = false
    }
    
    // MARK: - Source Management
    
    func isInstalled(source: SourceDescriptor) -> Bool {
        return installedSources.contains(where: { $0.id == source.id })
    }
    
    func toggleInstall(source: SourceDescriptor) {
        if let index = installedSources.firstIndex(where: { $0.id == source.id }) {
            installedSources.remove(at: index)
        } else {
            installedSources.append(source)
        }
        saveInstalledSources()
    }
    
    private func saveInstalledSources() {
        do {
            let data = try JSONEncoder().encode(installedSources)
            UserDefaults.standard.set(data, forKey: installedSourcesKey)
        } catch {
            print("Failed to save installed sources: \(error)")
        }
    }
    
    private func loadInstalledSources() {
        guard let data = UserDefaults.standard.data(forKey: installedSourcesKey) else { return }
        do {
            installedSources = try JSONDecoder().decode([SourceDescriptor].self, from: data)
        } catch {
            print("Failed to load installed sources: \(error)")
        }
    }
}
