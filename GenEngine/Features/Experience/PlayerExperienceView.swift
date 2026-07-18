import SwiftUI

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

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.violet)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let bootstrap = state.playerBootstrap, bootstrap.nextAction != "OpenMap" { onboarding(bootstrap) }
                    sectionPicker
                    switch section {
                    case .map: map
                    case .journal: journal
                    case .companion: companion
                    case .shop: shop
                    case .help: help
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 120)
                .containerRelativeFrame(.horizontal) { width, _ in min(width, 960) }
            }
        }
        .navigationTitle(state.copy("nav.experience", fallback: "Votre aventure"))
        .task { await state.loadPlatformContext(); await state.loadCatalog(); await state.loadJournal(); hydrateSelection() }
        .refreshable { await state.loadPlatformContext(); await state.loadCatalog(force: true); await state.loadJournal(); hydrateSelection() }
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

    private func onboarding(_ bootstrap: PlayerBootstrapView) -> some View {
        Group {
            if bootstrap.nextAction == "ConfigureFamiliar" {
                OnboardingCard(index: 1, title: "Rencontrez votre compagnon", message: "Choisissez son apparence, son nom et sa façon de vous aider.", action: "Le personnaliser") { section = .companion }
            } else if let step = bootstrap.tutorial.steps.sorted(by: { $0.order < $1.order }).first(where: { !bootstrap.experience.onboarding.completedStepIds.contains($0.id) }) {
                OnboardingCard(index: step.order, title: step.title, message: step.body, action: "J’ai compris") { Task { await state.completeOnboardingStep(step) } }
                    .contextMenu { if bootstrap.tutorial.allowSkip { Button("Passer le tutoriel") { Task { await state.skipOnboarding() } } } }
            }
        }
    }

    private var map: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Carte du monde", systemImage: "map.fill").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            TextField("Rechercher une histoire", text: $search).textFieldStyle(.roundedBorder)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach((state.experience?.document.categories ?? []).filter(\.isVisible)) { category in
                    let masteries = state.playerExperience?.masteries.filter { category.scenarioIds?.contains($0.scenarioId) == true } ?? []
                    let progress = masteries.isEmpty ? 0 : masteries.map(\.masteryPercent).reduce(0, +) / masteries.count
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.title).foregroundStyle(GenEngineTheme.verdigris)
                        EyebrowText(text: "ZONE \(category.order)", color: GenEngineTheme.verdigris)
                        Text(category.name).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                        Text(category.description).font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText)
                        ProgressView(value: Double(progress), total: 100).tint(GenEngineTheme.ember)
                        Text("\(progress)% exploré").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                    }.padding(20).glassPanel()
                }
            }
            Text("Histoires disponibles").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                ForEach(filteredStories) { story in
                    CompactStoryCard(story: story) { Task { await state.open(story) } }
                }
            }
        }
    }

    private var filteredStories: [StorySummary] {
        guard !search.isEmpty else { return state.stories }
        return state.stories.filter { "\($0.title) \($0.synopsis)".localizedCaseInsensitiveContains(search) }
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label("Journal de votre parcours", systemImage: "book.pages.fill").font(.title2.bold()); Spacer(); Text("\(state.playerJournal?.total ?? 0) traces").foregroundStyle(GenEngineTheme.amber) }.foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.playerExperience?.masteries ?? []) { mastery in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Histoire explorée").font(.headline); Spacer(); Text("\(mastery.masteryPercent)%").foregroundStyle(GenEngineTheme.amber) }
                    Text("\(mastery.choiceIds.count) choix · \(mastery.endingIds.count) fin(s)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                    ProgressView(value: Double(mastery.masteryPercent), total: 100).tint(GenEngineTheme.verdigris)
                }.padding(16).glassPanel()
            }
            ForEach(state.playerJournal?.items ?? state.playerExperience?.recentJournal ?? []) { entry in
                HStack(alignment: .top, spacing: 14) {
                    Circle().fill(GenEngineTheme.ember).frame(width: 10, height: 10).shadow(color: GenEngineTheme.ember, radius: 8)
                    VStack(alignment: .leading, spacing: 5) {
                        EyebrowText(text: entry.type, color: GenEngineTheme.ember)
                        Text(entry.title).font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                        Text(entry.summary).foregroundStyle(GenEngineTheme.secondaryText)
                        Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                }.padding(.vertical, 8)
            }
        }
    }

    private var companion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Votre compagnon", systemImage: "sparkles").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            if let definitions = state.experience?.document.familiars, let definition = definitions.first(where: { $0.id == familiarID }) ?? definitions.first {
                companionPortrait(definition)
                TextField("Son nom", text: $customName).textFieldStyle(.roundedBorder)
                Picker("Forme", selection: $form) { ForEach(definition.availableForms, id: \.self) { Text($0.capitalized).tag($0) } }
                Picker("Ton", selection: $tone) { ForEach(definition.availableTones, id: \.self) { Text($0).tag($0) } }
                Stepper("Niveau d’aide : \(helpLevel)/5", value: $helpLevel, in: 0...5)
                Stepper("Fréquence : \(frequency)/5", value: $frequency, in: 0...5)
                Toggle("Me proposer de l’aide au bon moment", isOn: $proactive)
                Button("Enregistrer mon compagnon") { Task { await state.saveFamiliar(.init(familiarId: definition.id, form: form, tone: tone, writingStyle: writingStyle, accent: accent, helpLevel: helpLevel, customName: customName, interventionFrequency: frequency, proactive: proactive)) } }.buttonStyle(PrimaryActionStyle())
            }
        }.padding(20).glassPanel()
    }

    private func companionPortrait(_ definition: FamiliarDefinition) -> some View {
        VStack(spacing: 10) {
            if let value = definition.portraitUrl ?? definition.avatarUrl, let url = URL(string: value) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView().tint(GenEngineTheme.amber) }
                    .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 360).clipped().clipShape(RoundedRectangle(cornerRadius: 28))
            } else { Image(systemName: "sparkles").font(.system(size: 70)).foregroundStyle(GenEngineTheme.amber).frame(height: 220) }
            Text(customName.isEmpty ? definition.name : customName).font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
            Text(definition.description).multilineTextAlignment(.center).foregroundStyle(GenEngineTheme.secondaryText)
        }.frame(maxWidth: .infinity)
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
        guard let definition = state.playerExperience?.familiarDefinition ?? state.experience?.document.familiars.first else { return }
        let selected = state.playerExperience?.familiar
        familiarID = selected?.familiarId ?? definition.id; form = selected?.form ?? definition.form; tone = selected?.tone ?? definition.tone
        writingStyle = selected?.writingStyle ?? definition.writingStyle; accent = selected?.accent ?? definition.accent; helpLevel = selected?.helpLevel ?? definition.helpLevel
        customName = selected?.customName ?? definition.name; frequency = selected?.interventionFrequency ?? state.playerBootstrap?.assistant.defaultFrequency ?? 2; proactive = selected?.proactive ?? state.playerBootstrap?.assistant.proactive ?? true
    }
}

private struct OnboardingCard: View {
    let index: Int; let title: String; let message: String; let action: String; let perform: () -> Void
    var body: some View { HStack(spacing: 16) { Text(String(format: "%02d", index)).font(.system(size: 34, design: .serif)).foregroundStyle(GenEngineTheme.amber); VStack(alignment: .leading) { EyebrowText(text: "TUTORIEL PERSISTANT", color: GenEngineTheme.amber); Text(title).font(.headline).foregroundStyle(GenEngineTheme.ivory); Text(message).font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); Button(action, action: perform).buttonStyle(.borderedProminent).tint(GenEngineTheme.ember) }.padding(18).glassPanel() }
}
