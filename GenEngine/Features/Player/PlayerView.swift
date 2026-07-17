import SwiftUI

struct PlayerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            if !state.isDemoSession && (session.status == .paused || session.status == .awaitingInput) {
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
        } else {
            VStack(spacing: 14) {
                ForEach(Array(step.choices.enumerated()), id: \.element.id) { index, choice in
                    Button {
                        Task { await state.submit(choiceID: choice.id) }
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
                    .accessibilityLabel("Choix \(index + 1), \(choice.text)")
                }
            }
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
