import SwiftUI

// MARK: - TabGridView (Safari style)

struct TabGridView: View {

    @ObservedObject var tabManager: TabManager
    var onSelectTab: (Int) -> Void
    var onClose:     () -> Void
    var onNewTab:    () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ───────────────────────────────────────────────
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            tabManager.tabs.forEach { tabManager.closeTab(id: $0.id) }
                        }
                        onClose()
                    }) {
                        Text("Tout fermer")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(tabManager.tabs.count) onglet\(tabManager.tabs.count > 1 ? "s" : "")")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Spacer()

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onClose()
                    }) {
                        Text("Terminé")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, 16)

                // ── Grille ───────────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { idx, tab in
                            TabCard(
                                tab:      tab,
                                isActive: idx == tabManager.activeIndex,
                                onSelect: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSelectTab(idx)
                                },
                                onClose: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    tabManager.closeTab(id: tab.id)
                                    if tabManager.tabs.isEmpty { onClose() }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 110)
                }

                Spacer(minLength: 0)
            }

            // ── Barre du bas ─────────────────────────────────────────────
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onNewTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.7), radius: 6)
                            .shadow(color: .white.opacity(0.35), radius: 16)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 44)
            }
        }
    }
}

// MARK: - TabCard (swipe to kill)

private struct TabCard: View {

    let tab:      BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose:  () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false

    private let dismissThreshold: CGFloat = 90

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── Fond rouge visible au swipe ────────────────────────────
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.55 * min(abs(dragOffset) / dismissThreshold, 1.0)))

            // ── Carte principale ───────────────────────────────────────
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {

                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        Text(tab.title.isEmpty ? "Nouvel onglet" : tab.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(isActive ? 0.1 : 0.06))

                    VStack(alignment: .leading, spacing: 6) {
                        if !tab.urlString.isEmpty {
                            Text(tab.urlString)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                                .lineLimit(3)
                        } else {
                            Text("Page vide")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 90)
                    .background(Color.white.opacity(0.03))
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isActive ? Color.white.opacity(0.45) : Color.white.opacity(0.1),
                                    lineWidth: isActive ? 1.5 : 0.8
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .offset(x: dragOffset)
            .opacity(isDismissing ? 0 : 1 - min(abs(dragOffset) / 200.0, 0.4))
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: dragOffset)

            // ── Bouton fermer ──────────────────────────────────────────
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color(white: 0.25))
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
            .padding(6)
            .opacity(isDismissing ? 0 : 1)
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Seulement horizontal
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let swipe = value.translation.width
                    if abs(swipe) > dismissThreshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragOffset  = swipe > 0 ? 300 : -300
                            isDismissing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            onClose()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}
