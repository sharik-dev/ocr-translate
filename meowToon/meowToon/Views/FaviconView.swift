import SwiftUI

// Shared favicon view — shows the real site icon via Google's favicon service,
// falls back to a coloured badge with the first 2 letters of the domain.

private let kFavGreen = Color(red: 0.12, green: 0.92, blue: 0.45)

struct FaviconView: View {
    let urlString: String
    /// Rendered size (width == height)
    var size: CGFloat = 32

    private var faviconURL: URL? {
        guard let host = URL(string: urlString)?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }

    /// e.g. "mangadex.org" → "MA"
    private var initials: String {
        let host = URL(string: urlString)?.host ?? urlString
        let clean = host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: ".org", with: "")
            .replacingOccurrences(of: ".net", with: "")
        return String(clean.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let faviconURL {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                    default:
                        badge
                    }
                }
            } else {
                badge
            }
        }
        .frame(width: size, height: size)
    }

    private var badge: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(LinearGradient(
                        colors: [kFavGreen, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
            )
    }
}
