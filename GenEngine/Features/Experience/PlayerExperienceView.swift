import SwiftUI
import UniformTypeIdentifiers

/// Contenus de l'univers. La carte n'est pas un onglet : c'est l'état de repos de l'écran.
///
/// Ces cinq entrées formaient auparavant une seconde barre d'onglets, posée sous la barre
/// de navigation globale de la coque. Deux barres d'onglets empilées en bas d'écran ne
/// disent pas au joueur laquelle le déplace : les quatre panneaux sont devenus des actions
/// du bandeau haut, et la carte reste le fond permanent.
private enum UniverseSection: String, CaseIterable, Identifiable {
    case map, journal, companion, shop, help
    var id: String { rawValue }
    var title: String { switch self { case .map: "Carte"; case .journal: "Journal"; case .companion: "Compagnon"; case .shop: "Magasin"; case .help: "Aide" } }
    var symbol: String { switch self { case .map: "map.fill"; case .journal: "book.closed.fill"; case .companion: "sparkles"; case .shop: "bag.fill"; case .help: "questionmark.circle.fill" } }

    /// Les panneaux réellement ouvrables. `map` en est exclue : elle est déjà à l'écran.
    static var panels: [UniverseSection] { [.journal, .companion, .shop, .help] }
}

struct PlayerExperienceViewScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section: UniverseSection = .map
    @State private var doorPage = 0
    @State private var familiarID: UUID?
    @State private var form = "spark"
    @State private var tone = "Warm"
    @State private var writingStyle = "Socratic"
    @State private var accent = "amber"
    @State private var customName = ""
    @State private var helpLevel = 2
    @State private var frequency = 2
    @State private var proactive = true
    @State private var selectedCategoryID: UUID?
    /// Ouverture du panneau de porte, **distincte** de la sélection.
    ///
    /// Une porte reste sélectionnée sur la carte après refermeture du panneau : le joueur
    /// voit toujours où il en est. Confondre les deux états rendrait la fermeture
    /// destructrice, elle effacerait le repère qu'il vient de poser.
    @State private var showsDoorPanel = false
    @State private var assetPack = FamiliarAssetPackStore.load()
    @State private var showsAssetImporter = false
    @State private var showsKeyReward = false
    @State private var assetMessage: String?

    var body: some View {
        Group {
            if let bootstrap = state.playerBootstrap, bootstrap.nextAction == "ConfigureFamiliar" {
                familiarFirstRun
            } else if let bootstrap = state.playerBootstrap, let step = nextTutorialStep(bootstrap) {
                tutorialStory(step, bootstrap: bootstrap)
            } else {
                immersiveWorld
            }
        }
        .task { await state.loadPlatformContext(); await state.loadCatalog(); await state.loadJournal(); hydrateSelection() }
        .fileImporter(isPresented: $showsAssetImporter, allowedContentTypes: [.json]) { importAssetPack($0) }
        .fullScreenCover(isPresented: $showsKeyReward) { keyReward }
    }

    /// Monde immersif.
    ///
    /// Le décor passe par `sceneBackdrop` et non par une `Image` posée en frère de `ZStack`.
    /// Mesuré à l'écran sur iPad Pro 13" : `Image("WorldMap").resizable().scaledToFill()`
    /// en frère de pile impose sa taille intrinsèque au conteneur. L'asset étant en 3:2,
    /// dans une zone de 1236 × 906 il se mesurait 906 × 1,5 = **1359** de large — 123 de
    /// trop. La `ZStack` adoptait cette largeur, puis toute la coque se recentrait dedans :
    /// tout partait de 61,5 pt vers la gauche, hors de l'écran. D'où « Le Diapason » réduit
    /// à « apason » et les libellés du rail amputés (« …univers », « …othèque »). Les
    /// géométries rapportées par SwiftUI restaient justes, ce qui rendait le défaut
    /// trompeur : c'est l'ancêtre qui était trop large, pas les vues fautives.
    ///
    /// `sceneBackdrop` pose le décor en arrière-plan clippé, où il ne participe plus au
    /// calcul de mise en page — et court malgré tout bord à bord grâce à `ignoresSafeArea`.
    /// Monde immersif.
    ///
    /// Le décor passe par `sceneBackdrop` et non par une `Image` posée en frère de `ZStack`.
    /// Mesuré à l'écran sur iPad Pro 13" : `Image("WorldMap").resizable().scaledToFill()`
    /// en frère de pile impose sa taille intrinsèque au conteneur — elle se mesurait 1359 de
    /// large dans une zone de 1236. La `ZStack` adoptait cette largeur, puis toute la coque
    /// se recentrait dedans et partait d'une soixantaine de points vers la gauche, hors de
    /// l'écran : « Le Diapason » réduit à « apason » et libellés du rail amputés
    /// (« …univers », « …othèque »). Les géométries rapportées par SwiftUI restaient justes,
    /// ce qui rendait le défaut trompeur : c'est l'ancêtre qui était trop large, pas les
    /// vues qui paraissaient fautives.
    ///
    /// `frame(maxWidth:maxHeight:)` suivi de `clipped()` ne suffit pas — vérifié à l'écran,
    /// le débord persiste. Seul `sceneBackdrop` règle le cas : il pose le décor en
    /// arrière-plan clippé, où il ne participe plus au calcul de mise en page, tout en
    /// courant bord à bord grâce à `ignoresSafeArea`.
    private var immersiveWorld: some View {
        ZStack {
            worldDoors
            if section == .map {
                if showsDoorPanel { doorScenarioPanel }
            } else {
                sectionOverlay
            }
            gameHUD
        }
        // L'avance automatique dans les pages du catalogue vit ici, sur la carte, et non
        // dans le panneau : une porte ouverte puis refermée avant la fin du chargement
        // perdrait autrement la recherche en cours, et la rouvrir repartirait de zéro.
        // La clé est `selectedCategoryID`, jamais `doorPage` : changer de page de portes ne
        // change pas le contenu demandé au serveur, cela ne fait que montrer d'autres portes.
        //
        // La boucle s'arrête dès qu'une page n'apporte rien — fin de liste ou erreur
        // réseau — pour ne pas réessayer indéfiniment.
        .task(id: selectedCategoryID) {
            var loaded = state.publishedStories.count
            while PlayerExperiencePresentation.shouldRequestMoreScenarios(
                loadedForCategory: selectedScenarios.count,
                hasMoreCatalog: state.hasMorePublishedStories), !Task.isCancelled {
                await state.loadMorePublishedStories()
                guard state.publishedStories.count > loaded else { return }
                loaded = state.publishedStories.count
            }
        }
        .sceneBackdrop(
            image: "WorldMap",
            overlay: LinearGradient(
                colors: [.black.opacity(0.36), .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom))
    }

    /// Portes de la carte. Toutes les catégories visibles sont atteignables, sans plafond.
    ///
    /// Le `GeometryReader` **ne** déborde **plus** la zone sûre : elle est déjà étendue par
    /// `GameShellView` pour dégager le HUD global, et déborder revenait à poser des portes
    /// sous les barres. Les positions viennent de `doorPlacement`, calculé en points écran.
    private var worldDoors: some View {
        GeometryReader { proxy in
            let categories = visibleCategories
            let placement = PlayerExperiencePresentation.doorPlacement(
                total: categories.count, page: doorPage, viewport: proxy.size)
            ZStack(alignment: .bottom) {
                ForEach(Array(placement.range.enumerated()), id: \.element) { slot, index in
                    let category = categories[index]
                    door(category, isSelected: selectedCategoryID == category.id, size: placement.size)
                        .position(placement.positions[slot])
                }
                if placement.isPaginated {
                    doorPager(placement)
                        .position(x: proxy.size.width / 2, y: placement.field.maxY + 22)
                }
            }
            .onChange(of: placement.pageCount) { _, count in
                if doorPage >= count { doorPage = max(0, count - 1) }
            }
        }
    }

    /// Pagination des portes. Elle n'apparaît que lorsque l'écran ne peut pas toutes les
    /// porter lisiblement : mieux vaut une page suivante annoncée qu'un empilement muet.
    private func doorPager(_ placement: PlayerExperiencePresentation.DoorPlacement) -> some View {
        HStack(spacing: 14) {
            Button { doorPage = max(0, doorPage - 1) } label: {
                Image(systemName: "chevron.left").frame(width: HUDMetrics.minimumTarget, height: HUDMetrics.minimumTarget)
            }
            .disabled(placement.page == 0)
            .accessibilityLabel("Portes précédentes")
            Text("Portes \(placement.range.lowerBound + 1)–\(placement.range.upperBound) sur \(visibleCategories.count)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Button { doorPage = min(placement.pageCount - 1, doorPage + 1) } label: {
                Image(systemName: "chevron.right").frame(width: HUDMetrics.minimumTarget, height: HUDMetrics.minimumTarget)
            }
            .disabled(placement.page >= placement.pageCount - 1)
            .accessibilityLabel("Portes suivantes")
        }
        .padding(.horizontal, 10)
        .foregroundStyle(GenEngineTheme.ivory)
        .glassPanel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page \(placement.page + 1) sur \(placement.pageCount) de portes")
    }

    private func door(_ category: CategoryDefinition, isSelected: Bool, size: CGSize) -> some View {
        // La densité décide de la mise en page, pas un seuil sur le nombre de catégories :
        // c'est la taille réellement disponible qui dit ce qu'une porte peut afficher.
        let isCompact = size.width < 170
        let progress = PlayerExperiencePresentation.doorProgress(
            category: category,
            stories: state.stories,
            savedSessions: state.savedSessions)
        // Une porte s'ouvre : elle ne devient pas une vignette de catalogue. Le tap
        // sélectionne la porte *et* ouvre le panneau qui porte ses récits.
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) {
                selectedCategoryID = category.id
                section = .map
                showsDoorPanel = true
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isSelected ? "door.left.hand.open" : "door.left.hand.closed")
                    .font(.system(size: isCompact ? 28 : 42)).foregroundStyle(GenEngineTheme.amber)
                Text(category.name)
                    .font(.system(isCompact ? .subheadline : .headline, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("PORTE \(category.order)").font(.caption2).tracking(1.2)
                // La progression existait déjà dans la bibliothèque ; la carte l'ignorait.
                ProgressView(value: progress.fraction)
                    .tint(GenEngineTheme.verdigris)
                Text(progress.label)
                    .font(.caption2)
                    .foregroundStyle(GenEngineTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(isCompact ? 9 : 12)
            // La porte occupe exactement la place que la disposition lui a réservée :
            // c'est ce qui garantit qu'elle ne mord ni sur ses voisines, ni sur le cadre.
            .frame(width: size.width, height: size.height)
            .foregroundStyle(GenEngineTheme.ivory)
            .background(.black.opacity(isSelected ? 0.86 : 0.68), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? GenEngineTheme.amber : .white.opacity(0.18)))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .frame(minWidth: HUDMetrics.minimumTarget, minHeight: HUDMetrics.minimumTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Porte \(category.order), \(category.name). \(progress.label)")
        .accessibilityHint("Ouvrir cette porte et afficher ses récits")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Bandeau interne de l'univers.
    ///
    /// Il n'y a plus qu'une seule barre d'onglets à l'écran, celle de la coque. Ce bandeau
    /// n'est pas une navigation concurrente : il ouvre des panneaux superposés. Il se place
    /// dans la zone laissée libre par `HUDMetrics`, que `GameShellView` réserve déjà en
    /// étendant la zone sûre de la destination.
    private var gameHUD: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                // `HStack` et non `LazyHStack` : une pile paresseuse ne publie pas de
                // hauteur idéale fiable, et le `fixedSize` ci-dessous mesurait le bandeau
                // trop court — les libellés « Journal », « Tierce », « Magasin » et « Aide »
                // étaient rognés par le bord du panneau. Le bandeau compte quatre entrées :
                // la paresse n'y gagnait rien.
                HStack(spacing: 10) {
                    Label(state.playerExperience?.onboarding.status == "Completed" ? "Clé acquise" : "Clé à gagner", systemImage: "key.fill")
                        .font(.subheadline)
                    Text("\(state.playerExperience?.balance ?? 0) \(state.playerExperience?.currencyIcon ?? "✦")")
                        .fontWeight(.bold)
                        .foregroundStyle(GenEngineTheme.amber)
                        .accessibilityLabel("Solde : \(state.playerExperience?.balance ?? 0) \(state.playerExperience?.currencyName ?? "accords")")
                    ForEach(UniverseSection.panels) { item in
                        HUDButton(
                            symbol: item.symbol,
                            title: item == .companion && !customName.isEmpty ? customName : item.title,
                            showsTitle: true,
                            isSelected: section == item,
                            hint: "Ouvrir le panneau \(item.title)") {
                                withAnimation(.snappy) { section = item }
                            }
                    }
                }
                .padding(6)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Même correctif que la barre basse de la coque : un `ScrollView` horizontal
            // reste gourmand sur son axe transverse. Sans cette contrainte il prenait toute
            // la hauteur sous la barre haute, et son matériau `glassPanel` voilait une
            // colonne pleine hauteur de 620 pt — sur iPad, le tiers central de la carte
            // était occulté, portes comprises, et la rangée flottait au milieu du panneau.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 620)
            .foregroundStyle(GenEngineTheme.ivory)
            .glassPanel()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder private var sectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea().onTapGesture { section = .map }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { EyebrowText(text: section.title, color: GenEngineTheme.amber); Spacer(); Button { section = .map } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.buttonStyle(.bordered).buttonBorderShape(.circle).tint(GenEngineTheme.ivory).accessibilityLabel("Fermer ce panneau et revenir à la carte") }
                    switch section { case .journal: journal; case .companion: companion; case .shop: shop; case .help: help; case .map: EmptyView() }
                }.padding(24).frame(maxWidth: 900)
            }
            .safeAreaPadding(.top, 76).safeAreaPadding(.bottom, 82)
            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 70).padding(.vertical, 20)
        }
    }

    /// Panneau des récits d'une porte, ouvert au clic sur la porte.
    ///
    /// Il remplace le dock horizontal permanent, qui posait deux problèmes. Le premier était
    /// visuel et vérifié à l'écran, sur iPhone comme sur iPad et dans les deux orientations :
    /// les cartes de récit **recouvraient partiellement les cartes de porte**, masquant le
    /// numéro et la progression de celles qu'elles chevauchaient. Le second était de sens :
    /// un bandeau de catalogue collé en bas de la carte transformait les portes en simples
    /// filtres d'une liste toujours présente. Une porte se franchit, elle ne trie pas.
    ///
    /// Le panneau réutilise `HUDOverlayPanel`, la surface superposée que la coque emploie
    /// déjà : même matériau, même croix libellée, même comportement modal pour VoiceOver.
    /// La carte n'a pas besoin d'un second vocabulaire de panneau.
    ///
    /// Deux paginations coexistent sur cet écran et ne doivent pas être confondues :
    /// `doorPage` pagine l'**affichage** des portes quand le viewport ne peut pas toutes les
    /// porter — état local à la vue, aucun appel réseau — tandis que le catalogue pagine le
    /// **contenu** servi par `GET /catalog`. Une porte n'est pas une page de catalogue.
    @ViewBuilder private var doorScenarioPanel: some View {
        if let category = selectedCategory {
            let progress = PlayerExperiencePresentation.doorProgress(
                category: category,
                stories: state.stories,
                savedSessions: state.savedSessions)
            let scenarios = selectedScenarios
            HUDOverlayPanel(
                title: category.name,
                symbol: "door.left.hand.open",
                // Fermer ne perd que l'affichage : `selectedCategoryID` survit, la porte
                // reste marquée sélectionnée sur la carte.
                onClose: { withAnimation(reduceMotion ? nil : .snappy) { showsDoorPanel = false } }
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowText(text: "PORTE \(category.order)", color: GenEngineTheme.amber)
                        Text(category.description).font(.callout).foregroundStyle(GenEngineTheme.secondaryText)
                        ProgressView(value: progress.fraction).tint(GenEngineTheme.verdigris)
                        Text(progress.label).font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)

                    if scenarios.isEmpty {
                        Label(
                            PlayerExperiencePresentation.doorPanelEmptyLabel(
                                isLoading: state.isLoadingMoreCatalog,
                                hasMoreCatalog: state.hasMorePublishedStories),
                            systemImage: "hourglass")
                            .font(.callout)
                            .foregroundStyle(GenEngineTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // `LazyVStack` : le panneau ne construit pas la totalité du catalogue
                    // d'un coup pour n'en montrer que les premières cartes.
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(scenarios) { story in
                            doorScenarioCard(story)
                                // Fin du défilement : on demande la page suivante du
                                // catalogue. C'est la pagination du *contenu*, sans rapport
                                // avec `doorPage` qui ne pagine que l'affichage des portes.
                                .onAppear {
                                    guard story.id == scenarios.last?.id, state.hasMorePublishedStories else { return }
                                    Task { await state.loadMorePublishedStories() }
                                }
                        }
                    }

                    if state.isLoadingMoreCatalog {
                        ProgressView()
                            .tint(GenEngineTheme.amber)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Chargement des récits de cette porte")
                    } else if state.hasMorePublishedStories, !scenarios.isEmpty {
                        // Le défilement automatique ne suffit pas à VoiceOver ni au clavier :
                        // une commande explicite reste atteignable, comme dans la bibliothèque.
                        Button("Charger la suite") { Task { await state.loadMorePublishedStories() } }
                            .buttonStyle(.bordered)
                            .tint(GenEngineTheme.amber)
                            .frame(minWidth: HUDMetrics.minimumTarget, minHeight: HUDMetrics.minimumTarget)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func doorScenarioCard(_ story: StorySummary) -> some View {
        Button { Task { await state.open(story) } } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(story.eyebrow.uppercased()).font(.caption2).foregroundStyle(GenEngineTheme.amber)
                Text(story.title).font(.system(.headline, design: .serif))
                Text(story.synopsis).font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                Label("Entrer", systemImage: "arrow.right").font(.caption.bold())
            }
            .padding(14)
            // Pleine largeur du panneau : le nom et le synopsis se replient au lieu d'être
            // rognés, ce que la carte de 240 points du dock ne permettait pas en Dynamic
            // Type agrandi.
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: HUDMetrics.minimumTarget)
            .foregroundStyle(GenEngineTheme.ivory)
            .glassPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(story.title). \(story.synopsis)")
        .accessibilityHint("Entrer dans ce récit")
    }

    private var familiarFirstRun: some View {
        ScrollView { familiarCreation.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity, alignment: .trailing) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sceneBackdrop(
                image: "FamiliarTierce",
                overlay: LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            )
    }

    private func nextTutorialStep(_ bootstrap: PlayerBootstrapView) -> OnboardingStepDefinition? {
        bootstrap.tutorial.steps.sorted(by: { $0.order < $1.order }).first { !bootstrap.experience.onboarding.completedStepIds.contains($0.id) }
    }

    private func tutorialStory(_ step: OnboardingStepDefinition, bootstrap: PlayerBootstrapView) -> some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 16) {
                EyebrowText(text: "PROLOGUE · ÉTAPE \(step.order)", color: GenEngineTheme.amber)
                Text(step.title).font(.system(size: 48, weight: .bold, design: .serif)).foregroundStyle(GenEngineTheme.ivory)
                Text(step.body).font(.title3).foregroundStyle(GenEngineTheme.ivory.opacity(0.86))
                HStack(spacing: 14) {
                    Image(systemName: interactionSymbol(step.action)).font(.title).foregroundStyle(GenEngineTheme.amber)
                    VStack(alignment: .leading) { Text(step.action.isEmpty ? "Faire avancer l’histoire" : step.action).font(.headline); Text("Interaction paramétrée par ce scénario · \(step.target)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }
                    Spacer()
                    Button("Interagir") { Task { await completeTutorial(step, bootstrap: bootstrap) } }.buttonStyle(PrimaryActionStyle())
                }.padding(16).glassPanel()
                if bootstrap.tutorial.allowSkip { Button("Passer le prologue") { Task { await state.skipOnboarding() } }.foregroundStyle(GenEngineTheme.secondaryText) }
            }.padding(28).frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .sceneBackdrop(
            image: step.order.isMultiple(of: 2) ? "WorldMap" : "IntroGateway",
            overlay: LinearGradient(colors: [.clear, .black.opacity(0.96)], startPoint: .top, endPoint: .bottom)
        )
        .accessibilityElement(children: .contain)
    }

    private func completeTutorial(_ step: OnboardingStepDefinition, bootstrap: PlayerBootstrapView) async {
        let remaining = bootstrap.tutorial.steps.filter { !bootstrap.experience.onboarding.completedStepIds.contains($0.id) }
        await state.completeOnboardingStep(step)
        if remaining.count == 1 { showsKeyReward = true }
    }

    private func interactionSymbol(_ action: String) -> String {
        let value = action.lowercased()
        if value.contains("dialog") { return "quote.bubble.fill" }
        if value.contains("touch") || value.contains("tap") { return "hand.tap.fill" }
        return "sparkle.magnifyingglass"
    }

    private var selectedCategory: CategoryDefinition? {
        visibleCategories.first { $0.id == selectedCategoryID }
    }

    /// Récits de la porte sélectionnée. Le filtre lui-même vit dans
    /// `PlayerExperiencePresentation`, où il est testable sans monter de vue.
    private var selectedScenarios: [StorySummary] {
        PlayerExperiencePresentation.doorScenarios(category: selectedCategory, stories: state.stories)
    }

    private var visibleCategories: [CategoryDefinition] { (state.experience?.document.categories ?? []).filter(\.isVisible).sorted { $0.order < $1.order } }
    private var journal: some View {
        VStack(alignment: .leading, spacing: 18) {
            let entries = PlayerExperiencePresentation.uniqueJournalEntries(state.playerJournal?.items ?? state.playerExperience?.recentJournal ?? [])
            let masteries = PlayerExperiencePresentation.uniqueMasteries(state.playerExperience?.masteries ?? [])
            HStack { Label("Journal de votre parcours", systemImage: "book.pages.fill").font(.title2.bold()); Spacer(); Text("\(entries.count) trace\(entries.count > 1 ? "s" : "")").foregroundStyle(GenEngineTheme.amber) }.foregroundStyle(GenEngineTheme.ivory)
            ForEach(masteries) { mastery in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Histoire explorée").font(.headline); Spacer(); Text("\(mastery.masteryPercent)%").foregroundStyle(GenEngineTheme.amber) }
                    Text("\(mastery.nodeIds.count) scène(s) · \(mastery.choiceIds.count) choix · \(mastery.endingIds.count) fin(s)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                    ProgressView(value: Double(mastery.masteryPercent), total: 100).tint(GenEngineTheme.verdigris)
                    scenarioMap(for: mastery)
                }
                .padding(16)
                .glassPanel()
                .task(id: mastery.scenarioVersionId) { await state.loadScenarioStructure(for: mastery.scenarioVersionId) }
            }
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 14) {
                    Circle().fill(GenEngineTheme.ember).frame(width: 10, height: 10).shadow(color: GenEngineTheme.ember, radius: 8)
                    VStack(alignment: .leading, spacing: 5) {
                        EyebrowText(text: PlayerExperiencePresentation.journalTypeLabel(entry.type), color: GenEngineTheme.ember)
                        Text(entry.title).font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                        Text(entry.summary).foregroundStyle(GenEngineTheme.secondaryText)
                        Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                }.padding(.vertical, 8)
            }
        }
    }

    /// Carte réelle d'un scénario serveur, hors partie : topologie publiée par Play, couleurs
    /// issues de la seule mémoire cumulée. Un refus reste visible et n'est jamais remplacé
    /// par la fixture de démonstration.
    @ViewBuilder
    private func scenarioMap(for mastery: ScenarioMasteryView) -> some View {
        if let graph = state.questGraph(for: mastery) {
            QuestGraphView(
                graph: graph,
                title: "Carte du scénario",
                subtitle: "Structure complète du scénario, colorée par le cumul de vos parties.",
                showsCurrentRun: false)
        } else if let failure = state.scenarioStructureErrors[mastery.scenarioVersionId] {
            VStack(alignment: .leading, spacing: 10) {
                Label("Carte indisponible", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GenEngineTheme.ember)
                Text(failure).font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
                Button("Réessayer") { Task { await state.retryScenarioStructure(for: mastery.scenarioVersionId) } }
                    .buttonStyle(.bordered)
                    .tint(GenEngineTheme.amber)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        } else if state.isLoadingScenarioStructure(mastery.scenarioVersionId) {
            ProgressView().tint(GenEngineTheme.amber).accessibilityLabel("Chargement de la carte du scénario")
        }
    }

    private var companion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Votre compagnon", systemImage: "sparkles").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            if let definitions = state.experience?.document.familiars, let definition = definitions.first(where: { $0.id == familiarID }) ?? definitions.first {
                if definitions.count > 1 { Picker("Familier", selection: Binding(get: { familiarID ?? definition.id }, set: { familiarID = $0; hydrateDefinition($0) })) { ForEach(definitions) { Text($0.name).tag($0.id) } } }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 16) { companionPortrait(definition); assetPackCard }.frame(maxWidth: 390)
                        companionControls(definition)
                    }
                    VStack(spacing: 16) { companionPortrait(definition); assetPackCard; companionControls(definition) }
                }
            }
        }.padding(20).glassPanel()
    }

    private func companionControls(_ definition: FamiliarDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Son nom", text: $customName).textFieldStyle(.roundedBorder)
            Picker("Forme", selection: $form) { ForEach(definition.availableForms, id: \.self) { Text(PlayerExperiencePresentation.familiarOptionLabel($0)).tag($0) } }
            Picker("Personnalité", selection: $tone) { ForEach(definition.availableTones, id: \.self) { Text(PlayerExperiencePresentation.familiarOptionLabel($0)).tag($0) } }
            Stepper("Niveau d’aide : \(helpLevel)/5", value: $helpLevel, in: 0...5)
            Stepper("Fréquence d’intervention : \(frequency)/5", value: $frequency, in: 0...5)
            Toggle("Me proposer de l’aide au bon moment", isOn: $proactive)
            Button("Enregistrer les réglages") { Task { await state.saveFamiliar(.init(familiarId: definition.id, form: form, tone: tone, writingStyle: writingStyle, accent: accent, helpLevel: helpLevel, customName: customName, interventionFrequency: frequency, proactive: proactive)) } }
                .buttonStyle(PrimaryActionStyle()).disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isBusy)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var familiarCreation: some View {
        VStack(alignment: .leading, spacing: 18) {
            EyebrowText(text: "VOTRE PREMIER ALLIÉ", color: GenEngineTheme.amber)
            Text("Donnez une forme à la voix qui marchera avec vous.").font(.system(size: 48, weight: .bold, design: .serif)).foregroundStyle(GenEngineTheme.ivory)
            Text("Le familier peut suggérer et éclairer ; vos choix vous appartiennent toujours. Son pack visuel reste un simple asset local, sans propriété ni économie.").foregroundStyle(GenEngineTheme.secondaryText)
            companion
        }
    }

    private var assetPackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Pack visuel · \(assetPack.name)", systemImage: "shippingbox.fill").font(.headline).foregroundStyle(GenEngineTheme.verdigris)
            Text("\(assetPack.license) · \(assetPack.attribution)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            Button { showsAssetImporter = true } label: { Label("Charger un manifeste JSON", systemImage: "square.and.arrow.down") }.buttonStyle(.bordered).tint(GenEngineTheme.ivory)
            if let assetMessage { Text(assetMessage).font(.caption).foregroundStyle(GenEngineTheme.amber) }
        }.padding(14).background(GenEngineTheme.verdigris.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func companionPortrait(_ definition: FamiliarDefinition) -> some View {
        VStack(spacing: 10) {
            if assetPack.targetFamiliarId == nil || assetPack.targetFamiliarId == definition.id, let name = assetPack.bundledAssetName {
                Image(name).resizable().scaledToFill().frame(maxWidth: .infinity, minHeight: 300, maxHeight: 440).clipped().clipShape(RoundedRectangle(cornerRadius: 28))
            } else if assetPack.targetFamiliarId == nil || assetPack.targetFamiliarId == definition.id, let url = assetPack.portraitUrl {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView().tint(GenEngineTheme.amber) }
                    .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 440).clipped().clipShape(RoundedRectangle(cornerRadius: 28))
            } else if let value = definition.portraitUrl ?? definition.avatarUrl, let url = URL(string: value) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView().tint(GenEngineTheme.amber) }
                    .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 360).clipped().clipShape(RoundedRectangle(cornerRadius: 28))
            } else { Image(systemName: "sparkles").font(.system(size: 70)).foregroundStyle(GenEngineTheme.amber).frame(height: 220) }
            Text(customName.isEmpty ? definition.name : customName).font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
            Text(definition.description).multilineTextAlignment(.center).foregroundStyle(GenEngineTheme.secondaryText)
        }.frame(maxWidth: .infinity)
    }

    private func importAssetPack(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 1_000_000 else { throw FamiliarAssetPackError.invalidManifest }
            let pack = try JSONDecoder().decode(FamiliarAssetPack.self, from: data).validated()
            try FamiliarAssetPackStore.save(pack)
            assetPack = pack
            assetMessage = "Pack chargé. Seule la présentation locale du familier a changé."
        } catch { assetMessage = error.localizedDescription }
    }

    private func hydrateDefinition(_ id: UUID) {
        guard let definition = state.experience?.document.familiars.first(where: { $0.id == id }) else { return }
        form = definition.form; tone = definition.tone; writingStyle = definition.writingStyle; accent = definition.accent; helpLevel = definition.helpLevel; customName = definition.name
    }

    private var keyReward: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { EyebrowText(text: "PROLOGUE ACCOMPLI", color: GenEngineTheme.amber); Text("La clé des possibles est à vous.").font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory); Text("Elle ouvre n’importe quelle porte de la carte. Votre parcours et vos gains sont conservés dans le journal.").font(.title3).foregroundStyle(GenEngineTheme.ivory.opacity(0.84)); Label("1 clé universelle", systemImage: "key.fill").foregroundStyle(GenEngineTheme.amber); Button("Choisir une porte") { showsKeyReward = false; section = .map }.buttonStyle(PrimaryActionStyle()) }.padding(28).frame(maxWidth: 720)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sceneBackdrop(
            image: "TutorialKey",
            overlay: LinearGradient(colors: [.clear, .black.opacity(0.94)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var shop: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Magasin", systemImage: "bag.fill").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.experience?.document.economy.offers.filter(\.enabled) ?? []) { offer in
                HStack { VStack(alignment: .leading) { Text(offer.name).font(.headline); Text(offer.description).font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); if state.playerExperience?.ownedOfferIds.contains(offer.id) == true { Label("Acquis", systemImage: "checkmark.seal.fill").foregroundStyle(GenEngineTheme.verdigris) } else { Button("\(offer.price) \(state.playerExperience?.currencyIcon ?? "✦")") { Task { await state.purchase(offer) } }.buttonStyle(.borderedProminent).tint(GenEngineTheme.ember) } }.padding(16).glassPanel()
            }
        }.foregroundStyle(GenEngineTheme.ivory)
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Centre d’aide", systemImage: "questionmark.circle.fill").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.experience?.document.help.articles.filter(\.published) ?? []) { article in
                DisclosureGroup { Text(article.body).padding(.top, 8).foregroundStyle(GenEngineTheme.secondaryText) } label: { VStack(alignment: .leading) { Text(article.title).font(.headline); Text(article.summary).font(.caption).foregroundStyle(GenEngineTheme.secondaryText) } }.padding(16).glassPanel()
            }
            Text("Glossaire").font(.title3.bold()).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.experience?.document.help.glossary ?? []) { entry in HStack(alignment: .top) { Text(entry.term).fontWeight(.bold).frame(width: 120, alignment: .leading); Text(entry.definition).foregroundStyle(GenEngineTheme.secondaryText) }.padding(.vertical, 6) }
        }
    }

    private func hydrateSelection() {
        selectedCategoryID = selectedCategoryID ?? visibleCategories.first?.id
        guard let definition = state.playerExperience?.familiarDefinition ?? state.experience?.document.familiars.first else { return }
        let selected = state.playerExperience?.familiar
        familiarID = selected?.familiarId ?? definition.id; form = selected?.form ?? definition.form; tone = selected?.tone ?? definition.tone
        writingStyle = selected?.writingStyle ?? definition.writingStyle; accent = selected?.accent ?? definition.accent; helpLevel = selected?.helpLevel ?? definition.helpLevel
        customName = selected?.customName ?? definition.name; frequency = selected?.interventionFrequency ?? state.playerBootstrap?.assistant.defaultFrequency ?? 2; proactive = selected?.proactive ?? state.playerBootstrap?.assistant.proactive ?? true
    }
}
