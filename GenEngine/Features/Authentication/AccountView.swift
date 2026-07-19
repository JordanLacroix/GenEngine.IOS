import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ZStack {
            StoryCanvas(accent: GenEngineTheme.verdigris)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        EyebrowText(text: state.isAuthenticated ? "Session active" : "Compte joueur", color: GenEngineTheme.verdigris)
                        Text(state.isAuthenticated ? state.access?.userName ?? "Compte connecté" : "Se connecter")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(GenEngineTheme.ivory)
                        Text(state.isAuthenticated
                             ? "Votre session est protégée dans le trousseau de l’iPad."
                             : "Connectez-vous sans quitter la démonstration pour retrouver vos histoires, vos rôles et votre progression.")
                            .foregroundStyle(GenEngineTheme.secondaryText)
                    }

                    if state.isAuthenticated { connectedCard }
                    else { loginCard }
                }
                .padding(22)
                .padding(.bottom, 24)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in min(availableWidth, 620) }
            }
        }
    }

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connecté en tant que \(state.access?.userName ?? "utilisateur")", systemImage: "checkmark.shield.fill")
                .font(.headline).foregroundStyle(GenEngineTheme.verdigris)
            if let roles = state.access?.roles, !roles.isEmpty {
                Text(roles.map(\.name).joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText)
            }
            Button { Task { await state.resetOnboarding() } } label: {
                Label("Rejouer le prologue", systemImage: "arrow.counterclockwise.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).tint(GenEngineTheme.amber)
            Button(role: .destructive) { state.signOut() } label: {
                Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22).glassPanel()
    }

    private var loginCard: some View {
        VStack(spacing: 14) {
            TextField(state.copy("auth.username", fallback: "Identifiant"), text: Binding(get: { state.userName }, set: { state.userName = $0 }))
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField(state.copy("auth.password", fallback: "Mot de passe"), text: Binding(get: { state.password }, set: { state.password = $0 }))
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
            Button { Task { await state.login() } } label: {
                HStack {
                    Label("Se connecter", systemImage: "person.badge.key.fill")
                    if state.isBusy { ProgressView() }
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(state.isBusy || state.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.password.isEmpty)
            Button("Créer un compte") { Task { await state.register() } }
                .disabled(state.isBusy)
            HStack { Rectangle().frame(height: 1); Text("OU").font(.caption); Rectangle().frame(height: 1) }
                .foregroundStyle(GenEngineTheme.secondaryText.opacity(0.5))
            Button { Task { await state.loginWithMicrosoft() } } label: {
                Label("Continuer avec Microsoft", systemImage: "building.2.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(GenEngineTheme.ivory)
            .disabled(state.isBusy)
            if state.isDemoAccess {
                Button { state.leaveDemo() } label: { Label("Revoir l’introduction", systemImage: "play.rectangle.on.rectangle") }
                Button(role: .destructive) { state.leaveDemo() } label: { Text("Quitter la démonstration") }
                    .disabled(state.isBusy)
            }
        }
        .padding(22).glassPanel()
    }
}
