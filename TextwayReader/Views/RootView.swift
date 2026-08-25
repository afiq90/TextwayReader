import SwiftUI

enum LibraryRoute: Hashable {
    case reader(UUID)
}

struct RootView: View {
    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: LibraryRoute.self) { route in
                    switch route {
                    case .reader(let documentID):
                        ReaderView(documentID: documentID)
                    }
                }
        }
        .tint(.blue)
    }
}

#Preview("Empty library") {
    RootView()
        .environment(AppModel())
        .environment(SpeechService())
}
