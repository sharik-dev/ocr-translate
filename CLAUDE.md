# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**meowToon** is an iOS webtoon/manga reader and browser app built with SwiftUI (iOS 17+). It combines a multi-tab web browser with aggressive ad blocking, a personal webtoon library, and OCR+translation support. Zero external dependencies — all native iOS frameworks.

---

## Build & Run

```bash
# Open in Xcode
open meowToon/meowToon.xcodeproj

# Run: ⌘R in Xcode (iOS 17+ simulator or device required)
# Tests: ⌘U in Xcode
```

Requirements: Xcode 15+, macOS 12+, iOS 17+.

---

## Architecture

MVVM pattern with Combine for reactive state. No external packages — pure SwiftUI + WebKit + Vision + Translation.

### Entry points
- **`meowToonApp.swift`** — App entry; forces dark theme; resets floating button positions on cold launch
- **`ContentView.swift`** — Root container: tab management, URL bar state, overlay coordination, floating action buttons (OCR + bookmark). Defines shared colors `kGreen` (accent) and `kDarkBG` (background).

### Key managers (singletons / @StateObject)

| Class | Role |
|-------|------|
| `TabManager` | Multi-tab lifecycle; lazy WebVM creation (only mounts WebView for visited tabs) |
| `LibraryManager` | Category/webtoon CRUD + bookmark management; persists to UserDefaults as JSON |
| `SettingsViewModel` | Global settings (ad-block toggle, OCR, translation prefs, favorite sites) |
| `AdBlockManager` | Compiles `AdBlockRules.json` as `WKContentRuleList`; cached singleton; applied/removed per tab dynamically |
| `AppNavigator` | Deferred URL loading — lets navigation happen before WebView is attached |
| `OCRViewModel` | Vision-based text recognition + translation pipeline |

### Views
- **`HomeView.swift`** — Home screen: quick-access favorites grid + webtoon library (3-column, sortable, filterable by category)
- **`WebViewContainer.swift`** — `UIViewRepresentable` wrapping `WKWebView`; injects all ad-block JS at `document_start`
- **`FavoriteSiteFormView.swift`** — Form to add/edit a favorite shortcut or webtoon entry

---

## Ad Blocking Architecture

**Two-layer approach** (both applied per tab):

1. **`AdBlockRules.json`** — WebKit native `WKContentRuleList` (network-level blocking). Compiled once by `AdBlockManager` singleton, cached, applied/removed per `WKUserContentController`.

2. **JS injected at `document_start`** in `WebViewContainer.swift** — 8 layers:
   - CSS cosmetic filtering (hides ad containers, zero flicker)
   - `window.open()` nullification (JS popup blocker)
   - `target="_blank"` stripping (forces links to stay in current tab)
   - Ad-network iframe removal (doubleclick, googlesyndication, adsterra, exoclick, etc.)
   - Forbidden host blocklist (navigation guard)
   - `setTimeout`-based redirect killer (<100ms redirects blocked)
   - Anti-adblock spoofing (stubs `window.adsbygoogle`, `googletag`, `fbq`)
   - `<meta http-equiv="refresh">` removal

Toggle ad-block in real-time via `SettingsViewModel.adBlockEnabled` — changes propagate immediately to all tabs.

---

## Data Persistence

All data stored in `UserDefaults`:

| Key | Contents |
|-----|----------|
| `meowToon.libraryV2` | JSON — categories + their webtoons |
| `meowToon.uncategorized` | JSON — webtoons with no category |
| `browser.tabs` | JSON — tab state (lazy restored) |
| `browser.activeIndex` | Int — active tab |
| `search.history` | Array — last 50 URLs/queries |

`LibraryManager` auto-creates 5 default categories (Action ⚔️, Romance 💕, Fantasy 🧙, Comedy 😄, Sci-Fi 🚀) on first launch.

---

## Key Data Models

```swift
// FavoriteSite — quick-access shortcut or webtoon entry
struct FavoriteSite: Identifiable, Codable {
    id: UUID; name: String; urlString: String
    type: FavoriteType  // .site | .webtoon
    iconSystemName: String
}

// Library hierarchy
LibraryCategory  →  [LibraryWebtoon]  →  [WebBookmark]
// WebBookmark: title, URL, note, timestamp
```

---

## UI Conventions

- **Theme**: `kDarkBG` background (`#0D0D12`), `kGreen` accent (`#00D564`), white text at varying opacities
- **Material**: `ultraThinMaterial` with custom stroke borders for cards/sheets
- **Animations**: Spring-based (`response: 0.35, damping: 0.8`) — never linear easing
- **Haptics**: `UIImpactFeedbackGenerator` on button taps
- **Floating buttons** (OCR + bookmark): draggable with snap-to-edge; positions intentionally reset on cold launch (by design, not a bug)
- **Navigation bubble**: collapsible to compact dot; draggable; resets position on cold launch

---

## Localization

UI text is in French. Keep new UI strings in French to match existing conventions.
