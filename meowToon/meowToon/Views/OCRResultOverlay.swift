import SwiftUI

struct OCRResultOverlay: View {
    let items: [RecognizedTextItem]
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background to capture taps and dismiss
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
                
                VStack {
                    Text(String(localized: "ocr.tap_to_dismiss"))
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.top, 40)
                    Spacer()
                }
            
            // Map each recognized item to a view at its bounds
            ForEach(items) { item in
                Text(item.displayText)
                    .font(.system(size: 1000)) // Use a massive font
                    .minimumScaleFactor(0.01)  // Let it scale down to perfectly fit
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(UIColor.systemBackground)))
                    .frame(width: item.boundingBox.width, height: item.boundingBox.height)
                    .position(x: item.boundingBox.midX, y: item.boundingBox.midY)
            }
        }
    }
}
