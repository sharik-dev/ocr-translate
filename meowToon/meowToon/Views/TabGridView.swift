import SwiftUI

// MARK: - TabGridView (Safari style)

struct TabGridView: View {

    @ObservedObject var tabManager: TabManager
    var onSelectTab: (Int) -> Void
    var onClose:     () -> Void
    var onNewTab:    () -> Void

    @State private var showCloseAllConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
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
                        showCloseAllConfirm = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Tout fermer")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.12))
                                .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 0.8))
                        )
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
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { idx, tab in
                            TabCard(
                                tab:       tab,
                                thumbnail: tabManager.thumbnails[tab.id],
                                isActive:  idx == tabManager.activeIndex,
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
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabManager.tabs.count)
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
        .confirmationDialog(
            "Fermer tous les onglets ?",
            isPresented: $showCloseAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Tout fermer", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    tabManager.closeAllTabs()
                }
                onClose()
            }
            Button("Annuler", role: .cancel) { }
        }
    }
}

// MARK: - TabCard (Safari-style swipe-left to dismiss)

private struct TabCard: View {

    let tab:       BrowserTab
    let thumbnail: UIImage?
    let isActive:  Bool
    let onSelect:  () -> Void
    let onClose:   () -> Void

    @State private var dragOffset:   CGFloat = 0
    @State private var isDismissing = false

    private let dismissThreshold: CGFloat = 90

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── Fond rouge visible au swipe-left ───────────────────────
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.6 * min(abs(min(dragOffset, 0)) / dismissThreshold, 1.0)))
                .overlay(
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(min(abs(min(dragOffset, 0)) / dismissThreshold, 1.0))
                            .padding(.trailing, 20)
                    }
                )

            // ── Carte principale ───────────────────────────────────────
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header — favicon + title
                    HStack(spacing: 6) {
                        if !tab.urlString.isEmpty {
                            FaviconView(urlString: tab.urlString, size: 14)
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Text(tab.title.isEmpty ? "Nouvel onglet" : tab.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(isActive ? 0.12 : 0.06))

                    // Screenshot preview (or fallback)
                    ZStack {
                        Color(white: 0.08)
                        if let img = thumbnail {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if !tab.urlString.isEmpty {
                            VStack(spacing: 6) {
                                FaviconView(urlString: tab.urlString, size: 28)
                                    .opacity(0.6)
                                Text(URL(string: tab.urlString)?.host ?? tab.urlString)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.3))
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                            }
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.white.opacity(0.15))
                                Text("Page vide")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isActive ? Color.white.opacity(0.55) : Color.white.opacity(0.1),
                                    lineWidth: isActive ? 1.8 : 0.8
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .offset(x: dragOffset)
            .opacity(isDismissing ? 0 : 1 - min(abs(dragOffset) / 240.0, 0.35))

            // ── Bouton fermer (plus grand) ──────────────────────────────
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.2)) {
                    isDismissing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    onClose()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.8))
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(8)
            .opacity(isDismissing ? 0 : 1)
            .offset(x: dragOffset)
        }
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.75), value: dragOffset)
        .animation(.easeOut(duration: 0.2), value: isDismissing)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    // Safari-style: swipe LEFT only
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    // Allow slight right elasticity but only commit left
                    if value.translation.width <= 0 {
                        dragOffset = value.translation.width
                    } else {
                        dragOffset = value.translation.width * 0.2
                    }
                }
                .onEnded { value in
                    if value.translation.width < -dismissThreshold {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragOffset   = -360
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
