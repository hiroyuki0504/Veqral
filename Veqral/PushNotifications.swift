import UIKit
import UserNotifications

enum VeqralPushAction {
    static let approve = "VEQRAL_APPROVE_LOW"
    static let reject = "VEQRAL_REJECT_LOW"
    static let lowApprovalCategory = "VEQRAL_APPROVAL_LOW"
    static let highApprovalCategory = "VEQRAL_APPROVAL_HIGH"
    static let statusCategory = "VEQRAL_STATUS"
}

enum VeqralFeatureFlags {
    static let pushNotificationsEnabled = false
}

@MainActor
final class VeqralPushNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = VeqralPushNotificationCenter()

    private weak var store: ForgeStore?
    private var cachedToken: (token: String, environment: String)?

    func attach(store: ForgeStore) {
        self.store = store
        guard VeqralFeatureFlags.pushNotificationsEnabled else { return }
        if let cachedToken {
            sendToken(cachedToken.token, environment: cachedToken.environment)
        }
    }

    func register() {
        guard VeqralFeatureFlags.pushNotificationsEnabled else { return }
        #if targetEnvironment(macCatalyst)
        return
        #else
        registerCategories()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
        #endif
    }

    func receiveToken(_ token: String) {
        guard VeqralFeatureFlags.pushNotificationsEnabled, !token.isEmpty else { return }
        let environment = Self.apnsEnvironment
        cachedToken = (token, environment)
        sendToken(token, environment: environment)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        let runID = Self.runID(from: response.notification.request.content.userInfo)
        let action = response.actionIdentifier
        Task { @MainActor in
            if let runID {
                await self.store?.handlePushApproval(
                    actionIdentifier: action,
                    category: category,
                    runID: runID
                )
            }
        }
        completionHandler()
    }

    private func sendToken(_ token: String, environment: String) {
        guard let store else { return }
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.hiroyuki.veqral"
        let locale = Locale.current.identifier
        Task {
            await store.registerPushToken(token, environment: environment, bundleID: bundleID, locale: locale)
        }
    }

    private nonisolated static func runID(from userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo["veqral_run_id"] as? String, !value.isEmpty {
            return value
        }
        if let nested = userInfo["veqral"] as? [String: Any],
           let value = nested["veqral_run_id"] as? String,
           !value.isEmpty {
            return value
        }
        return nil
    }

    private func registerCategories() {
        let approve = UNNotificationAction(identifier: VeqralPushAction.approve, title: "承認", options: [])
        let reject = UNNotificationAction(identifier: VeqralPushAction.reject, title: "却下", options: [.destructive])
        let low = UNNotificationCategory(
            identifier: VeqralPushAction.lowApprovalCategory,
            actions: [approve, reject],
            intentIdentifiers: [],
            options: []
        )
        let high = UNNotificationCategory(
            identifier: VeqralPushAction.highApprovalCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let status = UNNotificationCategory(
            identifier: VeqralPushAction.statusCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([low, high, status])
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }
}

final class VeqralAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in VeqralPushNotificationCenter.shared.receiveToken(token) }
    }
}
