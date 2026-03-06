import SwiftUI
import Combine
import Translation
import WebKit

struct BrowserView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @StateObject private var webVM = WebViewModel()
    @StateObject private var ocrVM = OCRViewModel()
    
    let initialURL: String
    
    @State private var floatingButtonPosition = CGPoint(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 150)
    @Environment(\.dismiss) private var dismiss
    @State private var isTabBarExpanded = true
    @State private var webViewSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            // WebView takes full screen
            GeometryReader { geo in
                WebViewContainer(viewModel: webVM)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        webViewSize = geo.size
                        if webVM.webView?.url == nil {
                            webVM.load(urlString: initialURL)
                        }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        webViewSize = newSize
                    }
            }
            
            // Retractable Bottom Tab Bar
            VStack {
                Spacer()
                HStack {
                    if isTabBarExpanded {
                        // Expanded state
                        Button(action: { dismiss() }) {
                            Image(systemName: "house.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        Button(action: { webVM.goBack() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!webVM.canGoBack)
                        .opacity(webVM.canGoBack ? 1.0 : 0.3)
                        
                        Spacer()
                        
                        Button(action: { webVM.goForward() }) {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!webVM.canGoForward)
                        .opacity(webVM.canGoForward ? 1.0 : 0.3)
                        
                        Spacer()
                        
                        if webVM.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 44, height: 44)
                        } else {
                            Button(action: { webVM.reload() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                isTabBarExpanded.toggle()
                            }
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        // Collapsed state
                        Button(action: {
                            withAnimation(.spring()) {
                                isTabBarExpanded.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .padding(.horizontal, isTabBarExpanded ? 15 : 5)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                )
                .frame(width: isTabBarExpanded ? UIScreen.main.bounds.width * 0.85 : 60, height: 60)
                .padding(.bottom, 20)
            }
            
            // OCR Overlay if processing or complete
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
            
            // Floating Button
            if settingsVM.translationSettings.isOCREnabled && !ocrVM.isProcessing && !ocrVM.showOverlay {
                FloatingOCRButton(position: $floatingButtonPosition) {
                    Task {
                        if let image = await webVM.takeSnapshot() {
                            await ocrVM.startPipeline(
                                image: image,
                                viewSize: webViewSize,
                                targetLanguageCode: settingsVM.translationSettings.targetLanguageCode
                            )
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .translationTask(ocrVM.translationConfig) { session in
            await ocrVM.performTranslation(session: session)
        }
    }
}
