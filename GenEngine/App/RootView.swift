import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(GameAudioDirector.self) private var audio
    @State private var confirmation: ConfirmationAction?

    var body: some View {
        @Bindable var state = state
        ZStack {
            if state.hasProductAccess { GameShellView() }
            else { WelcomeView() }
        }
        .tint(GenEngineTheme.amber)
        // Une opération réussie doit se voir : elle n'allait jusqu'ici que dans `developerLog`.
        .successToast($state.successMessage)
        .confirmation($confirmation)
        // La partie occupe tout l'écran : elle n'est pas une destination de navigation
        // empilée sous une barre système, mais une prise de contrôle complète de l'écran.
        .fullScreenCover(isPresented: Binding(
            get: { state.session != nil },
            // Une fermeture venue du système ne clôt plus la session en silence : elle
            // demande la même confirmation que le bouton « Quitter l'histoire ».
            set: { if !$0 { requestSessionExit() } }
        )) {
            PlayerView().interactiveDismissDisabled()
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

    private func requestSessionExit() {
        guard state.session != nil else { return }
        confirmation = SessionExit.confirmation(state: state)
    }
}

/// Sortie de partie. Le geste abandonne le tour en cours sans reprise possible :
/// il porte donc la même confirmation d'où qu'il vienne.
enum SessionExit {
    @MainActor
    static func confirmation(state: AppState) -> ConfirmationAction {
        ConfirmationAction(
            title: "Quitter l’histoire ?",
            message: state.isDemoSession
                ? "La partie de démonstration en cours est abandonnée. Le chemin parcouru rejoint votre mémoire cumulée, mais la scène repartira du début."
                : "La session en cours est refermée. Vous pourrez la reprendre depuis « Reprendre le fil » dans la bibliothèque.",
            confirmLabel: "Quitter") { state.endSession() }
    }
}
