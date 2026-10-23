import AVFoundation
import Combine

@MainActor
final class ReadingSpeaker: NSObject, ObservableObject {
    static let shared = ReadingSpeaker()
    static let rate: Float = 0.42

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: ObjectIdentifier?
    private lazy var voice: AVSpeechSynthesisVoice? = Self.pickJapaneseVoice()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isAvailable: Bool {
        voice != nil
    }

    func speak(_ text: String) {
        guard let voice else {
            return
        }
        if synthesizer.isSpeaking {
            currentUtterance = nil
            synthesizer.stopSpeaking(at: .immediate)
        }
        activateSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Self.rate
        currentUtterance = ObjectIdentifier(utterance)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else {
            return
        }
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        guard id == currentUtterance else {
            return
        }
        currentUtterance = nil
        finish()
    }

    private func finish() {
        isSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    static func pickJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" && !isNovelty($0) }
        if let kyoko = voices.first(where: { $0.name.localizedCaseInsensitiveContains("Kyoko") }) {
            return kyoko
        }
        if let premium = voices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return voices.first
    }

    private static func isNovelty(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if #available(iOS 17.0, *) {
            return voice.voiceTraits.contains(.isNoveltyVoice)
        }
        return false
    }
}

extension ReadingSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.utteranceEnded(id)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.utteranceEnded(id)
        }
    }
}
