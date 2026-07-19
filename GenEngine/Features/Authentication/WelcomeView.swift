import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @Environment(GameAudioDirector.self) private var audio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introIndex = 0
    @State private var introDismissed = false
    @State private var forcesIntroduction = false
    @State private var showsServerSettings = false
    @State private var showsMenu = false
    @AppStorage("genengine.intro.last-version") private var lastIntroVersion = 0

    var body: some View {
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
                        // L'identité vient de la configuration, pas du moteur : le nom de
                        // l'application en surtitre, son accroche en titre. Sans amorce
                        // cliente joignable, on retombe sur les copies génériques.
                        EyebrowText(text: state.gameName)
                        Text(state.tagline ?? state.copy("welcome.title", fallback: "Entrez dans des mondes qui se souviennent de vous."))
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(GenEngineTheme.ivory)
                            .frame(maxWidth: .infinity)
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

                    // Formulaire unique, partagé avec `AccountView`.
                    SignInPanel()
                        .frame(maxWidth: 440)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    // La démonstration hors ligne n'existe que dans l'état anonyme.
                    if state.isDemoAvailable {
                        VStack(spacing: 9) {
                            Text("Pas encore prêt à créer un compte ? Essayez une histoire complète, puis consultez le chemin parcouru.")
                                .font(.caption).multilineTextAlignment(.center).foregroundStyle(GenEngineTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                            Button { withAnimation(reduceMotion ? nil : .snappy) { state.unlockDemo() } } label: {
                                Label(state.copy("demo.explore", fallback: "Lancer la démo"), systemImage: "play.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(GenEngineTheme.amber)
                        }.frame(maxWidth: 440)
                    }
                    Spacer(minLength: 44)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            // L'accueil anonyme porte sa propre barre haute : elle flotte au-dessus du
            // contenu et ne lui vole pas de place, mais le contenu doit dégager sa hauteur
            // pour ne pas venir se lire par-dessus l'horloge en fin de course.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: HUDMetrics.topBarHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if shouldShowIntroduction { introduction(introScenes[introIndex]) }
            else { welcomeMenu }
            if showsMenu {
                HUDOverlayPanel(title: "Menu", symbol: "line.3.horizontal", onClose: { showsMenu = false }) {
                    menuEntries
                }
            }
            if showsServerSettings {
                HUDOverlayPanel(title: "Paramètres du serveur", symbol: "server.rack", dismissesOnBackgroundTap: false, onClose: { showsServerSettings = false }) {
                    ServerSettingsPanel(endpoints: state.endpoints)
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showsMenu)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showsServerSettings)
    }

    /// Barre de commandes de l'état anonyme.
    ///
    /// Avant connexion il n'existait aucun menu : ni entrée de démonstration, ni accès aux
    /// réglages. Sur un appareil neuf, l'application ne pouvait donc viser que l'adresse
    /// compilée par défaut, sans aucun recours.
    private var welcomeMenu: some View {
        VStack {
            HStack(spacing: 8) {
                Spacer()
                HUDButton(
                    symbol: audio.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    title: audio.isEnabled ? "Couper le son" : "Activer le son") { audio.isEnabled.toggle() }
                HUDButton(symbol: "line.3.horizontal", title: "Ouvrir le menu") { showsMenu = true }
            }
            .padding(.horizontal, 20)
            .frame(height: HUDMetrics.topBarHeight - 14)
            .hudTopBarSurface()
            Spacer()
        }
    }

    private var menuEntries: some View {
        VStack(alignment: .leading, spacing: 14) {
            // La démonstration est déjà proposée sous le formulaire ; elle est aussi ici,
            // parce qu'un menu est l'endroit où l'on cherche une entrée d'application.
            if state.isDemoAvailable {
                Button {
                    showsMenu = false
                    withAnimation(reduceMotion ? nil : .snappy) { state.unlockDemo() }
                } label: {
                    Label(state.copy("demo.explore", fallback: "Lancer la démo"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(GenEngineTheme.amber)
                .frame(minHeight: HUDMetrics.minimumTarget)
                Text("Une histoire complète, hors ligne, sans compte et sans appel réseau.")
                    .font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }
            Button {
                showsMenu = false
                showsServerSettings = true
            } label: {
                Label("Paramètres du serveur", systemImage: "server.rack")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(GenEngineTheme.ivory)
            .frame(minHeight: HUDMetrics.minimumTarget)
            Text("Indiquez où sont installés les six services qui servent \(state.gameName), ensemble ou séparément.")
                .font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            Button {
                showsMenu = false
                introIndex = 0
                introDismissed = false
                forcesIntroduction = true
            } label: {
                Label("Revoir l’introduction", systemImage: "play.rectangle.on.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(GenEngineTheme.ivory)
            .frame(minHeight: HUDMetrics.minimumTarget)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        // Une scène sans image ne doit pas réserver la place de l'image absente.
        // `ViewThatFits` retient la version qui se referme sur son texte quand celui-ci
        // tient à l'écran, et ne bascule sur la version défilante que lorsqu'il déborde
        // — scène longue, Dynamic Type agrandi ou petit écran.
        ViewThatFits(in: .vertical) {
            introductionCard(scene, scrolls: false)
            introductionCard(scene, scrolls: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Le décor passe en `background` : une image `scaledToFill` placée en
        // frère de ZStack impose sa taille intrinsèque (l'asset carré 1254×1254
        // dépassait la hauteur de l'écran) et poussait les commandes hors cadre.
        .background { introductionBackdrop(scene) }
        .transition(.opacity)
    }

    @ViewBuilder
    private func introductionCard(_ scene: IntroSceneDefinition, scrolls: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Les commandes restent hors du ScrollView, donc toujours visibles.
            if scrolls {
                ScrollView {
                    introductionText(scene)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.bottom)
            } else {
                introductionText(scene)
            }

            introductionControls
        }
        .padding(28)
        .frame(maxWidth: 720)
    }

    private func introductionText(_ scene: IntroSceneDefinition) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            EyebrowText(text: scene.eyebrow, color: GenEngineTheme.amber)
            Text(scene.title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(GenEngineTheme.ivory)
                .fixedSize(horizontal: false, vertical: true)
            Text(scene.body)
                .font(.title3)
                .foregroundStyle(GenEngineTheme.ivory.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func introductionBackdrop(_ scene: IntroSceneDefinition) -> some View {
        ZStack {
            Color.black
            if let value = scene.imageUrl {
                Color.clear.overlay {
                    if let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                    } else {
                        Image(value).resizable().scaledToFill()
                    }
                }
                .clipped()
                .opacity(0.55)
            }
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var introductionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Les boutons passent en pile si la largeur disponible ne suffit plus.
            ViewThatFits(in: .horizontal) {
                HStack { introductionAdvanceButton; introductionSkipButton }
                VStack(alignment: .leading, spacing: 12) { introductionAdvanceButton; introductionSkipButton }
            }
            Text("\(introIndex + 1) / \(introScenes.count)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
        }
    }

    private var introductionAdvanceButton: some View {
        Button(introIndex == introScenes.count - 1 ? "Entrer dans le monde" : "Continuer") { advanceIntroduction() }
            .buttonStyle(PrimaryActionStyle())
    }

    @ViewBuilder
    private var introductionSkipButton: some View {
        if state.experience?.document.intro.allowSkip != false {
            Button("Passer") { finishIntroduction() }.buttonStyle(.bordered).tint(GenEngineTheme.ivory)
        }
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
