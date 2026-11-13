import SwiftUI
import UIKit

@MainActor
enum AccessibilityAnnouncer {
    static func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else {
            return
        }
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(message).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
