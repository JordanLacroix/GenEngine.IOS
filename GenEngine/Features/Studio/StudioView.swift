import SwiftUI

struct StudioView: View {
    @Environment(AppState.self) private var state
    @State private var categoryID: UUID?
    @State private var provider = "offline"
    @State private var prompt = ""
    @State private var tone = "immersive"
    @State private var targetMinutes = 10

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.verdigris)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        EyebrowText(text: state.copy("studio.eyebrow", fallback: "Atelier narratif"), color: GenEngineTheme.verdigris)
                        Text(state.copy("studio.title", fallback: "Créer une nouvelle histoire")).font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                        Text(state.copy("studio.copilot.subtitle", fallback: "Le moteur assemble l’histoire globale, la catégorie et votre intention pour produire un brouillon jouable.")).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                    contextCard
                    creationForm
                    if let result = state.generatedScenario { resultCard(result) }
                }
                .padding(.horizontal, 20).padding(.bottom, 110)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in min(availableWidth, 900) }
            }
        }
        .navigationTitle(state.copy("nav.studio", fallback: "Studio"))
        .task { await state.loadPlatformContext(); categoryID = categoryID ?? categories.first?.id }
    }

    private var categories: [CategoryDefinition] { state.experience?.document.categories.filter(\.isVisible).sorted { $0.order < $1.order } ?? [] }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(state.gameName, systemImage: "globe.europe.africa.fill").font(.title3.bold()).foregroundStyle(GenEngineTheme.ivory)
            Text(state.experience?.document.game.globalStory ?? "Chargement de l’univers…")
                .font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText).lineLimit(5)
        }.padding(20).glassPanel()
    }

    private var creationForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.copy("studio.title", fallback: "Créer une nouvelle histoire")).font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
            Picker(state.copy("studio.category.label", fallback: "Catégorie"), selection: Binding(get: { categoryID ?? categories.first?.id }, set: { categoryID = $0 })) {
                ForEach(categories) { Text($0.name).tag(Optional($0.id)) }
            }
            .tint(GenEngineTheme.amber)
            TextField(state.copy("studio.prompt.label", fallback: "Votre intention"), text: $prompt, axis: .vertical)
                .lineLimit(5...10).textFieldStyle(.roundedBorder)
            HStack {
                Picker(state.copy("studio.tone.label", fallback: "Ton"), selection: $tone) {
                    Text("Immersif").tag("immersive"); Text("Lumineux").tag("hopeful"); Text("Mystérieux").tag("mysterious"); Text("Tendu").tag("tense")
                }
                Stepper("\(targetMinutes) min", value: $targetMinutes, in: 5...45, step: 5).foregroundStyle(GenEngineTheme.ivory)
            }
            Picker(state.copy("studio.provider.label", fallback: "Provider"), selection: $provider) {
                Text("Hors ligne · déterministe").tag("offline")
                if state.experience?.document.aiProviders.contains(where: { $0.enabled && $0.type.lowercased().contains("azure") }) == true {
                    Text("Azure AI Foundry").tag("azureAiFoundry")
                }
            }.pickerStyle(.menu).tint(GenEngineTheme.amber)
            Button {
                guard let categoryID else { return }
                Task { await state.generateScenario(categoryId: categoryID, prompt: prompt, provider: provider, targetMinutes: targetMinutes, tone: tone) }
            } label: {
                HStack { Label(state.copy("studio.generateDraft", fallback: "Générer le brouillon"), systemImage: "wand.and.sparkles"); if state.isBusy { ProgressView() } }.frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle()).disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || categoryID == nil || state.isBusy)
        }.padding(22).glassPanel()
    }

    private func resultCard(_ result: ScenarioView) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText(text: "Brouillon créé", color: GenEngineTheme.verdigris)
            Text(result.title).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
            Text("Révision \(result.revision) · prêt à valider, prévisualiser puis publier.").foregroundStyle(GenEngineTheme.secondaryText)
            Label("Identifiant \(result.id.uuidString.lowercased())", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(GenEngineTheme.verdigris)
        }.padding(22).glassPanel()
    }
}
