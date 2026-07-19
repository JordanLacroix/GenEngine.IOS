import SwiftUI

/// Coque plein écran du jeu.
///
/// Il n'y a plus ni `TabView`, ni barre de navigation système : le contenu court bord à
/// bord et toute la navigation passe par une surcouche HUD. Sur iPhone (largeur compacte)
/// le HUD descend en barre basse ; sur iPad (largeur régulière) il devient un rail vertical
/// à gauche, conformément à la grammaire retenue pour la présentation immersive.
///
/// Accessibilité : le HUD est un conteneur voisin du contenu, jamais modal, jamais
/// `accessibilityHidden`. Le contenu conserve donc son ordre de lecture et le focus
/// VoiceOver circule librement entre les deux.
struct GameShellView: View {
    @Environment(AppState.self) private var state
    @Environment(GameAudioDirector.self) private var audio
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAudioPanel = false

    private var usesRail: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            destination
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Le HUD ne réserve pas de place : il flotte. Le contenu défilant, lui,
                // dégage la zone occupée pour rester atteignable en fin de course.
                //
                // Ces marges passent par `safeAreaInset` et non par `safeAreaPadding` :
                // `safeAreaPadding` agrandit réellement la vue de la marge demandée. La
                // pile la mesurait alors plus large que l'écran et centrait tout le monde
                // dedans — sur iPad, le HUD partait à moitié hors de l'écran par la gauche
                // (rail réduit à quelques pixels, « Le Diapason » amputé de son article)
                // pendant que le contenu débordait d'autant par la droite.
                // `safeAreaInset` réserve la bande *à l'intérieur* des limites : la vue
                // garde la taille de l'écran et le contenu défile bien sous le HUD.
                .safeAreaInset(edge: .top, spacing: 0) { hudClearance(height: HUDMetrics.topBarHeight) }
                .safeAreaInset(edge: .leading, spacing: 0) { hudClearance(width: usesRail ? HUDMetrics.railWidth : 0) }
                .safeAreaInset(edge: .bottom, spacing: 0) { hudClearance(height: usesRail ? 0 : HUDMetrics.bottomBarHeight) }
            hud
            if showsAudioPanel {
                HUDOverlayPanel(title: "Son", symbol: "waveform", onClose: { showsAudioPanel = false }) {
                    AudioSettingsPanel()
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showsAudioPanel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: state.activeTab)
        .onChange(of: state.activeTab, initial: true) { _, tab in audio.enter(tab.ambience) }
    }

    /// Bande vide réservant la place du HUD dans la zone sûre du contenu.
    /// Elle est décorative et transparente aux gestes : le HUD, lui, est une vue voisine
    /// posée par-dessus, et c'est lui qui reçoit les touches.
    private func hudClearance(width: CGFloat = 0, height: CGFloat = 0) -> some View {
        Color.clear
            .frame(width: width, height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var destination: some View {
        switch state.activeTab {
        case .home: HomeView()
        case .library: LibraryView()
        case .experience: PlayerExperienceViewScreen()
        case .studio: StudioView()
        case .administration: AdministrationView()
        case .account: AccountView()
        }
    }

    private var hud: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            if !usesRail { bottomBar }
        }
        .overlay(alignment: .leading) { if usesRail { rail } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Commandes du jeu")
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(state.gameName)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(GenEngineTheme.ivory)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            if state.isDemoAccess {
                // La barre haute doit loger le nom de l'application, l'étiquette d'état et
                // deux commandes. L'étiquette porte donc la forme courte ; VoiceOver, lui,
                // continue d'annoncer l'état complet.
                HUDBadge(symbol: "play.rectangle.on.rectangle", text: "Démo", tint: GenEngineTheme.verdigris)
                    .accessibilityLabel("Démonstration hors ligne")
            }
            Spacer(minLength: 0)
            if state.isBusy { ProgressView().tint(GenEngineTheme.amber).accessibilityLabel("Chargement en cours") }
            HUDButton(
                symbol: audio.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                title: audio.isEnabled ? "Couper le son" : "Activer le son",
                hint: "Le son reste facultatif : aucune information n’est portée par lui seul.") {
                    audio.isEnabled.toggle()
                }
            HUDButton(symbol: "waveform", title: "Réglages du son") { showsAudioPanel = true }
        }
        .padding(.horizontal, 20)
        .frame(height: HUDMetrics.topBarHeight - 14)
        .hudTopBarSurface()
    }

