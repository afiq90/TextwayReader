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

    @ObservationIgnored
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    var isSpeaking = false
    var isPaused = false
    var isInterrupted = false
    var characterOffset = 0
    var textLength = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else {
                return
            }
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeRawValue: type, optionsRawValue: options)
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
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

        activateAudioSession()

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
            isInterrupted = false
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        isInterrupted = false
        deactivateAudioSession()
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
        isInterrupted = false
        deactivateAudioSession()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        isPaused = false
        isInterrupted = false
    }

    private func handleInterruption(typeRawValue: UInt, optionsRawValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeRawValue) else {
            return
        }

        switch type {
        case .began:
            guard isSpeaking else { return }
            _ = synthesizer.pauseSpeaking(at: .word)
            isPaused = true
            isInterrupted = true
        case .ended:
            guard isInterrupted else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRawValue)
            guard options.contains(.shouldResume) else { return }

            activateAudioSession()
            if synthesizer.continueSpeaking() {
                isPaused = false
                isInterrupted = false
            }
        @unknown default:
            break
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP, .allowAirPlay])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
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
