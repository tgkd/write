import SwiftUI

struct PracticeModePicker: View {
    @ObservedObject var practiceState: PracticeState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Picker("Mode", selection: Binding(
            get: { practiceState.mode },
            set: { mode in
                practiceState.changeMode(mode)
                settings.practiceMode = mode
            }
        )) {
            ForEach(PracticeMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
