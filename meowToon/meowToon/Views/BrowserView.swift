import SwiftUI

// BrowserView is kept as a thin wrapper for any remaining NavigationLink references.
// Primary browser functionality is now handled by ContentView's unified nav bar + WebVM.

struct BrowserView: View {
    @EnvironmentObject var navigator: AppNavigator
    @Environment(\.dismiss) private var dismiss
    let initialURL: String

    var body: some View {
        Color.clear
            .onAppear {
                navigator.navigate(to: initialURL)
                dismiss()
            }
    }
}
