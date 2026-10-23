import SwiftUI

struct ReadingSpeakerButton: View {
    let text: String?
    var onPlay: () -> Void = {}

    @ObservedObject private var speaker = ReadingSpeaker.shared

    var body: some View {
        if let text, speaker.isAvailable {
            Button {
                speaker.speak(text)
                onPlay()
            } label: {
                Image(systemName: speaker.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Play reading")
            .accessibilityIdentifier("playReading")
            .onDisappear {
                speaker.stop()
            }
        }
    }
}
