import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsLogin = false

    var body: some View {
        @Bindable var state = state
        ZStack {
            StoryCanvas()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 56)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 52, weight: .light))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(GenEngineTheme.amber, GenEngineTheme.ember)
                        .accessibilityHidden(true)
                    VStack(spacing: 14) {
                        EyebrowText(text: state.copy("welcome.eyebrow", fallback: "Vos choix. Votre histoire."))
                        Text(state.copy("welcome.title", fallback: "Entrez dans des mondes qui se souviennent de vous."))
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(GenEngineTheme.ivory)
                        Text(state.copy("welcome.subtitle", fallback: "Une nouvelle génération de récits interactifs."))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(GenEngineTheme.secondaryText)
                            .frame(maxWidth: 480)
                    }

                    if showsLogin {
                        VStack(spacing: 14) {
                            TextField(state.copy("auth.username", fallback: "Identifiant"), text: $state.userName)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            SecureField(state.copy("auth.password", fallback: "Mot de passe"), text: $state.password)
                                .textContentType(.password)
                                .textFieldStyle(.roundedBorder)
                            Button { Task { await state.login() } } label: {
                                HStack { Text(state.copy("auth.login", fallback: "Se connecter")); if state.isBusy { ProgressView() } }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryActionStyle())
                            .disabled(state.isBusy)
                            Button(state.copy("auth.register", fallback: "Créer un compte")) { Task { await state.register() } }
                                .disabled(state.isBusy)
                            HStack { Rectangle().frame(height: 1); Text("OU").font(.caption); Rectangle().frame(height: 1) }
                                .foregroundStyle(GenEngineTheme.secondaryText.opacity(0.5))
                            Button { Task { await state.loginWithMicrosoft() } } label: {
                                Label(state.copy("auth.microsoft", fallback: "Continuer avec Microsoft"), systemImage: "building.2.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(GenEngineTheme.ivory)
                            .disabled(state.isBusy)
                        }
                        .padding(22)
                        .frame(maxWidth: 440)
                        .glassPanel()
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else {
                        VStack(spacing: 14) {
                            Button {
                                withAnimation(reduceMotion ? nil : .snappy) { state.unlockDemo() }
                            } label: {
                                Label(state.copy("demo.explore", fallback: "Explorer la démo"), systemImage: "play.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryActionStyle())
                            Button(state.copy("auth.existingAccount", fallback: "J’ai déjà un compte")) {
                                withAnimation(reduceMotion ? nil : .snappy) { showsLogin = true }
                            }
                            .font(.headline)
                            .foregroundStyle(GenEngineTheme.ivory)
                        }
                        .frame(maxWidth: 360)
                    }
                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
    }
}
