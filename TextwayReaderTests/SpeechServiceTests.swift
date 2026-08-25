import AVFAudio
import XCTest
@testable import TextwayReader

@MainActor
final class SpeechServiceTests: XCTestCase {
    func testInterruptionBeginningPreservesPositionAndMarksPlaybackInterrupted() async {
        let service = SpeechService()
        service.isSpeaking = true
        service.characterOffset = 12

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        await Task.yield()

        XCTAssertTrue(service.isInterrupted)
        XCTAssertTrue(service.isPaused)
        XCTAssertEqual(service.characterOffset, 12)
    }

    func testInterruptionEndingWithoutResumeHintKeepsPlaybackPaused() async {
        let service = SpeechService()
        service.isSpeaking = true

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        await Task.yield()

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: 0
            ]
        )
        await Task.yield()

        XCTAssertTrue(service.isInterrupted)
        XCTAssertTrue(service.isPaused)
    }
}
