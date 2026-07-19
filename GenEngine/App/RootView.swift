import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(GameAudioDirector.self) private var audio

    var body: some View {
        ZStack {
            if state.hasProductAccess { GameShellView() }
            else { WelcomeView() }
        }
        .tint(GenEngineTheme.amber)
        // La partie occupe tout l'écran : elle n'est pas une destination de navigation
        // empilée sous une barre système, mais une prise de contrôle complète de l'écran.
        .fullScreenCover(isPresented: Binding(
            get: { state.session != nil },
            set: { if !$0 { state.endSession() } }
        )) {
            PlayerView()
        }
        .alert(state.gameName, isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button(state.copy("action.close", fallback: "Fermer"), role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        // Une erreur est d'abord un message lisible ; le signal sonore ne fait que le doubler.
        .onChange(of: state.errorMessage) { _, message in if message != nil { audio.signal(.error) } }
        .onChange(of: state.hasProductAccess, initial: true) { _, hasAccess in
            if !hasAccess { audio.enter(.welcome) }
        }
    }
}
