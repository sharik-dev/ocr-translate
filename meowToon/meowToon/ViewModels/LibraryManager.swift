import Foundation
import Combine

class LibraryManager: ObservableObject {
    @Published var savedSeries: [WebtoonSeries] = []
    
    private let userDefaultsKey = "meowToon.library"
    
    init() {
        loadLibrary()
    }
    
    func isSaved(series: WebtoonSeries) -> Bool {
        return savedSeries.contains(where: { $0.id == series.id })
    }
    
    func toggleSave(series: WebtoonSeries) {
        if let index = savedSeries.firstIndex(where: { $0.id == series.id }) {
            savedSeries.remove(at: index)
        } else {
            savedSeries.append(series)
        }
        saveLibrary()
    }
    
    private func saveLibrary() {
        do {
            let data = try JSONEncoder().encode(savedSeries)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save library: \(error)")
        }
    }
    
    private func loadLibrary() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            savedSeries = try JSONDecoder().decode([WebtoonSeries].self, from: data)
        } catch {
            print("Failed to load library: \(error)")
        }
    }
}
