import SwiftUI

struct FloatingOCRButton: View {
    @Binding var position: CGPoint
    let action: () -> Void
    
    // Limits for dragging
    let iconSize: CGFloat = 60
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    self.position = value.location
                }
                .onEnded { value in
                    self.position = value.location
                    // Optional: snap to edge logic could be added here
                }
        )
    }
}
