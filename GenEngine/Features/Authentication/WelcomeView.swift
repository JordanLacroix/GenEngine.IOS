import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introIndex = 0
    @State private var introDismissed = false
    @State private var forcesIntroduction = false
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
                        Button { introIndex = 0; introDismissed = false; forcesIntroduction = true } label: {
                            Label("Revoir l’introduction", systemImage: "play.rectangle.on.rectangle")
                        }
                        .buttonStyle(.bordered).tint(GenEngineTheme.ivory)
                    }

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
                    VStack(spacing: 9) {
                        Text("Pas encore prêt à créer un compte ? Essayez une histoire complète, puis consultez le chemin parcouru.")
                            .font(.caption).multilineTextAlignment(.center).foregroundStyle(GenEngineTheme.secondaryText)
                        Button { withAnimation(reduceMotion ? nil : .snappy) { state.unlockDemo() } } label: {
                            Label(state.copy("demo.explore", fallback: "Lancer la démo"), systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(GenEngineTheme.verdigris)
                    }.frame(maxWidth: 440)
                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 24)
            }
            if shouldShowIntroduction { introduction(introScenes[introIndex]) }
        }
        .navigationBarHidden(true)
    }

    private var introScenes: [IntroSceneDefinition] {
        let configured = state.experience?.document.intro.scenes ?? []
        return (configured.isEmpty ? fallbackIntroScenes : configured).sorted { $0.order < $1.order }
    }

    private var fallbackIntroScenes: [IntroSceneDefinition] {
        [
            .init(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, eyebrow: "AVANT LE PREMIER CHOIX", title: "Chaque monde commence par une porte.", body: "Rien n’est écrit à votre place. Vos décisions dessinent la route et les souvenirs.", imageUrl: "IntroGateway", order: 1),
            .init(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, eyebrow: "UNE PRÉSENCE À VOS CÔTÉS", title: "Créez le familier qui apprendra votre manière d’avancer.", body: "Il conseille, éclaire un détail et reformule une énigme ; il ne choisit jamais pour vous.", imageUrl: "FamiliarAster", order: 2),
            .init(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, eyebrow: "LE PROLOGUE", title: "Votre première histoire vous remettra une clé.", body: "Terminez le tutoriel, relisez votre chemin, puis ouvrez la porte de votre choix.", imageUrl: "TutorialKey", order: 3)
        ]
    }

    private var shouldShowIntroduction: Bool {
        guard !introDismissed, introScenes.indices.contains(introIndex) else { return false }
        if forcesIntroduction { return true }
        guard let experience = state.experience else { return true }
        guard experience.document.intro.enabled else { return false }
        return experience.document.intro.displayPolicy == "EveryLaunch" || lastIntroVersion != experience.version
    }

    private func introduction(_ scene: IntroSceneDefinition) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let value = scene.imageUrl {
                if let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                        .ignoresSafeArea().opacity(0.55)
                } else {
                    Image(value).resizable().scaledToFill().ignoresSafeArea().opacity(0.55)
                }
            }
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                EyebrowText(text: scene.eyebrow, color: GenEngineTheme.amber)
                Text(scene.title).font(.system(size: 54, weight: .bold, design: .serif)).foregroundStyle(GenEngineTheme.ivory)
                Text(scene.body).font(.title3).foregroundStyle(GenEngineTheme.ivory.opacity(0.82))
                HStack {
                    Button(introIndex == introScenes.count - 1 ? "Entrer dans le monde" : "Continuer") { advanceIntroduction() }.buttonStyle(PrimaryActionStyle())
                    if state.experience?.document.intro.allowSkip != false { Button("Passer") { finishIntroduction() }.buttonStyle(.bordered).tint(GenEngineTheme.ivory) }
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
        forcesIntroduction = false
        withAnimation { introDismissed = true }
    }
}
