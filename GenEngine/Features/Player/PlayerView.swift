import SwiftUI

struct PlayerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textInput = ""
    @State private var showsTree = false

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
                            choices(step)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 70)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsTree) { SessionTreeView(tree: state.tree) }
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
            if !state.isDemoSession {
                Button { showsTree = true; Task { await state.loadTree() } } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Explorer l’arbre de l’histoire")
            }
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
            VStack(spacing: 16) {
                Image(systemName: "sun.horizon.fill").font(.largeTitle).foregroundStyle(GenEngineTheme.amber)
                Text("Votre histoire continue ailleurs.").font(.headline).foregroundStyle(GenEngineTheme.secondaryText)
                Button("Retour à la bibliothèque") { state.endSession() }.buttonStyle(PrimaryActionStyle())
            }
            .padding(.top, 18)
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
                    .disabled(state.isBusy)
                    .accessibilityLabel("\(step.kind == .quiz ? "Réponse" : "Choix") \(index + 1), \(choice.text)")
                }
            }
        }
    }
}

private struct SessionTreeView: View {
    let tree: NarrativeTree?

    var body: some View {
        NavigationStack {
            Group {
                if let tree {
                    List {
                        Section("Scènes") {
                            ForEach(tree.nodes) { node in
                                HStack(alignment: .top) {
                                    Image(systemName: symbol(for: node.state)).foregroundStyle(color(for: node.state))
                                    VStack(alignment: .leading) {
                                        Text(node.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                                        Text(node.text).lineLimit(2)
                                    }
                                }
                            }
                        }
                        Section("Chemins et conditions") {
                            ForEach(Array(tree.edges.enumerated()), id: \.offset) { _, edge in
                                VStack(alignment: .leading, spacing: 5) {
                                    Label(edge.text, systemImage: edge.isAvailable ? "arrow.right.circle.fill" : "lock.circle")
                                    Text("\(edge.sourceNodeId) → \(edge.targetNodeId)").font(.caption.monospaced()).foregroundStyle(.secondary)
                                    Text(edge.evaluation.explanation).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else { ProgressView("Chargement de l’arbre…") }
            }
            .navigationTitle("Exploration")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func symbol(for state: String) -> String {
        switch state.lowercased() { case "current": "location.fill"; case "visited": "checkmark.circle.fill"; case "locked": "lock.fill"; default: "circle.dotted" }
    }

    private func color(for state: String) -> Color {
        switch state.lowercased() { case "current": GenEngineTheme.ember; case "visited": GenEngineTheme.verdigris; case "locked": .secondary; default: GenEngineTheme.amber }
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
