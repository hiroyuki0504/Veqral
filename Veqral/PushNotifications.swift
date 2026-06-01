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

    static var pushUnavailableMessage: String {
        L10n.tr("Push requires paid Apple Developer Program.")
    }
}

@MainActor
final class VeqralPushNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = VeqralPushNotificationCenter()

    private weak var store: CommandCenterStore?
    private var cachedToken: (token: String, environment: String)?

    func attach(store: CommandCenterStore) {
        self.store = store
        guard VeqralFeatureFlags.pushNotificationsEnabled else {
            store.pushNotificationMessage = VeqralFeatureFlags.pushUnavailableMessage
            return
        }
        if let cachedToken {
            store.receiveRemoteNotificationToken(cachedToken.token, environment: cachedToken.environment)
        }
    }

    func register() {
        guard VeqralFeatureFlags.pushNotificationsEnabled else {
            store?.pushNotificationMessage = VeqralFeatureFlags.pushUnavailableMessage
            return
        }
        #if targetEnvironment(macCatalyst)
        return
        #else
        registerCategories()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                if let error {
                    self.store?.pushNotificationMessage = "\(L10n.tr("Push registration failed")): \(error.localizedDescription)"
                    return
                }
                guard granted else {
                    self.store?.pushNotificationMessage = L10n.tr("Push notifications are disabled.")
                    return
                }
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        #endif
    }

    func receiveToken(_ token: String) {
        guard VeqralFeatureFlags.pushNotificationsEnabled else { return }
        let environment = Self.apnsEnvironment
        cachedToken = (token, environment)
        store?.receiveRemoteNotificationToken(token, environment: environment)
    }

    func receiveRegistrationError(_ error: Error) {
        guard VeqralFeatureFlags.pushNotificationsEnabled else { return }
        store?.pushNotificationMessage = "\(L10n.tr("Push registration failed")): \(error.localizedDescription)"
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
        let actionIdentifier = response.actionIdentifier
        let userInfo = Self.pushPayload(from: response.notification.request.content.userInfo)
        Task { @MainActor in
            await self.store?.handlePushNotificationResponse(
                actionIdentifier: actionIdentifier,
                userInfo: userInfo
            )
        }
        completionHandler()
    }

    private nonisolated static func pushPayload(from userInfo: [AnyHashable: Any]) -> [String: String] {
        var payload: [String: String] = [:]
        for key in ["veqral_run_id", "veqral_event", "veqral_severity"] {
            if let value = userInfo[key] as? String {
                payload[key] = value
            }
        }
        if let nested = userInfo["veqral"] as? [String: Any] {
            for key in ["veqral_run_id", "veqral_event", "veqral_severity"] {
                if payload[key] == nil, let value = nested[key] as? String {
                    payload[key] = value
                }
            }
        }
        return payload
    }

    private func registerCategories() {
        let approve = UNNotificationAction(
            identifier: VeqralPushAction.approve,
            title: L10n.tr("Approve"),
            options: []
        )
        let reject = UNNotificationAction(
            identifier: VeqralPushAction.reject,
            title: L10n.tr("Reject"),
            options: [.destructive]
        )
        let lowApproval = UNNotificationCategory(
            identifier: VeqralPushAction.lowApprovalCategory,
            actions: [approve, reject],
            intentIdentifiers: [],
            options: []
        )
        let highApproval = UNNotificationCategory(
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
        UNUserNotificationCenter.current().setNotificationCategories([lowApproval, highApproval, status])
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
        Task { @MainActor in
            VeqralPushNotificationCenter.shared.receiveToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            VeqralPushNotificationCenter.shared.receiveRegistrationError(error)
        }
    }
}
