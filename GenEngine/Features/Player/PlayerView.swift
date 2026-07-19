import SwiftUI

struct PlayerView: View {
    @Environment(AppState.self) private var state
    @Environment(GameAudioDirector.self) private var audio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textInput = ""
    @State private var showsTree = false
    @State private var interactionCompleted = false

    var body: some View {
        ZStack {
            StoryCanvas(accent: state.currentStory.map { GenEngineTheme.accent($0.accent) } ?? GenEngineTheme.ember)
            if let session = state.session, let step = state.step {
                VStack(spacing: 0) {
                    playerHeader(session: session)
                    ScrollView {
                        VStack(spacing: 30) {
                            Spacer(minLength: 20)
                            EyebrowText(text: step.status == .completed ? "Épilogue" : "Chapitre \(step.turn + 1)")
                            Text(step.text)
                                .font(.system(.title, design: .serif, weight: .regular))
                                .foregroundStyle(GenEngineTheme.ivory)
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .frame(maxWidth: 720)
                                .id(step.nodeId)
                                .transition(.opacity)
                                .accessibilityAddTraits(.isHeader)
                            interactionArtifact(step)
                            choices(step)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 70)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .overlay {
            // La carte est un panneau de HUD superposé au jeu, pas un écran de navigation.
            if showsTree {
                HUDOverlayPanel(title: "Carte du scénario", symbol: "point.3.connected.trianglepath.dotted", onClose: { showsTree = false }) {
                    SessionTreePanel(graph: state.questGraph, failure: state.treeError)
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showsTree)
        .task { audio.enter(.session) }
        .onChange(of: state.step?.nodeId) { _, _ in interactionCompleted = false }
        // Le son ne fait que doubler un état déjà écrit à l'écran (« Chemin accompli »).
        .onChange(of: state.step?.status) { _, status in
            guard let status, status == .completed || status == .abandoned else { return }
            audio.signal(.gameOver)
        }
    }

    private func playerHeader(session: SessionView) -> some View {
        HStack(spacing: 14) {
            Button { state.endSession() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("Quitter l’histoire")
            VStack(alignment: .leading, spacing: 2) {
                Text(state.currentStory?.title ?? "GenEngine").font(.subheadline.weight(.semibold)).foregroundStyle(GenEngineTheme.ivory)
                Text("Choix \(session.turn + 1)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }
            Spacer()
            Button { showsTree = true; if !state.isDemoSession { Task { await state.loadTree() } } } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Explorer la carte de l’histoire")
            if !state.isDemoSession && [.paused, .awaitingInput, .awaitingExternalInput, .awaitingValidation].contains(session.status) {
                Button { Task { await state.pauseOrResume() } } label: {
                    Image(systemName: session.status == .paused ? "play.fill" : "pause.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel(session.status == .paused ? "Reprendre" : "Mettre en pause")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func choices(_ step: CurrentStep) -> some View {
        if step.status == .completed || step.status == .abandoned {
            completionSummary
        } else if step.status == .paused {
            VStack(spacing: 14) {
                Image(systemName: "pause.circle").font(.largeTitle).foregroundStyle(GenEngineTheme.amber)
                Text("Histoire en pause").font(.headline).foregroundStyle(GenEngineTheme.ivory)
                Button("Reprendre") { Task { await state.pauseOrResume() } }.buttonStyle(PrimaryActionStyle())
            }
        } else if step.kind == .narration {
            Button("Continuer") { Task { await state.continueInteraction() } }
                .buttonStyle(PrimaryActionStyle())
                .disabled(state.isBusy)
                .frame(maxWidth: 660)
        } else if step.kind == .freeText && step.status == .awaitingExternalInput {
            VStack(spacing: 14) {
                TextField("Votre réponse", text: $textInput, axis: .vertical)
                    .lineLimit(3...7)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 660)
                Button("Faire analyser ma réponse") {
                    let value = textInput
                    Task { await state.submit(text: value) }
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(state.isBusy || textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } else if step.kind == .freeText && step.status == .awaitingValidation, let analysis = step.pendingTextAnalysis {
            VStack(spacing: 16) {
                Label(analysis.isAccepted ? "Réponse reconnue" : "Réponse partiellement reconnue", systemImage: analysis.isAccepted ? "checkmark.seal.fill" : "questionmark.diamond.fill")
                    .font(.headline)
                    .foregroundStyle(analysis.isAccepted ? GenEngineTheme.verdigris : GenEngineTheme.amber)
                Text(analysis.explanation).foregroundStyle(GenEngineTheme.secondaryText).multilineTextAlignment(.center)
                if !analysis.matchedTerms.isEmpty {
                    Text("Termes reconnus : \(analysis.matchedTerms.joined(separator: ", "))").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                }
                HStack {
                    Button("Modifier") { Task { await state.confirmTextAnalysis(false) } }
                    Button("Confirmer") { Task { await state.confirmTextAnalysis(true); textInput = "" } }.buttonStyle(PrimaryActionStyle())
                }
                .disabled(state.isBusy)
            }
            .padding(20)
            .frame(maxWidth: 660)
            .glassPanel()
        } else {
            VStack(spacing: 14) {
                ForEach(Array(step.choices.enumerated()), id: \.element.id) { index, choice in
                    Button {
                        audio.signal(.choice)
                        Task {
                            if step.kind == .quiz { await state.submit(answerID: choice.id) }
                            else { await state.submit(choiceID: choice.id) }
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ChoiceNumber(value: index + 1)
                            Text(choice.text).font(.system(.body, design: .serif, weight: .medium)).multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.right").foregroundStyle(GenEngineTheme.amber)
                        }
                        .foregroundStyle(GenEngineTheme.ivory)
                        .padding(18)
                        .frame(maxWidth: 660, minHeight: 64)
                        .glassPanel()
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isBusy || requiresDemoInteraction(step))
                    .accessibilityLabel("\(step.kind == .quiz ? "Réponse" : "Choix") \(index + 1), \(choice.text)")
                }
            }
        }
    }

    @ViewBuilder
    private func interactionArtifact(_ step: CurrentStep) -> some View {
        if step.status != .completed && step.status != .abandoned {
            if state.isDemoSession, let interaction = DemoStory.node(id: step.nodeId)?.interaction {
                HStack(spacing: 14) { Image(systemName: interaction.symbol).font(.title).foregroundStyle(GenEngineTheme.amber); VStack(alignment: .leading) { EyebrowText(text: "INTERACTION DU SCÉNARIO", color: GenEngineTheme.amber); Text(interaction.label).font(.headline).foregroundStyle(GenEngineTheme.ivory); Text(interaction.hint).font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); Button(interactionCompleted ? "Signal reçu" : "Interagir") { interactionCompleted = true; audio.signal(.reward) }.buttonStyle(.borderedProminent).tint(GenEngineTheme.verdigris) }.padding(16).frame(maxWidth: 720).glassPanel()
            } else if !state.isDemoSession {
                Label(materializedLabel(step), systemImage: "hand.tap.fill").font(.caption).foregroundStyle(GenEngineTheme.verdigris).padding(12).glassPanel()
            }
        }
    }

    private func requiresDemoInteraction(_ step: CurrentStep) -> Bool { state.isDemoSession && DemoStory.node(id: step.nodeId)?.interaction != nil && !interactionCompleted }
    private func materializedLabel(_ step: CurrentStep) -> String {
        switch step.kind { case .quiz: "Question matérialisée par le scénario"; case .freeText: "Expression libre analysée par le moteur"; case .characteristicGate: "Dialogue conditionnel débloqué par votre parcours"; default: "Interaction narrative · \(step.nodeId)" }
    }

    /// Nature de la fin atteinte en démonstration. Le moteur n'exposant aucun
    /// drapeau d'échec, une rupture est portée par le texte et par cette interface.
    private var demoOutcome: DemoOutcome? {
        guard state.isDemoSession, let id = state.demoPath.last else { return nil }
        return DemoStory.node(id: id)?.outcome
    }

    private var completionSummary: some View {
        let outcome = demoOutcome
        let isRupture = outcome == .rupture
        return VStack(spacing: 18) {
            Image(systemName: isRupture ? "exclamationmark.triangle.fill" : "trophy.fill").font(.system(size: 42)).foregroundStyle(GenEngineTheme.amber)
            Text(PlayerExperiencePresentation.demoOutcomeTitle(outcome)).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory).multilineTextAlignment(.center)
            Text(PlayerExperiencePresentation.demoOutcomeNote(outcome)).foregroundStyle(GenEngineTheme.secondaryText).multilineTextAlignment(.center)
            if state.isDemoSession {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(state.demoPath.count) étapes traversées", systemImage: "point.3.connected.trianglepath.dotted").font(.headline)
                    ForEach(Array(state.demoPath.enumerated()), id: \.offset) { index, node in
                        Text("\(index + 1). \(DemoStory.node(id: node)?.title ?? node)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                    Divider()
                    ForEach(PlayerExperiencePresentation.demoPostures(state.demoPath), id: \.self) { posture in
                        Label("Posture exercée : \(posture)", systemImage: "tuningfork")
                    }
                    Label(PlayerExperiencePresentation.demoFrequencyLabel(outcome), systemImage: isRupture ? "xmark.circle" : "waveform")
                    Label("Une page de journal", systemImage: "book.closed.fill")
                }.padding(18).frame(maxWidth: 660, alignment: .leading).glassPanel()
            }
            if let graph = state.questGraph {
                QuestGraphView(
                    graph: graph,
                    title: "Mémoire de quête",
                    subtitle: state.isDemoSession
                        ? "Ce que vous avez traversé, ici et lors de vos parties de démonstration précédentes."
                        : "Ce que vous avez traversé, ici et lors de vos parties précédentes.")
            } else if let treeError = state.treeError {
                VStack(spacing: 8) {
                    Label("Carte du scénario indisponible", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(GenEngineTheme.amber)
                    Text(treeError).font(.caption).foregroundStyle(GenEngineTheme.secondaryText).multilineTextAlignment(.center)
                    Button("Réessayer") { Task { await state.loadTree() } }.buttonStyle(.bordered).tint(GenEngineTheme.ivory)
                }
                .padding(18)
                .frame(maxWidth: 660)
                .glassPanel()
            }
            // Sur une rupture, reprendre depuis le début devient l'action principale :
            // la situation ne peut plus être rattrapée en cours de route.
            HStack {
                if isRupture {
                    Button("Reprendre depuis le début") { state.startDemo() }.buttonStyle(PrimaryActionStyle())
                    Button("Créer mon aventure") { state.endSession(); state.selectedTab = state.isAuthenticated ? .experience : .account }.buttonStyle(.bordered).tint(GenEngineTheme.ivory)
                } else {
                    if state.isDemoSession { Button("Essayer une autre situation") { state.startDemo() }.buttonStyle(.bordered).tint(GenEngineTheme.ivory) }
                    Button(state.isDemoSession ? "Créer mon aventure" : "Voir mon univers") { state.endSession(); state.selectedTab = state.isAuthenticated ? .experience : .account }.buttonStyle(PrimaryActionStyle())
                }
            }
        }.padding(.top, 18)
    }
}

private struct SessionTreePanel: View {
    let graph: QuestGraph?
    let failure: String?

    var body: some View {
        if let graph {
            QuestGraphView(graph: graph, title: "Carte du scénario", subtitle: "Tout le scénario, pas seulement le chemin emprunté.")
        } else if let failure {
            VStack(spacing: 10) {
                Label("Carte indisponible", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(GenEngineTheme.amber)
                Text(failure).font(.caption).foregroundStyle(GenEngineTheme.secondaryText).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } else {
            ProgressView("Chargement de la carte…").tint(GenEngineTheme.amber).padding(40)
        }
    }
}

private struct ChoiceNumber: View {
    let value: Int

    var body: some View {
        Text(value.formatted())
            .font(.caption.bold())
            .foregroundStyle(GenEngineTheme.amber)
            .frame(width: 28, height: 28)
            .background(GenEngineTheme.amber.opacity(0.13), in: Circle())
    }
}
