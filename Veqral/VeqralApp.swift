import SwiftUI

@main
struct VeqralApp: App {
    @UIApplicationDelegateAdaptor(VeqralAppDelegate.self) private var appDelegate
    @StateObject private var store = CommandCenterStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(VQTheme.accent)
                .environmentObject(store)
                .onAppear {
                    VeqralPushNotificationCenter.shared.attach(store: store)
                    VeqralPushNotificationCenter.shared.register()
                }
                .onOpenURL { url in
                    store.handleAppURL(url)
                }
        }
    }
}
