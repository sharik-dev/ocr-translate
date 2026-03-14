import Foundation
import Combine

/// Shared navigation intent — set from any sheet/child to trigger main-browser navigation.
class AppNavigator: ObservableObject {
    @Published var requestedURL: String? = nil

    func navigate(to url: String) {
        requestedURL = url
    }
}
