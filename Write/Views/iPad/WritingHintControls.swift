import SwiftUI

struct WritingHintControls: View {
    @ObservedObject var state: PracticeState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            RecallHintButton(practiceState: state).accessibilityIdentifier("writing.hint")
            if !state.hidesCharacter {
                PracticeModelView(kanji: state.kanjiData, showsGrid: settings.showPracticeGrid)
                    .frame(width: 44, height: 44)
            }
        }
    }
}
