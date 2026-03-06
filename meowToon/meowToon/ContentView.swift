import SwiftUI
import Combine
import Translation

struct ContentView: View {
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var extensionManager = ExtensionManager()
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var ocrVM = OCRViewModel()
    
    @State private var floatingButtonPosition = CGPoint(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 150)
    
    var body: some View {
        ZStack {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Browser", systemImage: "safari")
                    }
                
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
                
                ExtensionsListView()
                    .tabItem {
                        Label("Extensions", systemImage: "puzzlepiece.extension")
                    }
            }
            .environmentObject(settingsVM)
            .environmentObject(extensionManager)
            .environmentObject(libraryManager)
            .environmentObject(ocrVM)
            
            // Global OCR Overlay if processing or complete
            if ocrVM.isProcessing {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    ProgressView(String(localized: "browser.analyzing"))
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            } else if ocrVM.showOverlay {
                OCRResultOverlay(items: ocrVM.recognizedItems) {
                    ocrVM.dismissOverlay()
                }
            }
            
            // Global Floating Button
            if settingsVM.translationSettings.isOCREnabled && !ocrVM.isProcessing {
                FloatingOCRButton(position: $floatingButtonPosition) {
                    Task {
                        // We use a helper extension on UIApplication to snapshot the main window
                        guard let window = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .flatMap({ $0.windows })
                            .first(where: { $0.isKeyWindow }),
                              let image = window.snapshot() else { return }
                            
                        await ocrVM.startPipeline(
                            image: image,
                            viewSize: window.bounds.size,
                            targetLanguageCode: settingsVM.translationSettings.targetLanguageCode
                        )
                    }
                }
            }
        }
        .translationTask(ocrVM.translationConfig) { session in
            await ocrVM.performTranslation(session: session)
        }
    }
}

extension UIView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            layer.render(in: context)
            return UIGraphicsGetImageFromCurrentImageContext()
        }
        return nil
    }
}

#Preview {
    ContentView()
}
