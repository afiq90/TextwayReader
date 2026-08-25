import Foundation
import XCTest
import ReaderCore
@testable import TextwayReader

final class DocumentTextLoaderTests: XCTestCase {
    func testLoadsUTF8TextThroughAsyncLoader() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextwayReaderLoaderTests-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        try Data("A quiet reading session.".utf8).write(to: url)

        let text = try await DocumentTextLoader.shared.load(from: url, kind: .text)

        XCTAssertEqual(text, "A quiet reading session.")
    }
}
