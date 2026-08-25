import Observation
import SwiftUI

@main
struct TextwayReaderApp: App {
    @State private var appModel = AppModel()
    @State private var speechService = SpeechService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(speechService)
        }
    }
}
