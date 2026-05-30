import SwiftUI

@main
struct VeqralApp: App {
    @StateObject private var store = CommandCenterStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(VQTheme.accent)
                .environmentObject(store)
                .onOpenURL { url in
                    store.handlePairingURL(url)
                }
        }
    }
}
