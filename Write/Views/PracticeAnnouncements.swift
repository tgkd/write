import SwiftUI

struct PracticeAnnouncements: ViewModifier {
    @ObservedObject var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .onChange(of: practiceState.attemptCount) { count in
                guard count > 0 else {
                    return
                }
                let notice = settings.rejectionNotice(for: practiceState.lastRejection)
                AccessibilityAnnouncer.announce(notice ?? String(localized: "Stroke not accepted"))
            }
            .onChange(of: practiceState.isComplete) { isComplete in
                if isComplete {
                    AccessibilityAnnouncer.announce(String(localized: "Complete"))
                }
            }
    }
}

extension View {
    func practiceAnnouncements(for practiceState: PracticeState) -> some View {
        modifier(PracticeAnnouncements(practiceState: practiceState))
    }
}
