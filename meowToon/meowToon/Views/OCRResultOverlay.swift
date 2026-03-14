import SwiftUI

struct OCRResultOverlay: View {
    let items: [RecognizedTextItem]
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Tap-to-dismiss backdrop (subtle, lets content show through)
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Dismiss hint
            VStack {
                Text("Toucher pour fermer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.vertical, 5).padding(.horizontal, 14)
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    )
                    .padding(.top, 54)
                Spacer()
            }

            // Translation bubbles
            ForEach(items) { item in
                bubble(item, screenWidth: UIScreen.main.bounds.width)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    @ViewBuilder
    private func bubble(_ item: RecognizedTextItem, screenWidth: CGFloat) -> some View {
        let fontSize = CGFloat(max(11, min(20, item.boundingBox.height * 0.5)))
        let minW     = max(item.boundingBox.width, 80.0)
        let maxW     = max(minW, screenWidth * 0.72)

        Text(item.displayText)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .lineLimit(4)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(minWidth: minW, maxWidth: maxW, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    // Dark background only — no colour tint, no glow
                    .fill(Color.black.opacity(0.72))
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8))
            )
            .position(x: item.boundingBox.midX, y: item.boundingBox.midY)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
    }
}
