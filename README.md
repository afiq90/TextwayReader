# Textway Reader

Textway Reader is a small iOS reading app that turns text documents into
spoken audio. It is an original portfolio MVP focused on one reliable flow:
import a document, listen to it, and continue later.

## Features

- Import `.txt` files and selectable-text PDFs from Files
- Extract PDF text with PDFKit
- Read text aloud with the device's installed voices
- Play, pause, resume, and replay completed documents
- Choose playback speed from 0.75× to 2.00×
- Save reading progress locally
- Accessible playback states, labels, hints, and Dynamic Type support
- Continue audio playback after supported interruptions while the process remains alive

## Technology

- Swift and SwiftUI
- Observation for app state
- PDFKit for PDF text extraction
- AVFAudio / `AVSpeechSynthesizer` for on-device text-to-speech
- Foundation and Codable for local document metadata and progress
- Local Swift package: `ReaderCore`

## Run the app

1. Open `TextwayReader.xcodeproj` in Xcode.
2. Select the `TextwayReader` scheme.
3. Choose an iOS 17+ Simulator or a connected device.
4. Build and run.
5. Tap **Add document** and choose a text file or selectable-text PDF.

Scanned image-only PDFs are not supported in this MVP because OCR is out of
scope.

## Reliability hardening

The latest slice hardens the existing reading flow without adding another
screen or changing the normal Play/Pause/Resume journey:

- `DocumentTextLoader` is an actor, so PDF/TXT extraction runs off the main
  actor and cancelled loads do not publish stale text.
- `SpeechService` owns a spoken `AVAudioSession` and the app declares the
  `audio` background mode.
- When iOS interrupts audio, playback pauses at a word boundary, preserves the
  live character offset, and exposes an `Interrupted` state with a `Resume`
  action.
- Playback resumes only when the interruption notification includes iOS's
  `shouldResume` hint; unrelated audio interruptions stay paused.
- Progress is persisted on interruption, pause, completion, backgrounding, and
  reader exit.
- Unit coverage now includes async document loading and interruption state;
  GitHub Actions runs the Fastlane build lane.

This is intentionally a reliability improvement rather than a new visible
feature. Background playback should feel unchanged when no interruption occurs.
The full interruption path is best verified on a physical device because the
Simulator does not consistently generate phone-call or Siri interruptions.
Background playback depends on the process remaining alive; app termination is
not restored.

CI intentionally runs only local package tests and an unsigned Simulator build.
Signing and TestFlight delivery stay outside this workflow.

## Verify locally

From the project folder:

```bash
swift test --package-path ReaderCore
fastlane build
xcodebuild test -project TextwayReader.xcodeproj -scheme TextwayReader \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -parallel-testing-enabled NO
```

## Scope

This is an original portfolio project. It has no accounts, cloud sync,
subscriptions, server-side voices, or OCR.
