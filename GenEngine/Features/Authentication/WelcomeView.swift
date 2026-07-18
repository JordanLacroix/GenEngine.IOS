import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsLogin = false
    @State private var introIndex = 0
    @State private var introDismissed = false
    @AppStorage("genengine.intro.last-version") private var lastIntroVersion = 0

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
            if shouldShowIntroduction { introduction(introScenes[introIndex]) }
        }
        .navigationBarHidden(true)
    }

    private var introScenes: [IntroSceneDefinition] {
        (state.experience?.document.intro.scenes ?? []).sorted { $0.order < $1.order }
    }

    private var shouldShowIntroduction: Bool {
        guard let experience = state.experience,
              experience.document.intro.enabled,
              !introDismissed,
              introScenes.indices.contains(introIndex) else { return false }
        return experience.document.intro.displayPolicy == "EveryLaunch" || lastIntroVersion != experience.version
    }

    private func introduction(_ scene: IntroSceneDefinition) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let value = scene.imageUrl, let url = URL(string: value) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                    .ignoresSafeArea().opacity(0.55)
            }
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                EyebrowText(text: scene.eyebrow, color: GenEngineTheme.amber)
                Text(scene.title).font(.system(size: 54, weight: .bold, design: .serif)).foregroundStyle(GenEngineTheme.ivory)
                Text(scene.body).font(.title3).foregroundStyle(GenEngineTheme.ivory.opacity(0.82))
                HStack {
                    Button(introIndex == introScenes.count - 1 ? "Entrer dans le monde" : "Continuer") { advanceIntroduction() }.buttonStyle(PrimaryActionStyle())
                    if state.experience?.document.intro.allowSkip == true { Button("Passer") { finishIntroduction() }.buttonStyle(.bordered).tint(GenEngineTheme.ivory) }
                }
                Text("\(introIndex + 1) / \(introScenes.count)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }.padding(28).frame(maxWidth: 720)
        }.transition(.opacity)
    }

    private func advanceIntroduction() {
        if introIndex < introScenes.count - 1 { withAnimation { introIndex += 1 } }
        else { finishIntroduction() }
    }

    private func finishIntroduction() {
        if let version = state.experience?.version { lastIntroVersion = version }
        withAnimation { introDismissed = true }
    }
}
