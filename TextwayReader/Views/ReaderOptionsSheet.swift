import AVFAudio
import SwiftUI

struct ReaderOptionsSheet: View {
    let initialSpeed: Double
    let initialVoiceIdentifier: String?

    @Environment(AppModel.self) private var appModel
    @Environment(SpeechService.self) private var speech
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpeed: Double
    @State private var selectedVoiceIdentifier: String

    private let speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0]

    init(speed: Double, voiceIdentifier: String?) {
        self.initialSpeed = speed
        self.initialVoiceIdentifier = voiceIdentifier
        _selectedSpeed = State(initialValue: speed)
        _selectedVoiceIdentifier = State(initialValue: voiceIdentifier ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Picker("Speed", selection: $selectedSpeed) {
                        ForEach(speedOptions, id: \.self) { speed in
                            Text(speed.formatted(.number.precision(.fractionLength(2))))
                                .tag(speed)
                        }
                    }

                    Text("Speed: \(selectedSpeed.formatted(.number.precision(.fractionLength(2))))×")
                        .foregroundStyle(.secondary)
                }

                Section("Voice") {
                    Picker("Voice", selection: $selectedVoiceIdentifier) {
                        Text("System default").tag("")
                        ForEach(speech.availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice.identifier)
                        }
                    }
                }
            }
            .navigationTitle("Reader options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        appModel.setSpeed(selectedSpeed)
                        appModel.setVoice(
                            identifier: selectedVoiceIdentifier.isEmpty ? nil : selectedVoiceIdentifier
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
