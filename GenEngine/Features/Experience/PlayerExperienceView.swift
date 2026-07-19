import SwiftUI
import UniformTypeIdentifiers

private enum UniverseSection: String, CaseIterable, Identifiable {
    case map, journal, companion, shop, help
    var id: String { rawValue }
    var title: String { switch self { case .map: "Carte"; case .journal: "Journal"; case .companion: "Compagnon"; case .shop: "Magasin"; case .help: "Aide" } }
    var symbol: String { switch self { case .map: "map.fill"; case .journal: "book.closed.fill"; case .companion: "sparkles"; case .shop: "bag.fill"; case .help: "questionmark.circle.fill" } }
}

struct PlayerExperienceViewScreen: View {
    @Environment(AppState.self) private var state
    @State private var section: UniverseSection = .map
    @State private var search = ""
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

    private var immersiveWorld: some View {
        ZStack {
            Image("WorldMap").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.36), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            worldDoors
            if section == .map { storyDock }
            else { sectionOverlay }
            gameHUD
        }
        .background(Color.black)
    }

    private var worldDoors: some View {
        GeometryReader { proxy in
            ForEach(Array(visibleCategories.prefix(5).enumerated()), id: \.element.id) { index, category in
                let anchors = PlayerExperiencePresentation.doorAnchors(for: proxy.size)
                let point = PlayerExperiencePresentation.projectMapPoint(anchors[index % anchors.count], into: proxy.size)
                Button { withAnimation(.snappy) { selectedCategoryID = category.id; section = .map } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selectedCategoryID == category.id ? "door.left.hand.open" : "door.left.hand.closed")
                            .font(.system(size: 42)).foregroundStyle(GenEngineTheme.amber)
                        Text(category.name).font(.system(.headline, design: .serif)).multilineTextAlignment(.center)
                        Text("PORTE \(category.order)").font(.caption2).tracking(1.2)
                    }
                    .padding(12).foregroundStyle(GenEngineTheme.ivory)
                    .background(.black.opacity(selectedCategoryID == category.id ? 0.82 : 0.64), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedCategoryID == category.id ? GenEngineTheme.amber : .white.opacity(0.18)))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                }
                .buttonStyle(.plain)
                .position(point)
                .accessibilityHint("Afficher les histoires de cette région")
            }
        }.ignoresSafeArea()
    }

    private var gameHUD: some View {
        VStack {
            HStack(spacing: 12) {
                Spacer()
                Label(state.playerExperience?.onboarding.status == "Completed" ? "Clé acquise" : "Clé à gagner", systemImage: "key.fill")
                Text("\(state.playerExperience?.balance ?? 0) \(state.playerExperience?.currencyIcon ?? "✦")").fontWeight(.bold).foregroundStyle(GenEngineTheme.amber)
                Button { section = .companion } label: { Label(customName.isEmpty ? "Compagnon" : customName, systemImage: "sparkles") }
            }
            .font(.subheadline).foregroundStyle(GenEngineTheme.ivory).padding(10).glassPanel()
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UniverseSection.allCases) { item in
                        Button { withAnimation(.snappy) { section = item } } label: { Label(item.title, systemImage: item.symbol).padding(.horizontal, 12).frame(minHeight: 48) }
                            .buttonStyle(.plain).foregroundStyle(section == item ? GenEngineTheme.amber : GenEngineTheme.ivory)
                            .background(section == item ? GenEngineTheme.ember.opacity(0.18) : Color.clear, in: Capsule())
                    }
                }.padding(5).glassPanel()
            }.frame(maxWidth: 620)
        }
        .padding(16)
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

    private var storyDock: some View {
        VStack { Spacer(); HStack(alignment: .bottom, spacing: 16) {
            if let category = visibleCategories.first(where: { $0.id == selectedCategoryID }) {
                VStack(alignment: .leading, spacing: 5) { EyebrowText(text: "PORTE \(category.order)", color: GenEngineTheme.amber); Text(category.name).font(.system(.title2, design: .serif, weight: .bold)); Text(category.description).font(.caption).foregroundStyle(GenEngineTheme.secondaryText).lineLimit(2) }.frame(width: 230, alignment: .leading)
            }
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(filteredStories) { story in Button { Task { await state.open(story) } } label: { VStack(alignment: .leading, spacing: 7) { Text(story.eyebrow.uppercased()).font(.caption2).foregroundStyle(GenEngineTheme.amber); Text(story.title).font(.system(.headline, design: .serif)); Text(story.synopsis).font(.caption).foregroundStyle(GenEngineTheme.secondaryText).lineLimit(2); Label("Entrer", systemImage: "arrow.right").font(.caption.bold()) }.padding(14).frame(width: 240, alignment: .leading).glassPanel() }.buttonStyle(.plain) } } }
        }.foregroundStyle(GenEngineTheme.ivory).padding(16).padding(.bottom, 64) }
    }

    private var familiarFirstRun: some View {
        ScrollView { familiarCreation.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity, alignment: .trailing) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sceneBackdrop(
                image: "FamiliarAster",
                overlay: LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            )
    }

    private var keyStatus: some View {
        let hasKey = state.playerExperience?.onboarding.status == "Completed"
        return HStack { Label(hasKey ? "Clé du prologue acquise" : "Prologue passé · clé à gagner", systemImage: hasKey ? "key.fill" : "key.horizontal").foregroundStyle(GenEngineTheme.amber); Spacer(); Text(hasKey ? "Toutes les portes sont ouvertes" : "Rejouez le prologue depuis Compte").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }
            .padding(14).glassPanel()
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                EyebrowText(text: state.gameName)
                Text("Un monde. Tous vos chemins.").font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                Text("Explorez, retrouvez vos accomplissements et poursuivez les branches encore inconnues.").foregroundStyle(GenEngineTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(state.playerExperience?.balance ?? 0)").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("\(state.playerExperience?.currencyIcon ?? "✦") \(state.playerExperience?.currencyName ?? "Braises")").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }.foregroundStyle(GenEngineTheme.amber)
        }
    }

    private var sectionPicker: some View {
        Picker("Votre univers", selection: $section) {
            ForEach(UniverseSection.allCases) { item in Label(item.title, systemImage: item.symbol).tag(item) }
        }
        .pickerStyle(.segmented)
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

    private var map: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) { Label("La carte des portes", systemImage: "map.fill").font(.title2.bold()); Text(state.playerExperience?.onboarding.status == "Completed" ? "Votre clé ouvre n’importe quelle région. Chaque porte rassemble les histoires configurées dans sa catégorie." : "Le prologue a été passé. Rejouez-le pour gagner la clé ; la disponibilité des histoires reste décidée par le serveur.").foregroundStyle(GenEngineTheme.secondaryText) }.foregroundStyle(GenEngineTheme.ivory)
            TextField("Rechercher une histoire", text: $search).textFieldStyle(.roundedBorder)
            GeometryReader { proxy in
                ZStack {
                    Image("WorldMap").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    ForEach(Array(visibleCategories.prefix(5).enumerated()), id: \.element.id) { index, category in
                        let anchors = PlayerExperiencePresentation.doorAnchors(for: proxy.size)
                        let point = PlayerExperiencePresentation.projectMapPoint(anchors[index % anchors.count], into: proxy.size)
                        Button { selectedCategoryID = category.id } label: {
                            VStack(spacing: 5) {
                                Image(systemName: selectedCategoryID == category.id ? "door.left.hand.open" : "door.left.hand.closed").font(.system(size: 38)).foregroundStyle(GenEngineTheme.amber)
                                Text(category.name).font(.system(.headline, design: .serif)).multilineTextAlignment(.center)
                                Text("PORTE \(category.order)").font(.caption2)
                            }.padding(10).foregroundStyle(GenEngineTheme.ivory).background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedCategoryID == category.id ? GenEngineTheme.amber : .white.opacity(0.18)))
                        }.buttonStyle(.plain).position(point)
                    }
                }
            }
            .frame(height: 620).clipShape(RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
            if let selected = visibleCategories.first(where: { $0.id == selectedCategoryID }) { Text(selected.description).foregroundStyle(GenEngineTheme.secondaryText) }
            Text("Histoires disponibles").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                ForEach(filteredStories) { story in
                    CompactStoryCard(story: story) { Task { await state.open(story) } }
                }
            }
        }
    }

    private var filteredStories: [StorySummary] {
        let category = visibleCategories.first { $0.id == selectedCategoryID }
        return state.stories.filter { story in
            let matchesSearch = search.isEmpty || "\(story.title) \(story.synopsis)".localizedCaseInsensitiveContains(search)
            guard matchesSearch, let ids = category?.scenarioIds, !ids.isEmpty else { return matchesSearch }
            return story.scenarioID.map(ids.contains) ?? false
        }
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
