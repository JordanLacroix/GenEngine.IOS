import SwiftUI

struct StudioView: View {
    @Environment(AppState.self) private var state
    @State private var categoryID: UUID?
    @State private var provider = "offline"
    @State private var prompt = ""
    @State private var tone = "immersive"
    @State private var targetMinutes = 10
    @State private var scenarioQuery = ""
    @State private var selectedNodeID: String?
    @State private var editedText = ""
    @State private var editedEnding = false
    @State private var confirmation: ConfirmationAction?

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
                    scenarioLibrary
                    creationForm
                    if let result = state.generatedScenario { resultCard(result); graphCard(result); nodeInspector(result) }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
        .confirmation($confirmation)
        .task {
            await state.loadPlatformContext()
            await state.searchScenarios()
            categoryID = categoryID ?? categories.first?.id
        }
    }

    private var categories: [CategoryDefinition] { state.experience?.document.categories.filter(\.isVisible).sorted { $0.order < $1.order } ?? [] }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(state.gameName, systemImage: "globe.europe.africa.fill").font(.title3.bold()).foregroundStyle(GenEngineTheme.ivory)
            Text(state.experience?.document.game.globalStory ?? "Chargement de l’univers…")
                .font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText).lineLimit(5)
        }.padding(20).glassPanel()
    }

    private var scenarioLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Bibliothèque du Studio", systemImage: "square.stack.3d.up.fill").font(.title2.bold())
                Spacer()
                Text("\(state.authorScenariosTotal) brouillon(s)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }
            HStack {
                TextField("Rechercher par titre ou intention", text: $scenarioQuery).textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await state.searchScenarios(scenarioQuery) } }
                Button { Task { await state.searchScenarios(scenarioQuery) } } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.bordered).tint(GenEngineTheme.verdigris)
            }
            if state.authorScenarios.isEmpty {
                Text("Aucun brouillon ne correspond à cette recherche.").font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(state.authorScenarios, id: \.id) { scenario in
                            Button {
                                state.selectScenario(scenario)
                                selectFirstNode(in: scenario)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(scenario.title).font(.headline).lineLimit(1)
                                    Text("Révision \(scenario.revision)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                                }
                                .frame(width: 210, alignment: .leading).padding(14)
                                .background(state.generatedScenario?.id == scenario.id ? GenEngineTheme.verdigris.opacity(0.18) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.foregroundStyle(GenEngineTheme.ivory).padding(20).glassPanel()
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
            Button(role: .destructive) {
                confirmation = ConfirmationAction(
                    title: "Archiver « \(result.title) » ?",
                    message: "Le brouillon quitte la bibliothèque du Studio. L’archivage est appliqué par le serveur et n’est pas annulable depuis le client.",
                    confirmLabel: "Archiver") { Task { await state.archiveScenario(result) } }
            } label: { Label("Archiver ce scénario", systemImage: "archivebox") }
                .buttonStyle(.bordered)
        }.padding(22).glassPanel()
    }

    private func graphCard(_ result: ScenarioView) -> some View {
        let nodes = studioNodes(result.draftJson)
        return VStack(alignment: .leading, spacing: 14) {
            HStack { Label("Arborescence narrative", systemImage: "point.3.connected.trianglepath.dotted").font(.title2.bold()); Spacer(); Text("\(nodes.count) scènes").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }
            if nodes.isEmpty { ContentUnavailableView("Graphe indisponible", systemImage: "exclamationmark.triangle", description: Text("Le brouillon ne contient aucune scène lisible.")) }
            else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            Button {
                                selectedNodeID = node.id
                                editedText = node.text
                                editedEnding = node.isEnding
                            } label: { VStack(alignment: .leading, spacing: 8) {
                                HStack { Text("\(index + 1)").font(.caption.bold()).frame(width: 26, height: 26).background(GenEngineTheme.verdigris.opacity(0.18), in: RoundedRectangle(cornerRadius: 7)); Text(node.id).font(.caption.monospaced()).foregroundStyle(GenEngineTheme.secondaryText) }
                                Text(node.text).font(.system(.headline, design: .serif)).lineLimit(4).frame(width: 210, alignment: .leading)
                                ForEach(node.choices, id: \.id) { choice in HStack { Text(choice.text).lineLimit(1); Spacer(); Image(systemName: "arrow.right"); Text(choice.target).font(.caption.monospaced()) }.font(.caption).padding(7).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8)) }
                                if node.isEnding { Label("Fin", systemImage: "flag.checkered").font(.caption).foregroundStyle(GenEngineTheme.amber) }
                            }.padding(14).frame(width: 240, alignment: .topLeading).background(GenEngineTheme.midnight.opacity(0.75), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(selectedNodeID == node.id ? GenEngineTheme.amber : (index == 0 ? GenEngineTheme.verdigris.opacity(0.6) : .white.opacity(0.08)))) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.foregroundStyle(GenEngineTheme.ivory).padding(20).glassPanel()
    }

    private func nodeInspector(_ result: ScenarioView) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Inspecteur de scène", systemImage: "slider.horizontal.3").font(.title2.bold())
            if let selectedNodeID {
                Text(selectedNodeID).font(.caption.monospaced()).foregroundStyle(GenEngineTheme.verdigris)
                TextField("Texte de la scène", text: $editedText, axis: .vertical)
                    .lineLimit(6...14).textFieldStyle(.roundedBorder)
                Toggle("Cette scène termine le scénario", isOn: $editedEnding).tint(GenEngineTheme.amber)
                Button {
                    guard let data = editedDocument(result.draftJson, nodeID: selectedNodeID) else { return }
                    Task { await state.updateScenario(document: data) }
                } label: { Label("Enregistrer la scène", systemImage: "square.and.arrow.down.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryActionStyle()).disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isBusy)
            } else {
                Text("Sélectionnez une carte dans l’arborescence pour modifier son texte et son statut de fin.").foregroundStyle(GenEngineTheme.secondaryText)
            }
        }.foregroundStyle(GenEngineTheme.ivory).padding(20).glassPanel()
    }

    private func selectFirstNode(in scenario: ScenarioView) {
        guard let first = studioNodes(scenario.draftJson).first else { return }
        selectedNodeID = first.id
        editedText = first.text
        editedEnding = first.isEnding
    }

    private func editedDocument(_ source: String, nodeID: String) -> Data? {
        guard let data = source.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var nodes = root["nodes"] as? [[String: Any]],
              let index = nodes.firstIndex(where: { $0["id"] as? String == nodeID }) else { return nil }
        nodes[index]["text"] = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        nodes[index]["isEnding"] = editedEnding
        root["nodes"] = nodes
        return try? JSONSerialization.data(withJSONObject: root)
    }

    private func studioNodes(_ source: String) -> [StudioNode] {
        guard let data = source.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nodes = root["nodes"] as? [[String: Any]] else { return [] }
        return nodes.compactMap { node in
            guard let id = node["id"] as? String else { return nil }
            let choices = (node["choices"] as? [[String: Any]] ?? []).compactMap { choice -> StudioChoice? in
                guard let choiceID = choice["id"] as? String, let target = choice["targetNodeId"] as? String else { return nil }
                return StudioChoice(id: choiceID, text: choice["text"] as? String ?? choiceID, target: target)
            }
            return StudioNode(id: id, text: node["text"] as? String ?? "Scène sans texte", isEnding: node["isEnding"] as? Bool ?? false, choices: choices)
        }
    }
}

private struct StudioNode { let id: String; let text: String; let isEnding: Bool; let choices: [StudioChoice] }
private struct StudioChoice { let id: String; let text: String; let target: String }
