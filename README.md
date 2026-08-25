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

## Run tests

From the project folder:

```bash
cd ReaderCore
swift test
```

## Scope

This is an original portfolio project. It has no accounts, cloud sync,
subscriptions, server-side voices, or OCR.
