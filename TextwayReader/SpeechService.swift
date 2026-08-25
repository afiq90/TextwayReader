import AVFAudio
import Foundation
import Observation

@MainActor
@Observable
final class SpeechService: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()

    @ObservationIgnored
    private var utteranceStartOffset = 0

    var isSpeaking = false
    var isPaused = false
    var characterOffset = 0
    var textLength = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted { lhs, rhs in
                if lhs.language == rhs.language { return lhs.name < rhs.name }
                return lhs.language < rhs.language
            }
    }

    func play(text: String, from offset: Int, speed: Double, voiceIdentifier: String?) {
        stop()

        textLength = text.utf16.count
        characterOffset = min(max(0, offset), textLength)
        utteranceStartOffset = characterOffset
        guard characterOffset < textLength else { return }

        let start = String.Index(utf16Offset: characterOffset, in: text)
        let utterance = AVSpeechUtterance(string: String(text[start...]))
        utterance.rate = speechRate(for: speed)
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        if synthesizer.pauseSpeaking(at: .word) {
            isPaused = true
        }
    }

    func resume() {
        guard synthesizer.isPaused else { return }
        if synthesizer.continueSpeaking() {
            isPaused = false
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        characterOffset = min(textLength, utteranceStartOffset + characterRange.location + characterRange.length)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        characterOffset = textLength
        isSpeaking = false
        isPaused = false
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        isPaused = false
    }

    private func speechRate(for multiplier: Double) -> Float {
        let defaultRate = Double(AVSpeechUtteranceDefaultSpeechRate)
        let requestedRate = defaultRate * multiplier
        return Float(
            min(
                Double(AVSpeechUtteranceMaximumSpeechRate),
                max(Double(AVSpeechUtteranceMinimumSpeechRate), requestedRate)
            )
        )
    }
}
