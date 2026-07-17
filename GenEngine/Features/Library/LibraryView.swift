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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 18)], spacing: 18) {
                    ForEach(filteredStories) { story in
                        LibraryStoryCard(story: story) { Task { await state.open(story) } }
                    }
                }
                .frame(maxWidth: 980)
                .padding(22)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Bibliothèque")
        .searchable(text: $query, prompt: "Rechercher une histoire")
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
