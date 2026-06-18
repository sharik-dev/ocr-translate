import SwiftUI

@main
struct meowToonApp: App {
    init() {
        // Deterministic state for UITest / screenshot runs:
        // wipe persisted favorites so the bundled defaults are re-seeded.
        if CommandLine.arguments.contains("-UITestMode") {
            let ud = UserDefaults.standard
            ud.removeObject(forKey: "meowToon.favorites")
            ud.removeObject(forKey: "meowToon.defaultFavoritesSeeded")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
