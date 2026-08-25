# Reliable Reading Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Textway Reader session resilient to backgrounding and audio interruptions while demonstrating a small, testable concurrency and delivery workflow.

**Architecture:** Keep the current SwiftUI/Observation shell and `ReaderCore` persistence model. Move document extraction behind an actor so PDF/TXT parsing does not run on the main actor. Keep audio-session ownership in the existing `SpeechService`; it will configure `AVAudioSession`, observe interruptions, preserve the current offset, and expose the existing playback state plus an interruption state. Add only the test and CI plumbing needed to prove this slice.

**Tech Stack:** Swift 6, SwiftUI, Observation, PDFKit, AVFAudio (`AVSpeechSynthesizer`/`AVAudioSession`), XCTest, Fastlane, GitHub Actions, iOS 17+.

**Spec:** Approved plan in the conversation: “Reliable Reading Session” production-readiness slice for Textway Reader.

## Global Constraints

- Preserve the existing iOS 17+ deployment target and local-only TXT/PDF product scope.
- Do not add accounts, cloud sync, server voices, OCR, subscriptions, analytics, or a second app.
- Do not include external brand names, copied assets, screenshots, or protected content.
- Reuse the existing `SpeechService`, `ReaderView`, `ReaderCore`, and progress persistence instead of adding parallel abstractions.
- Background playback is supported only while the process remains alive; app termination is not promised.
- Keep signing/TestFlight out of CI; CI only runs tests and an unsigned Simulator build.

---

### Task 1: Establish the test target and baseline

**Files:**
- Create: `TextwayReaderTests/SpeechServiceTests.swift`
- Modify: `TextwayReader.xcodeproj/project.pbxproj`
- Modify: `TextwayReader.xcodeproj/xcshareddata/xcschemes/TextwayReader.xcscheme`

**Interfaces:**
- Consumes: current `SpeechService` state and `AVAudioSession.interruptionNotification`.
- Produces: a testable `TextwayReaderTests` target that can run with `xcodebuild test`.

- [x] **Step 1: Write the failing tests** for the interruption state contract: an interruption beginning marks the service interrupted and paused, and an interruption ending without a resume hint keeps it paused.
- [x] **Step 2: Run the new tests** with `xcodebuild test` and confirm the staged continuation fails before the implementation is green.
- [x] **Step 3: Add the minimal Xcode test target wiring** and `@testable import TextwayReader` test file.
- [x] **Step 4: Run the tests again** and confirm the test target compiles and the tests pass after the interruption fix.

### Task 2: Move document extraction off the main actor

**Files:**
- Modify: `TextwayReader/DocumentTextLoader.swift`
- Modify: `TextwayReader/Views/ReaderView.swift`
- Modify: `TextwayReaderTests/DocumentTextLoaderTests.swift`

**Interfaces:**
- Consumes: `DocumentKind`, a security-scoped document URL, and the existing TXT/PDF extraction errors.
- Produces: `DocumentTextLoader.shared.load(from:kind:) async throws -> String`.

- [x] **Step 1: Write the failing loader test** that creates a temporary UTF-8 TXT file and awaits `DocumentTextLoader.shared.load(from:kind:)`.
- [x] **Step 2: Run the focused test** and confirm the staged continuation fails before the implementation is green.
- [x] **Step 3: Convert `DocumentTextLoader` into a small actor** with the async `load` method; keep PDFKit and UTF-8 validation in that actor and do not add a dependency.
- [x] **Step 4: Update `ReaderView.loadDocument()`** to await the loader, respect task cancellation, and preserve the existing progress save/error states.
- [x] **Step 5: Run the focused loader test and the full test target** and confirm they pass.

### Task 3: Make speech playback interruption-safe

**Files:**
- Modify: `TextwayReader/SpeechService.swift`
- Modify: `TextwayReader/Views/ReaderView.swift`
- Modify: `TextwayReader.xcodeproj/project.pbxproj`
- Modify: `TextwayReaderTests/SpeechServiceTests.swift`

**Interfaces:**
- Consumes: `AVAudioSession` and its interruption notifications.
- Produces: `SpeechService.isInterrupted`, deterministic pause/resume behaviour, and the existing `ReaderView` progress persistence.

- [x] **Step 1: Extend the failing tests** to post interruption notifications and assert the service preserves its offset, reports interruption, and only resumes when the system supplies the resume hint.
- [x] **Step 2: Run the focused tests** and confirm the new assertions fail before the interruption implementation is green.
- [x] **Step 3: Configure `AVAudioSession`** as spoken playback and activate it immediately before speaking.
- [x] **Step 4: Observe interruption notifications** on the main actor; pause at a word boundary, preserve `characterOffset`, set `isInterrupted`, and clear that state on a successful resume. Deactivate the session only on an explicit stop/finish.
- [x] **Step 5: Update `ReaderView` and `PlayerBar`** to show “Interrupted” and offer “Resume”, save progress on interruption/background, and keep navigation-away stop behaviour.
- [x] **Step 6: Add the `audio` background mode** to the generated Info.plist settings for Debug and Release.
- [x] **Step 7: Run the focused and full tests** and confirm they pass.

### Task 4: Add minimal delivery proof

**Files:**
- Create: `fastlane/Fastfile`
- Create: `.github/workflows/ios.yml`
- Modify: `README.md`

**Interfaces:**
- Consumes: the existing `ReaderCore` package and `TextwayReader` Xcode scheme.
- Produces: `fastlane build` and a CI job that runs the same test/build commands without signing.

- [x] **Step 1: Add one Fastlane `build` lane** that runs `swift test` in `ReaderCore` and an unsigned generic iOS Simulator `xcodebuild`.
- [x] **Step 2: Add one GitHub Actions workflow** on macOS that invokes the lane or equivalent commands for pushes and pull requests.
- [x] **Step 3: Document the reliability slice, architecture trade-offs, and local/CI verification commands in `README.md`.
- [x] **Step 4: Run the lane locally** (when Fastlane is installed) and record the fallback command if it is unavailable.

### Task 5: Verify and hand off

**Files:**
- Modify: `docs/superpowers/plans/2026-08-25-reliable-reading-session.md`

- [x] **Step 1: Run `swift test`** in `ReaderCore` and record the result.
- [x] **Step 2: Run `xcodebuild test`** for the iOS Simulator test target and record the result.
- [x] **Step 3: Run the generic Simulator build** with arm64 settings and record the result.
- [ ] **Step 4: Launch a booted Simulator** and manually verify import, playback, backgrounding, interruption/resume, completion, and saved progress.
- [x] **Step 5: Inspect `git diff` and `git status`** for generated files, unrelated edits, or prohibited branding, then update this checklist.
- [x] **Step 6: Commit and push the verified changes** to `origin/main` with a focused commit message.

## Verification notes

- The continuation started with the staged tests and implementation already in
  the working tree. The first arm64 `xcodebuild test` run reproduced Swift 6
  compiler failures in `SpeechService`: a non-Sendable observer token accessed
  from `deinit`, and a non-Sendable `Notification` captured into a main-actor
  task. The observer token is now explicitly unsafe only across `deinit`, and
  the task receives the parsed `UInt` payload instead of the notification.
- `swift test --package-path ReaderCore`: 4 tests passed.
- `xcodebuild test ... ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`: 3 iOS tests passed.
- The unsigned generic Simulator build with the same arm64 settings passed.
- Fastlane is not installed locally (`fastlane` was not found). The Fastfile
  parses with `ruby -c`, and its package-test and unsigned-build commands were
  run separately with the results above.
- No Simulator was booted; all available iOS 26.5 devices were shutdown, so
  manual UI verification remains pending.
