import SwiftUI

/// Formulaire de connexion unique.
///
/// `WelcomeView` et `AccountView` en dupliquaient chacune une copie entière : deux
/// formulaires équivalents mais divergents (validation, libellés, bouton Microsoft),
/// donc deux comportements différents pour le même geste. Il n'en reste qu'un.
struct SignInPanel<Footer: View>: View {
    @Environment(AppState.self) private var state
    var loginSymbol: String?
    @ViewBuilder var footer: Footer

    private var canSubmit: Bool {
        !state.isBusy
            && !state.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !state.password.isEmpty
    }

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 14) {
            TextField(state.copy("auth.username", fallback: "Identifiant"), text: $state.userName)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField(state.copy("auth.password", fallback: "Mot de passe"), text: $state.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if canSubmit { Task { await state.login() } } }
            Button { Task { await state.login() } } label: {
                HStack {
                    if let loginSymbol { Label(state.copy("auth.login", fallback: "Se connecter"), systemImage: loginSymbol) }
                    else { Text(state.copy("auth.login", fallback: "Se connecter")) }
                    if state.isBusy { ProgressView() }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!canSubmit)
            Button(state.copy("auth.register", fallback: "Créer un compte")) { Task { await state.register() } }
                .disabled(!canSubmit)
            HStack { Rectangle().frame(height: 1); Text("OU").font(.caption); Rectangle().frame(height: 1) }
                .foregroundStyle(GenEngineTheme.secondaryText.opacity(0.5))
                .accessibilityHidden(true)
            Button { Task { await state.loginWithMicrosoft() } } label: {
                Label(state.copy("auth.microsoft", fallback: "Continuer avec Microsoft"), systemImage: "building.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(GenEngineTheme.ivory)
            .disabled(state.isBusy)
            footer
        }
        .padding(22)
        .glassPanel()
    }
}

extension SignInPanel where Footer == EmptyView {
    init(loginSymbol: String? = nil) {
        self.init(loginSymbol: loginSymbol) { EmptyView() }
    }
}
