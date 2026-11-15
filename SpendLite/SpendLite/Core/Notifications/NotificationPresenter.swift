//
//  NotificationPresenter.swift
//  SpendLite
//

import UserNotifications

/// Shows SpendLite's notifications as banners even while the app is open
/// (otherwise iOS hides them when the app is in the foreground).
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
