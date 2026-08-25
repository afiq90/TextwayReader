import ReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporting = false
    @State private var documentToDelete: ReaderDocument?

    var body: some View {
        Group {
            if appModel.documents.isEmpty {
                ContentUnavailableView(
                    "No documents",
                    systemImage: "doc.text",
                    description: Text("Import a text or PDF file to start reading.")
                )
            } else {
                List {
                    Section("Your library") {
                        ForEach(appModel.documents) { document in
                            DocumentLinkRow(document: document) {
                                documentToDelete = document
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporting = true
                } label: {
                    Label("Add document", systemImage: "plus")
                }
                .accessibilityHint("Choose a text or PDF file from Files")
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { appModel.importDocument(from: url) }
            case .failure(let error):
                appModel.errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Library error",
            isPresented: Binding(
                get: { appModel.errorMessage != nil },
                set: { if !$0 { appModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { appModel.errorMessage = nil }
        } message: {
            Text(appModel.errorMessage ?? "Unknown error")
        }
        .confirmationDialog(
            "Delete this document?",
            isPresented: Binding(
                get: { documentToDelete != nil },
                set: { if !$0 { documentToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let document = documentToDelete {
                    appModel.remove(document: document)
                }
                documentToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                documentToDelete.map {
                    "\"\($0.title)\" and its saved progress will be removed from this device."
                } ?? "The selected document will be removed from this device."
            )
        }
    }
}

private struct DocumentLinkRow: View {
    let document: ReaderDocument
    let onDelete: () -> Void

    var body: some View {
        NavigationLink(value: LibraryRoute.reader(document.id)) {
            DocumentRow(document: document)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct DocumentRow: View {
    let document: ReaderDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(document.title, systemImage: document.kind == .pdf ? "doc.richtext" : "doc.text")
                .font(.headline)
                .lineLimit(2)

            if let progress = document.progress {
                ProgressView(value: progress)
                    .accessibilityLabel("Reading progress")
                    .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
            } else {
                Text("Not started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
