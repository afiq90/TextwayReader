import Foundation
import Observation
import ReaderCore

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored
    let store: LocalDocumentStore?

    var documents: [ReaderDocument]
    var errorMessage: String?
    var speedMultiplier: Double
    var voiceIdentifier: String?

    init(store: LocalDocumentStore? = nil) {
        if let store {
            self.store = store
            self.documents = store.documents
            self.errorMessage = nil
        } else {
            do {
                let store = try LocalDocumentStore.applicationSupportStore()
                self.store = store
                self.documents = store.documents
                self.errorMessage = nil
            } catch {
                self.store = nil
                self.documents = []
                self.errorMessage = error.localizedDescription
            }
        }

        let savedSpeed = UserDefaults.standard.double(forKey: "playbackSpeed")
        self.speedMultiplier = savedSpeed == 0 ? 1 : savedSpeed
        self.voiceIdentifier = UserDefaults.standard.string(forKey: "voiceIdentifier")
    }

    func importDocument(from url: URL) {
        guard let store else {
            errorMessage = "The local library is unavailable."
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        do {
            _ = try store.importFile(at: url)
            documents = store.documents
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func document(id: UUID) -> ReaderDocument? {
        documents.first { $0.id == id }
    }

    func documentURL(for document: ReaderDocument) -> URL? {
        store?.documentURL(for: document)
    }

    func saveProgress(offset: Int, contentLength: Int, for documentID: UUID) {
        do {
            try store?.updateProgress(
                offset: offset,
                contentLength: contentLength,
                for: documentID
            )
            documents = store?.documents ?? documents
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(document: ReaderDocument) {
        do {
            try store?.remove(document)
            documents = store?.documents ?? documents
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSpeed(_ value: Double) {
        speedMultiplier = value
        UserDefaults.standard.set(value, forKey: "playbackSpeed")
    }

    func setVoice(identifier: String?) {
        voiceIdentifier = identifier
        UserDefaults.standard.set(identifier, forKey: "voiceIdentifier")
    }
}
