import SwiftUI

struct RecallHintButton: View {
    @ObservedObject var practiceState: PracticeState
    var isCompact = false

    var body: some View {
        Button {
            practiceState.showNextHint()
        } label: {
            Label(title, systemImage: "eye")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: isCompact ? nil : .infinity)
        .disabled(practiceState.nextHint == nil)
        .accessibilityInputLabels([Text(title), Text("Hint")])
    }

    private var title: String {
        switch practiceState.nextHint {
        case .character?: return String(localized: "Show character")
        case .strokes?: return String(localized: "Show next stroke")
        default: return String(localized: "No more hints")
        }
    }
}
