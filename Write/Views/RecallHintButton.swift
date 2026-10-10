import SwiftUI

struct RecallHintButton: View {
    @ObservedObject var practiceState: PracticeState

    var body: some View {
        Button {
            practiceState.showNextHint()
        } label: {
            Label(title, systemImage: "eye")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(practiceState.nextHint == nil)
    }

    private var title: String {
        switch practiceState.nextHint {
        case .character?: return "Show character"
        case .strokes?: return "Show next stroke"
        default: return "No more hints"
        }
    }
}
