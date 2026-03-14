import SwiftUI
import Combine
import WebKit

struct CaptchaResolverView: View {
    @ObservedObject var manager = HiddenWebViewManager.shared
    
    var body: some View {
        if manager.isShowingCaptcha {
            ZStack {
                Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    HStack {
                        Text("Vérification de sécurité")
                            .font(.headline)
                        Spacer()
                        Button("Fermer") {
                            manager.isShowingCaptcha = false
                        }
                    }
                    .padding()
                    
                    Text("Veuillez résoudre le captcha pour continuer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CaptchaWebViewContainer()
                        .frame(height: 400)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    
                    Button("J'ai terminé") {
                        manager.isShowingCaptcha = false
                        // Once user solving is done, try to refresh or signal the engine
                        if let url = manager.currentURL {
                            manager.webView.load(URLRequest(url: url))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .padding(30)
            }
            .transition(.move(edge: .bottom))
        }
    }
}
