import Foundation
import PDFKit
import ReaderCore

enum DocumentTextLoaderError: LocalizedError {
    case unreadableText
    case noExtractablePDFText

    var errorDescription: String? {
        switch self {
        case .unreadableText:
            return "This text file could not be decoded as UTF-8."
        case .noExtractablePDFText:
            return "This PDF has no selectable text. Scanned PDFs are not supported yet."
        }
    }
}

enum DocumentTextLoader {
    static func load(from url: URL, kind: DocumentKind) throws -> String {
        switch kind {
        case .text:
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw DocumentTextLoaderError.unreadableText
            }
            return text
        case .pdf:
            guard let document = PDFDocument(url: url),
                  let text = document.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DocumentTextLoaderError.noExtractablePDFText
            }
            return text
        }
    }
}
