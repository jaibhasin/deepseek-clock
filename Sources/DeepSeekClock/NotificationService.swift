//
//  NotificationService.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ Sends the "off-peak just started" system notification.                       │
//  │                                                                              │
//  │ Why a protocol plus a concrete type?                                         │
//  │ The `ClockModel` only needs to know *that* a notification can be sent, not   │
//  │ how. Depending on the small `NotificationService` protocol keeps the model   │
//  │ free of the `UserNotifications` framework — which means tests can inject a   │
//  │ fake and never touch the real notification center.                           │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
//  HOW macOS NOTIFICATIONS WORK (the short version)
//  -------------------------------------------------
//  1. The app asks the user for permission once (`requestAuthorization`).
//  2. To deliver a notification you build a `UNNotificationRequest` — some
//     content (title/body) plus a trigger — and hand it to `UNUserNotificationCenter`.
//  3. `trigger: nil` means "deliver immediately".
//
//  Agent apps (`LSUIElement`, no Dock icon) can still post notifications; the
//  system just attributes them to the app's name.
//
import Foundation
import UserNotifications

/// Anything that can alert the user about pricing changes.
///
/// Kept deliberately tiny: one method to ask for permission, one to send the
/// off-peak alert. `ClockModel` depends on this protocol, not on Apple's
/// framework, so its logic stays unit-testable.
protocol NotificationService {
    /// Ask macOS for permission to show notifications. Safe to call repeatedly —
    /// the system only ever prompts the user once.
    func requestAuthorization()

    /// Tell the user that off-peak pricing has just begun.
    func notifyOffPeakStarted()
}

/// The real implementation backed by Apple's `UserNotifications` framework.
final class UserNotificationService: NotificationService {

    /// Stable identifier so a re-sent alert replaces the previous one instead of
    /// stacking duplicates in Notification Center.
    private static let offPeakRequestID = "deepseek.off-peak-started"

    func requestAuthorization() {
        // `UNUserNotificationCenter` requires a real app bundle. When the binary
        // is run bare (e.g. `swift run`) there is no bundle identifier and the
        // call would trap, so we quietly no-op in that case.
        guard Bundle.main.bundleIdentifier != nil else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            // The grant/deny result is not needed: if the user says no, the system
            // simply drops any notification we later post.
        }
    }

    func notifyOffPeakStarted() {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = "DeepSeek is now off-peak"
        content.body = "API pricing is currently 50% lower."
        content.sound = .default

        // `trigger: nil` = show it right away.
        let request = UNNotificationRequest(
            identifier: Self.offPeakRequestID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
