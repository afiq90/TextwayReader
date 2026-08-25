import Foundation

public enum DocumentKind: String, Codable, Hashable, Sendable {
    case text
    case pdf

    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "txt": self = .text
        case "pdf": self = .pdf
        default: return nil
        }
    }

    public var fileExtension: String { rawValue == "text" ? "txt" : "pdf" }
}

public struct ReaderDocument: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let kind: DocumentKind
    public let filename: String
    public let importedAt: Date
    public var resumeOffset: Int
    public var contentLength: Int?

    public init(
        id: UUID,
        title: String,
        kind: DocumentKind,
        filename: String,
        importedAt: Date,
        resumeOffset: Int = 0,
        contentLength: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.filename = filename
        self.importedAt = importedAt
        self.resumeOffset = max(0, resumeOffset)
        self.contentLength = contentLength.map { max(0, $0) }
    }

    public var progress: Double? {
        guard let contentLength, contentLength > 0 else { return nil }
        return min(1, Double(max(0, resumeOffset)) / Double(contentLength))
    }

    public func playbackOffset(for contentLength: Int) -> Int {
        guard contentLength > 0 else { return 0 }
        let offset = min(max(0, resumeOffset), contentLength)
        return offset == contentLength ? 0 : offset
    }
}

public enum DocumentStoreError: LocalizedError {
    case unsupportedFileType(String)
    case missingSource(URL)
    case missingDocument(UUID)
    case corruptMetadata

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let pathExtension):
            return "Unsupported file type: \(pathExtension.isEmpty ? "unknown" : pathExtension)."
        case .missingSource(let url):
            return "The selected file could not be read: \(url.lastPathComponent)."
        case .missingDocument(let id):
            return "The document \(id.uuidString) is no longer in the library."
        case .corruptMetadata:
            return "The local library metadata could not be read."
        }
    }
}

public final class LocalDocumentStore {
    public private(set) var documents: [ReaderDocument]

    private let rootURL: URL
    private let metadataURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL
        self.metadataURL = rootURL.appendingPathComponent("library.json")
        self.fileManager = fileManager
        self.documents = []

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: metadataURL.path) else { return }

        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            documents = try decoder.decode([ReaderDocument].self, from: data)
        } catch {
            throw DocumentStoreError.corruptMetadata
        }
    }

    public static func applicationSupportStore(
        subdirectory: String = "TextwayReader"
    ) throws -> LocalDocumentStore {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try LocalDocumentStore(
            rootURL: applicationSupport.appendingPathComponent(subdirectory, isDirectory: true)
        )
    }

    public func documentURL(for document: ReaderDocument) -> URL {
        rootURL.appendingPathComponent(document.filename)
    }

    public func document(id: UUID) -> ReaderDocument? {
        documents.first { $0.id == id }
    }

    @discardableResult
    public func importFile(at sourceURL: URL) throws -> ReaderDocument {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DocumentStoreError.missingSource(sourceURL)
        }
        guard let kind = DocumentKind(fileExtension: sourceURL.pathExtension) else {
            throw DocumentStoreError.unsupportedFileType(sourceURL.pathExtension)
        }

        let id = UUID()
        let filename = "\(id.uuidString).\(kind.fileExtension)"
        let destinationURL = rootURL.appendingPathComponent(filename)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let document = ReaderDocument(
            id: id,
            title: title.isEmpty ? "Untitled" : title,
            kind: kind,
            filename: filename,
            importedAt: Date()
        )

        documents.insert(document, at: 0)
        do {
            try persist()
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            documents.removeAll { $0.id == id }
            throw error
        }
        return document
    }

    public func updateProgress(
        offset: Int,
        contentLength: Int,
        for documentID: UUID
    ) throws {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else {
            throw DocumentStoreError.missingDocument(documentID)
        }

        documents[index].resumeOffset = min(max(0, offset), max(0, contentLength))
        documents[index].contentLength = max(0, contentLength)
        try persist()
    }

    public func remove(_ document: ReaderDocument) throws {
        let fileURL = documentURL(for: document)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        documents.removeAll { $0.id == document.id }
        try persist()
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(documents).write(to: metadataURL, options: .atomic)
    }
}
