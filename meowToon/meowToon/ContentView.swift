import SwiftUI

struct ContentView: View {
    @StateObject private var settingsVM = SettingsViewModel()
    
    var body: some View {
        HomeView()
            .environmentObject(settingsVM)
    }
}

#Preview {
    ContentView()
}
