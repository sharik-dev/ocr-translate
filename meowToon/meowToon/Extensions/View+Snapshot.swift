import SwiftUI
import UIKit

extension View {
    /// Captures the view as a UIImage using iOS 16+ ImageRenderer or UIHostingController fallback.
    /// Note: This captures exactly what is being rendered in the view.
    @MainActor
    func snapshot(scale: CGFloat? = nil) -> UIImage? {
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: self)
            // Need scale for retina displays
            // Get scale from parameter, or default to 3.0 for modern devices
            renderer.scale = scale ?? {
                // Try to get scale from active window scene
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                   let screen = windowScene.windows.first?.screen {
                    return screen.scale
                }
                return 3.0 // Default to 3x for modern devices
            }()
            return renderer.uiImage
        } else {
            // Fallback for older standard UIHostingController method
            let controller = UIHostingController(rootView: self)
            let view = controller.view
            
            let targetSize = controller.view.intrinsicContentSize
            view?.bounds = CGRect(origin: .zero, size: targetSize)
            view?.backgroundColor = .clear
            
            guard let view = view else { return nil }
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            
            return renderer.image { _ in
                view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
        }
    }
}
