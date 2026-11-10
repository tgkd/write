import SwiftUI

struct WritingRejectionNotice: View {
    static let visibleDuration: Duration = .seconds(3)

    @ObservedObject var state: PracticeState
    @EnvironmentObject private var settings: AppSettings
    @State private var dismissedAttempt: Int?

    private var notice: String? {
        guard dismissedAttempt != state.attemptCount else {
            return nil
        }
        return settings.rejectionNotice(for: state.lastRejection)
    }

    var body: some View {
        ZStack {
            if let notice {
                Text(notice)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .transition(.opacity)
                    .accessibilityIdentifier("strokeNotice")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: notice)
        .task(id: state.attemptCount) {
            let attempt = state.attemptCount
            do {
                try await Task.sleep(for: Self.visibleDuration)
            } catch {
                return
            }
            dismissedAttempt = attempt
        }
    }
}
