import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var state
    @State private var query = ""

    private var filteredStories: [StorySummary] {
        guard !query.isEmpty else { return state.stories }
        return state.stories.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.synopsis.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.verdigris)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if state.isAuthenticated && !state.savedSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            EyebrowText(text: "Reprendre le fil", color: GenEngineTheme.amber)
                            ForEach(state.savedSessions) { saved in
                                Button { Task { await state.resume(saved) } } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: saved.status == "Terminé" ? "checkmark.seal.fill" : "bookmark.fill").foregroundStyle(GenEngineTheme.amber)
                                        VStack(alignment: .leading) {
                                            Text(saved.title).font(.system(.headline, design: .serif)).foregroundStyle(GenEngineTheme.ivory)
                                            Text("\(saved.status) · Tour \(saved.turn + 1)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right").foregroundStyle(GenEngineTheme.amber)
                                    }
                                    .padding(16).glassPanel()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 18)], spacing: 18) {
                        ForEach(filteredStories) { story in
                            LibraryStoryCard(story: story) { Task { await state.open(story) } }
                        }
                    }
                }
                .padding(22)
                .padding(.bottom, 100)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in
                    min(availableWidth, 1_024)
                }
            }
        }
        .navigationTitle("Bibliothèque")
        .searchable(text: $query, prompt: "Rechercher une histoire")
        .task { await state.loadCatalog() }
    }
}

private struct LibraryStoryCard: View {
    let story: StorySummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: story.symbol).font(.title2).foregroundStyle(GenEngineTheme.accent(story.accent))
                    Spacer()
                    Text(story.duration).font(.caption.weight(.medium)).foregroundStyle(GenEngineTheme.secondaryText)
                }
                EyebrowText(text: story.eyebrow, color: GenEngineTheme.accent(story.accent))
                Text(story.title).font(.system(.title2, design: .serif, weight: .semibold)).foregroundStyle(GenEngineTheme.ivory).multilineTextAlignment(.leading)
                Text(story.synopsis).font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText).lineLimit(3).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Label(buttonLabel, systemImage: buttonSymbol).font(.subheadline.weight(.semibold)).foregroundStyle(GenEngineTheme.accent(story.accent))
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
            .background(GenEngineTheme.midnight.opacity(0.76), in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(GenEngineTheme.accent(story.accent).opacity(0.22)) }
        }
        .buttonStyle(.plain)
        .accessibilityHint(buttonLabel)
    }

    private var buttonLabel: String {
        switch story.availability { case .comingSoon: "Aperçu"; default: "Jouer" }
    }
    private var buttonSymbol: String {
        switch story.availability { case .comingSoon: "hourglass"; default: "play.fill" }
    }
}
