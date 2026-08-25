import ReaderCore
import SwiftUI

struct ReaderView: View {
    let documentID: UUID

    @Environment(AppModel.self) private var appModel
    @Environment(SpeechService.self) private var speech
    @State private var text = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showingOptions = false
    @State private var hasPlaybackSession = false

    @Environment(\.scenePhase) private var scenePhase

    private var document: ReaderDocument? { appModel.document(id: documentID) }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading document…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                ContentUnavailableView(
                    "Can’t read this document",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
            }
        }
        .navigationTitle(document?.title ?? "Reader")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingOptions = true
                } label: {
                    Label("Reader options", systemImage: "slider.horizontal.3")
                }
                .disabled(isLoading || text.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !text.isEmpty {
                PlayerBar(
                    isSpeaking: speech.isSpeaking,
                    isPaused: speech.isPaused,
                    isInterrupted: speech.isInterrupted,
                    isFinished: hasReachedEnd,
                    progress: currentProgress,
                    togglePlayback: togglePlayback
                )
            }
        }
        .task(id: documentID) {
            await loadDocument()
        }
        .sheet(isPresented: $showingOptions) {
            ReaderOptionsSheet(
                speed: appModel.speedMultiplier,
                voiceIdentifier: appModel.voiceIdentifier
            )
        }
        .onDisappear {
            saveProgress()
            speech.stop()
        }
        .onChange(of: speech.isSpeaking) { _, isSpeaking in
            if !isSpeaking { saveProgress() }
        }
        .onChange(of: speech.isInterrupted) { _, isInterrupted in
            if isInterrupted { saveProgress() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { saveProgress() }
        }
    }

    private var currentOffset: Int {
        guard !text.isEmpty else { return document?.resumeOffset ?? 0 }
        guard hasPlaybackSession else { return document?.resumeOffset ?? 0 }
        return min(max(0, speech.characterOffset), text.utf16.count)
    }

    private var currentProgress: Double? {
        guard !text.isEmpty else { return document?.progress }
        return min(1, Double(currentOffset) / Double(text.utf16.count))
    }

    private var hasReachedEnd: Bool {
        !text.isEmpty && !speech.isSpeaking && currentOffset >= text.utf16.count
    }

    private func loadDocument() async {
        isLoading = true
        loadError = nil
        hasPlaybackSession = false
        speech.stop()
        defer { isLoading = false }

        guard let document,
              let url = appModel.documentURL(for: document) else {
            loadError = "This document is no longer available in the local library."
            return
        }

        do {
            let loadedText = try await DocumentTextLoader.shared.load(from: url, kind: document.kind)
            try Task.checkCancellation()
            text = loadedText
            appModel.saveProgress(
                offset: min(document.resumeOffset, text.utf16.count),
                contentLength: text.utf16.count,
                for: documentID
            )
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func togglePlayback() {
        if speech.isSpeaking {
            if speech.isPaused {
                speech.resume()
            } else {
                speech.pause()
                saveProgress()
            }
            return
        }

        let startOffset: Int
        if hasReachedEnd {
            startOffset = 0
        } else if hasPlaybackSession {
            startOffset = currentOffset
        } else {
            startOffset = document?.playbackOffset(for: text.utf16.count) ?? 0
        }
        speech.play(
            text: text,
            from: startOffset,
            speed: appModel.speedMultiplier,
            voiceIdentifier: appModel.voiceIdentifier
        )
        hasPlaybackSession = true
    }

    private func saveProgress() {
        guard !text.isEmpty else { return }
        appModel.saveProgress(
            offset: currentOffset,
            contentLength: text.utf16.count,
            for: documentID
        )
    }
}

private struct PlayerBar: View {
    let isSpeaking: Bool
    let isPaused: Bool
    let isInterrupted: Bool
    let isFinished: Bool
    let progress: Double?
    let togglePlayback: () -> Void

    private var actionTitle: String {
        if isSpeaking && !isPaused { return "Pause" }
        if isInterrupted || isPaused { return "Resume" }
        if isFinished { return "Read again" }
        return "Play"
    }

    private var actionIcon: String {
        isSpeaking && !isPaused ? "pause.fill" : "play.fill"
    }

    private var statusTitle: String {
        if isSpeaking && !isPaused { return "Reading aloud" }
        if isInterrupted { return "Interrupted" }
        if isPaused { return "Paused" }
        if isFinished { return "Finished" }
        if let progress, progress > 0 { return "Ready to continue" }
        return "Ready to read"
    }

    var body: some View {
        VStack(spacing: 12) {
            if let progress {
                ProgressView(value: progress)
                    .accessibilityLabel("Reading progress")
                    .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
            }

            Text(statusTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: togglePlayback) {
                Label(actionTitle, systemImage: actionIcon)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint(
                isSpeaking && !isPaused
                    ? "Pauses reading"
                    : isInterrupted
                        ? "Resumes after the audio interruption"
                        : isPaused
                        ? "Continues from the saved position"
                        : isFinished
                            ? "Starts reading again from the beginning"
                            : "Reads this document aloud"
            )
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

#Preview("Reader") {
    ReaderView(documentID: UUID())
        .environment(AppModel())
        .environment(SpeechService())
}
