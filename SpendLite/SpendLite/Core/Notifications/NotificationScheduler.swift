//
//  NotificationScheduler.swift
//  SpendLite
//

import Foundation
import UserNotifications

/// The small part of UNUserNotificationCenter SpendLite uses, so tests can use a fake.
protocol NotificationScheduler: AnyObject {
    /// Asks for permission if not decided yet. Returns whether notifications are allowed.
    func requestAuthorization() async -> Bool
    /// True when the user turned notifications off for SpendLite in iOS Settings.
    func isDenied() async -> Bool
    /// Delivers now (`date == nil`) or at a date.
    func schedule(id: String, title: String, body: String, at date: Date?) async
    func cancel(ids: [String]) async
}

/// The real one.
final class SystemNotificationScheduler: NotificationScheduler {
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    func schedule(id: String, title: String, body: String, at date: Date?) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger: UNNotificationTrigger?
        if let date {
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        } else {
            trigger = nil // deliver now
        }
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

/// For tests, previews and UI tests: records what would have been sent.
final class FakeNotificationScheduler: NotificationScheduler {
    struct Sent: Equatable {
        let id: String
        let title: String
        let body: String
        let date: Date?
    }

    var grantsPermission: Bool
    private(set) var sent: [Sent] = []
    private(set) var pending: [String: Sent] = [:]

    init(grantsPermission: Bool = true) {
        self.grantsPermission = grantsPermission
    }

    func requestAuthorization() async -> Bool { grantsPermission }
    func isDenied() async -> Bool { !grantsPermission }

    func schedule(id: String, title: String, body: String, at date: Date?) async {
        let item = Sent(id: id, title: title, body: body, date: date)
        if date == nil { sent.append(item) } else { pending[id] = item }
    }

    func cancel(ids: [String]) async {
        ids.forEach { pending[$0] = nil }
    }
}
