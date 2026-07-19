import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            StoryCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    // L'histoire mise en avant est la démonstration hors ligne pour un
                    // visiteur anonyme, et une histoire réelle du catalogue une fois connecté.
                    if let featured = state.featuredStory {
                        HeroStoryCard(story: featured, startLabel: state.copy("action.start", fallback: "Commencer")) { Task { await state.open(featured) } }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text(state.copy("home.discover", fallback: "À découvrir")).font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory)
                        // Chargement progressif au défilement, comme la bibliothèque : le
                        // catalogue peut compter des centaines de récits et l'accueil ne
                        // doit pas en montrer une première page présentée comme le tout.
                        let discoverable = state.stories.filter { $0.id != state.featuredStory?.id }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                            ForEach(discoverable) { story in
                                CompactStoryCard(story: story) { Task { await state.open(story) } }
                                    .onAppear {
                                        guard story.id == discoverable.last?.id else { return }
                                        Task { await state.loadMorePublishedStories() }
                                    }
                            }
                        }
                        if state.isLoadingMoreCatalog {
                            HStack(spacing: 10) {
                                ProgressView().tint(GenEngineTheme.amber)
                                Text("Chargement des récits suivants…").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in
                    min(availableWidth, 1_024)
                }
            }
        }
        .task { await state.loadCatalog() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: state.gameName)
            Text("Bonsoir, voyageur.").font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(GenEngineTheme.ivory)
            Text("Quelle histoire allez-vous changer ce soir ?").foregroundStyle(GenEngineTheme.secondaryText)
        }
    }
}

struct HeroStoryCard: View {
    let story: StorySummary
    let startLabel: String
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [GenEngineTheme.ember.opacity(0.72), GenEngineTheme.midnight.opacity(0.88)], startPoint: .topTrailing, endPoint: .bottomLeading)
            Image(systemName: story.symbol).font(.system(size: 150, weight: .ultraLight)).foregroundStyle(GenEngineTheme.amber.opacity(0.16)).offset(x: 100, y: -50)
            VStack(alignment: .leading, spacing: 14) {
                EyebrowText(text: story.eyebrow, color: GenEngineTheme.ivory.opacity(0.8))
                Text(story.title).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                Text(story.synopsis).font(.body).foregroundStyle(GenEngineTheme.ivory.opacity(0.8)).frame(maxWidth: 560, alignment: .leading)
                HStack(spacing: 16) {
                    Button(action: action) { Label(startLabel, systemImage: "play.fill") }.buttonStyle(PrimaryActionStyle())
                    Label(story.duration, systemImage: "clock").font(.subheadline).foregroundStyle(GenEngineTheme.ivory.opacity(0.75))
                }
            }
            .padding(28)
        }
        .frame(minHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.1)) }
        .accessibilityElement(children: .contain)
    }
}

struct CompactStoryCard: View {
    let story: StorySummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: story.symbol).font(.title).foregroundStyle(GenEngineTheme.accent(story.accent))
                Spacer()
                EyebrowText(text: story.eyebrow, color: GenEngineTheme.accent(story.accent))
                Text(story.title).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(GenEngineTheme.ivory).multilineTextAlignment(.leading)
                Text(story.duration).font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
            .background(GenEngineTheme.midnight.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(GenEngineTheme.accent(story.accent).opacity(0.26)) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(story.title), \(story.eyebrow), \(story.duration)")
    }
}
