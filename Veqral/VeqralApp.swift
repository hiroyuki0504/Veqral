import SwiftUI

@main
struct VeqralApp: App {
    @UIApplicationDelegateAdaptor(VeqralAppDelegate.self) private var appDelegate
    @StateObject private var store = ForgeStore()

    var body: some Scene {
        WindowGroup {
            ForgeRootView()
                .environmentObject(store)
                .onAppear {
                    VeqralPushNotificationCenter.shared.attach(store: store)
                    VeqralPushNotificationCenter.shared.register()
                }
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "veqral",
                          url.host?.lowercased() == "pair" else {
                        return
                    }
                    Task {
                        _ = try? await store.pair(using: url, deviceName: "Veqral Forge")
                        try? await store.refresh()
                    }
                }
        }
    }
}