    private var bottomBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 6) {
                ForEach(state.destinations, id: \.self) { destination in
                    destinationButton(destination, showsTitle: true)
                }
            }
            .padding(6)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Un `ScrollView` horizontal reste gourmand sur son axe transverse : sans cette
        // contrainte il prenait toute la hauteur restante sous la barre haute. Son fond
        // `.ultraThinMaterial` recouvrait alors l'écran entier — le contenu apparaissait
        // flouté et illisible, et les onglets flottaient au milieu de l'écran.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 620)
        .hudSurface(cornerRadius: 24)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var rail: some View {
        VStack(spacing: 8) {
            ForEach(state.destinations, id: \.self) { destination in
                destinationButton(destination, showsTitle: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .frame(width: HUDMetrics.railWidth - 20)
        .hudSurface(cornerRadius: 26)
        .padding(.leading, 10)
        .padding(.top, HUDMetrics.topBarHeight)
        .padding(.bottom, 12)
    }

    private func destinationButton(_ destination: AppTab, showsTitle: Bool) -> some View {
        HUDButton(
            symbol: destination.symbol,
            title: label(for: destination),
            showsTitle: showsTitle,
            isSelected: state.activeTab == destination,
            hint: "Ouvrir \(label(for: destination))") {
                state.selectedTab = destination
            }
            .frame(minHeight: 54)
    }

    private func label(for destination: AppTab) -> String {
        switch destination {
        case .home: state.copy("nav.home", fallback: "Accueil")
        case .library: state.copy("nav.library", fallback: "Bibliothèque")
        case .experience: state.copy("nav.experience", fallback: "Mon univers")
        case .studio: state.copy("nav.studio", fallback: "Studio")
        case .administration: state.copy("nav.administration", fallback: "Administration")
        case .account: state.isAuthenticated ? state.copy("nav.account", fallback: "Compte") : "Se connecter"
        }
    }
}

/// Panneau de réglage du son, accessible depuis le HUD à tout moment.
/// Il annonce honnêtement l'absence de bande-son installée plutôt que de laisser croire
/// à une panne, et permet de couper le son intégralement.
struct AudioSettingsPanel: View {
    @Environment(GameAudioDirector.self) private var audio

    var body: some View {
        @Bindable var audio = audio
        VStack(alignment: .leading, spacing: 18) {
            Toggle(isOn: $audio.settings.isEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activer le son").font(.headline).foregroundStyle(GenEngineTheme.ivory)
                    Text("Le son est toujours facultatif. Aucune information n’est portée par lui seul : chaque signal double un retour visible à l’écran.")
                        .font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                }
            }
            .tint(GenEngineTheme.verdigris)

            ForEach(AudioLayer.allCases, id: \.self) { layer in
                VStack(alignment: .leading, spacing: 4) {
                    Text(layer.label).font(.subheadline.weight(.semibold)).foregroundStyle(GenEngineTheme.ivory)
                    Slider(
                        value: Binding(get: { audio.volume(for: layer) }, set: { audio.setVolume($0, for: layer) }),
                        in: 0...1) {
                            Text("Volume \(layer.label.lowercased())")
                        }
                        .tint(GenEngineTheme.amber)
                        .disabled(!audio.settings.isEnabled)
                        .accessibilityValue("\(Int(audio.volume(for: layer) * 100)) pour cent")
                }
            }

            if !audio.hasPlayableAssets {
                Label("Aucune bande-son n’est installée dans cette version : les réglages sont prêts, les pistes viendront avec le pack d’assets.", systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(GenEngineTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            #if DEBUG
            Text(audio.manifestStatus).font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
            #endif
        }
    }
}
