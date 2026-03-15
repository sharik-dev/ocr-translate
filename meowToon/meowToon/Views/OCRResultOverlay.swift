import SwiftUI

private let kOCRGreen = Color(red: 0.12, green: 0.92, blue: 0.45)

// MARK: - Layout engine

/// Computed frame for one bubble after clamping + de-overlap.
private struct BubbleFrame: Identifiable {
    var id: UUID { item.id }
    let item:            RecognizedTextItem
    var center:          CGPoint
    let width:           CGFloat
    let estimatedHeight: CGFloat

    var rect: CGRect {
        CGRect(x: center.x - width / 2,
               y: center.y - estimatedHeight / 2,
               width:  width,
               height: estimatedHeight)
    }
}

/// Clamp each bubble to screen bounds, then push overlapping ones downward.
private func buildLayout(items: [RecognizedTextItem], in size: CGSize) -> [BubbleFrame] {
    guard size.width > 0, size.height > 0 else { return [] }

    let gap:          CGFloat = 8
    let topSafe:      CGFloat = 72   // below dismiss hint
    let sideMargin:   CGFloat = 8
    let bottomMargin: CGFloat = 20

    // Build initial frames, sorted top→bottom
    var frames: [BubbleFrame] = items
        .sorted { $0.boundingBox.midY < $1.boundingBox.midY }
        .map { item in
            let fontSize = CGFloat(max(13, min(22, item.boundingBox.height * 0.65)))
            let w = min(max(item.boundingBox.width * 1.1, 72),
                        size.width - sideMargin * 2)
            let h = fontSize * 1.45 + 18  // single-line estimate; text expands vertically

            // Start at OCR centre, clamped
            let cx = min(max(item.boundingBox.midX, w / 2 + sideMargin),
                         size.width  - w / 2 - sideMargin)
            let cy = min(max(item.boundingBox.midY, topSafe + h / 2),
                         size.height - h / 2 - bottomMargin)

            return BubbleFrame(item: item,
                               center: CGPoint(x: cx, y: cy),
                               width: w,
                               estimatedHeight: h)
        }

    // Greedy de-overlap: push later bubbles below earlier ones
    for i in 1..<frames.count {
        for j in 0..<i {
            let a = frames[j].rect.insetBy(dx: -(gap / 2), dy: -(gap / 2))
            if a.intersects(frames[i].rect) {
                let newCY = frames[j].rect.maxY + gap + frames[i].estimatedHeight / 2
                frames[i].center.y = min(newCY,
                                         size.height - frames[i].estimatedHeight / 2 - bottomMargin)
            }
        }
    }

    return frames
}

// MARK: - Overlay

struct OCRResultOverlay: View {
    let items:     [RecognizedTextItem]
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let layout = buildLayout(items: items, in: geo.size)

            ZStack {
                // Tap-to-dismiss backdrop
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                // Dismiss hint
                VStack {
                    Text("Toucher pour fermer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.vertical, 5).padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 0.5))
                        )
                        .shadow(color: kOCRGreen.opacity(0.45), radius: 10, y: 2)
                        .padding(.top, 54)
                    Spacer()
                }

                // Translation bubbles — laid out without overlap
                ForEach(Array(layout.enumerated()), id: \.element.id) { idx, entry in
                    bubbleView(entry: entry)
                        .position(entry.center)
                        .opacity(appeared  ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.84, anchor: .center)
                        .animation(
                            .spring(response: 0.28, dampingFraction: 0.7)
                                .delay(Double(idx) * 0.03),
                            value: appeared
                        )
                }
            }
            .onAppear { withAnimation { appeared = true } }
        }
        .ignoresSafeArea()
    }

    // MARK: - Single bubble

    @ViewBuilder
    private func bubbleView(entry: BubbleFrame) -> some View {
        let fontSize = CGFloat(max(13, min(22, entry.item.boundingBox.height * 0.65)))

        Text(entry.item.displayText)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(width: entry.width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    // Semi-transparent grey — lets a hint of the underlying colour pass through
                    .fill(Color(white: 0.16, opacity: 0.76))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
    }
}
