import SwiftUI

struct PlayerExperienceViewScreen: View {
    @Environment(AppState.self) private var state
    @State private var familiarID: UUID?
    @State private var form = "spark"
    @State private var tone = "Warm"
    @State private var writingStyle = "Socratic"
    @State private var accent = "amber"
    @State private var helpLevel = 2

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.violet)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    pageHeader
                    wallet
                    familiar
                    shop
                    history
                }
                .padding(.horizontal, 20).padding(.bottom, 110)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in min(availableWidth, 900) }
            }
        }
        .navigationTitle(state.copy("nav.experience", fallback: "Mon univers"))
        .task { await state.loadPlatformContext(); hydrateSelection() }
        .refreshable { await state.loadPlatformContext(); hydrateSelection() }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: state.gameName)
            Text("Une aventure qui vous ressemble").font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
            Text("Votre familier, vos récompenses et vos objets réunis au même endroit.").foregroundStyle(GenEngineTheme.secondaryText)
        }
    }

    private var wallet: some View {
        HStack {
            VStack(alignment: .leading) {
                EyebrowText(text: state.copy("experience.wallet.title", fallback: "Portefeuille"), color: GenEngineTheme.verdigris)
                Text("\(state.playerExperience?.balance ?? 0)").font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(GenEngineTheme.ivory)
                Text(state.playerExperience?.currencyName ?? "Braises").foregroundStyle(GenEngineTheme.secondaryText)
            }
            Spacer()
            Text(state.playerExperience?.currencyIcon ?? "✦").font(.system(size: 46)).foregroundStyle(GenEngineTheme.amber)
        }
        .padding(22).glassPanel()
    }

    private var familiar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(state.copy("experience.familiar.title", fallback: "Mon familier"), systemImage: "sparkle.magnifyingglass").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            if let definitions = state.experience?.document.familiars, !definitions.isEmpty {
                Picker("Compagnon", selection: Binding(get: { familiarID ?? definitions[0].id }, set: { newID in familiarID = newID; adopt(definitions.first { $0.id == newID }) })) {
                    ForEach(definitions) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.segmented)
                if let definition = definitions.first(where: { $0.id == familiarID }) ?? definitions.first {
                    Text(definition.description).foregroundStyle(GenEngineTheme.secondaryText)
                    Picker(state.copy("experience.familiar.form", fallback: "Forme"), selection: $form) { ForEach(definition.availableForms, id: \.self) { Text($0.capitalized).tag($0) } }
                    Picker(state.copy("experience.familiar.tone", fallback: "Ton"), selection: $tone) { ForEach(definition.availableTones, id: \.self) { Text($0).tag($0) } }
                    TextField("Style d’écriture", text: $writingStyle).textFieldStyle(.roundedBorder)
                    Stepper("\(state.copy("experience.familiar.helpLevel", fallback: "Niveau d’aide")) : \(helpLevel)", value: $helpLevel, in: 0...5).foregroundStyle(GenEngineTheme.ivory)
                    Button(state.copy("experience.familiar.apply", fallback: "Appliquer cette personnalité")) {
                        Task { await state.saveFamiliar(.init(familiarId: definition.id, form: form, tone: tone, writingStyle: writingStyle, accent: accent, helpLevel: helpLevel)) }
                    }.buttonStyle(PrimaryActionStyle())
                }
            } else { ProgressView().tint(GenEngineTheme.amber) }
        }
        .padding(22).glassPanel()
    }

    private var shop: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(state.copy("experience.shop.title", fallback: "Magasin"), systemImage: "bag.fill").font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.experience?.document.economy.offers.filter(\.enabled) ?? []) { offer in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(offer.name).font(.headline).foregroundStyle(GenEngineTheme.ivory)
                        Text(offer.description).font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                    Spacer()
                    if state.playerExperience?.ownedOfferIds.contains(offer.id) == true { Label(state.copy("experience.shop.owned", fallback: "Acquis"), systemImage: "checkmark.seal.fill").foregroundStyle(GenEngineTheme.verdigris) }
                    else { Button("\(offer.price) \(state.playerExperience?.currencyIcon ?? "✦")") { Task { await state.purchase(offer) } }.buttonStyle(.borderedProminent).tint(GenEngineTheme.ember) }
                }
                .padding(16).background(GenEngineTheme.midnight.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Derniers gains").font(.title3.bold()).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.playerExperience?.recentEntries ?? []) { entry in
                HStack { Text(entry.reason); Spacer(); Text(entry.amount >= 0 ? "+\(entry.amount)" : "\(entry.amount)").fontWeight(.bold).foregroundStyle(entry.amount >= 0 ? GenEngineTheme.verdigris : GenEngineTheme.ember) }
                    .foregroundStyle(GenEngineTheme.secondaryText)
            }
        }
    }

    private func hydrateSelection() {
        guard let selected = state.playerExperience?.familiar else { familiarID = state.experience?.document.familiars.first?.id; return }
        familiarID = selected.familiarId; form = selected.form; tone = selected.tone; writingStyle = selected.writingStyle; accent = selected.accent; helpLevel = selected.helpLevel
    }

    private func adopt(_ definition: FamiliarDefinition?) {
        guard let definition else { return }
        form = definition.form; tone = definition.tone; writingStyle = definition.writingStyle; accent = definition.accent; helpLevel = definition.helpLevel
    }
}
