# Textway Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small original iOS 17+ SwiftUI reader that imports TXT/PDF files, stores local copies and progress, and reads them with installed system voices.

**Architecture:** A single `NavigationStack` presents a local library and pushes a reader by stable document ID. A Foundation-only local package owns Codable metadata and file copying so it can be tested with `swift test`; the iOS app owns PDFKit extraction, AVSpeechSynthesizer, and SwiftUI presentation.

**Tech Stack:** Swift 6.3, SwiftUI, Observation, AVFAudio, PDFKit, UniformTypeIdentifiers, Foundation, XCTest. No external dependencies.

**Spec:** Approved design in the coordinator thread; no separate design document was requested.

## Global Constraints

- Minimum OS: iOS 17.
- Import only user-selected `.txt` and `.pdf` files through `fileImporter`.
- Copy files into Application Support; persist only local Codable metadata and resume progress.
- Use installed `AVSpeechSynthesizer` voices; no server, account, cloud sync, OCR, or copied branding/assets.
- Keep controls accessible with Dynamic Type, VoiceOver labels/values, and 44pt hit targets.

---

### Task 1: Establish the failing core tests

**Files:**
- Create: `ReaderCore/Package.swift`
- Create: `ReaderCore/Sources/ReaderCore/ReaderCore.swift` (empty module placeholder only)
- Create: `ReaderCore/Tests/ReaderCoreTests/ReaderCoreTests.swift`

**Interfaces:**
- Tests define the required `DocumentKind`, `ReaderDocument`, `LocalDocumentStore`, and `DocumentText` behavior for later implementation.

- [x] **Step 1: Write tests for supported file kinds, clamped progress, and local-copy persistence.**
- [x] **Step 2: Run `swift test` from `ReaderCore/` and confirm the tests fail because the core behavior is absent.**

### Task 2: Implement the tested local core

**Files:**
- Modify: `ReaderCore/Sources/ReaderCore/ReaderCore.swift`
- Test: `ReaderCore/Tests/ReaderCoreTests/ReaderCoreTests.swift`

**Interfaces:**
- `DocumentKind(fileExtension:) -> DocumentKind?`
- `ReaderDocument.progress -> Double?`
- `LocalDocumentStore.importFile(at:)`, `documentURL(for:)`, `updateProgress(_:for:)`, and `remove(_:)`

- [x] **Step 1: Implement only the models, file copy, JSON metadata, progress clamping, and deletion needed by the failing tests.**
- [x] **Step 2: Run `swift test` and require all tests to pass.**

### Task 3: Add the iOS app shell and reader services

**Files:**
- Create: `TextwayReader.xcodeproj/project.pbxproj`
- Create: `TextwayReader.xcodeproj/xcshareddata/xcschemes/TextwayReader.xcscheme`
- Create: `TextwayReader/TextwayReaderApp.swift`
- Create: `TextwayReader/AppModel.swift`
- Create: `TextwayReader/SpeechService.swift`
- Create: `TextwayReader/DocumentTextLoader.swift`

**Interfaces:**
- `AppModel.documents`, `importDocument(url:)`, `document(id:)`, `saveProgress(offset:contentLength:for:)`
- `SpeechService.play(text:from:)`, `pause()`, `resume()`, `stop()`, `availableVoices`, and `rate`
- `DocumentTextLoader.load(from:kind:) throws -> String`

- [x] **Step 1: Wire the local package into the iOS app target and set iOS 17 deployment.**
- [x] **Step 2: Add the root observable model, PDFKit/TXT loader, and AVSpeechSynthesizer wrapper.**
- [x] **Step 3: Build the app target before adding views.**

### Task 4: Add the library, reader, import, and options UI

**Files:**
- Create: `TextwayReader/Views/RootView.swift`
- Create: `TextwayReader/Views/LibraryView.swift`
- Create: `TextwayReader/Views/ReaderView.swift`
- Create: `TextwayReader/Views/ReaderOptionsSheet.swift`

**Interfaces:**
- Library rows navigate with `LibraryRoute.reader(UUID)`.
- Reader owns loading/error view state and uses native `Picker`, `Slider`, `Button`, `List`, `ScrollView`, and `fileImporter`.

- [x] **Step 1: Add empty/loading/error/library states and TXT/PDF import with security-scoped access.**
- [x] **Step 2: Add reader text rendering, play/pause controls, progress, speed picker, and installed voice picker.**
- [x] **Step 3: Add VoiceOver labels, Dynamic Type-friendly text, and delete confirmation.**
- [x] **Step 4: Add deterministic previews for empty, populated, loading, and error states.**

### Task 5: Verify and report

**Files:**
- Modify: any source files required by compiler/test output.

- [x] **Step 1: Run `swift test` in `ReaderCore/`.**
- [x] **Step 2: Run a generic iOS Simulator build with `xcodebuild -project TextwayReader.xcodeproj -scheme TextwayReader -destination 'generic/platform=iOS Simulator' -configuration Debug build`.**
- [x] **Step 3: Attempt simulator discovery/build-run; all available simulators are shut down, so runtime launch/UI verification remains unverified.**
- [x] **Step 4: Re-read the approved requirements and report completed items and the exact runtime limitation to the coordinator.**
