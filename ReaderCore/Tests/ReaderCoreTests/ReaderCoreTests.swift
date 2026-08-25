import Foundation
import XCTest
@testable import ReaderCore

final class ReaderCoreTests: XCTestCase {
    func testDocumentKindRecognizesOnlyPlainTextAndPDF() {
        XCTAssertEqual(DocumentKind(fileExtension: "TXT"), .text)
        XCTAssertEqual(DocumentKind(fileExtension: "pdf"), .pdf)
        XCTAssertNil(DocumentKind(fileExtension: "rtf"))
    }

    func testProgressClampsToDocumentLength() {
        let document = ReaderDocument(
            id: UUID(),
            title: "Notes",
            kind: .text,
            filename: "notes.txt",
            importedAt: Date(timeIntervalSince1970: 0),
            resumeOffset: 20,
            contentLength: 10
        )

        XCTAssertEqual(document.progress, 1)
    }

    func testPlaybackOffsetRestartsAfterTheDocumentIsComplete() {
        var document = ReaderDocument(
            id: UUID(),
            title: "Notes",
            kind: .text,
            filename: "notes.txt",
            importedAt: Date(timeIntervalSince1970: 0),
            resumeOffset: 4,
            contentLength: 10
        )

        XCTAssertEqual(document.playbackOffset(for: 10), 4)

        document.resumeOffset = 10
        XCTAssertEqual(document.playbackOffset(for: 10), 0)
    }

    func testImportCopiesFileAndPersistsProgress() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderCoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("Notes.txt")
        let libraryURL = root.appendingPathComponent("Library", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: source)

        let store = try LocalDocumentStore(rootURL: libraryURL)
        let document = try store.importFile(at: source)

        XCTAssertEqual(document.title, "Notes")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.documentURL(for: document).path))

        try store.updateProgress(offset: 2, contentLength: 5, for: document.id)
        let reloaded = try LocalDocumentStore(rootURL: libraryURL)

        XCTAssertEqual(reloaded.documents.first?.resumeOffset, 2)
        XCTAssertEqual(reloaded.documents.first?.progress, 0.4)
    }
}
