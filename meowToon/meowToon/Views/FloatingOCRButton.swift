import SwiftUI

private let kGreen = Color(red: 0.12, green: 0.92, blue: 0.45)

struct FloatingOCRButton: View {
    @Binding var position: CGPoint
    let action: () -> Void
    var screenWidth: CGFloat = 390 // Default value, should be provided by parent

    @State private var isDragging = false
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        Button(action: action) {
            ZStack {
                // Solid glass circle — no pulsing ring
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(
                        LinearGradient(
                            colors: [kGreen.opacity(0.7), Color.green.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    ))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .frame(width: 52, height: 52)

                Image(systemName: "text.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: kGreen.opacity(0.35), radius: 8, y: 3)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    if !isDragging { isDragging = true }
                    position = v.location
                }
                .onEnded { v in
                    isDragging = false
                    // Snap to nearest horizontal edge
                    let screenW = screenWidth
                    let margin: CGFloat = 34
                    let snappedX = v.location.x < screenW / 2 ? margin : screenW - margin
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        position = CGPoint(x: snappedX, y: v.location.y)
                    }
                }
        )
    }
}
