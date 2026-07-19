import SwiftUI

@main
struct GenEngineApp: App {
    @State private var state = AppState()
    @State private var audio = GameAudioDirector()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .environment(audio)
                .preferredColorScheme(.dark)
        }
    }
}
