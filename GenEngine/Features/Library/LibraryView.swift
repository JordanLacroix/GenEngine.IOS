import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var state
    @State private var query = ""

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.verdigris)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // La recherche est un élément du HUD, pas une barre de navigation système.
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(GenEngineTheme.amber).accessibilityHidden(true)
                        TextField(searchPrompt, text: $query)
                            .textFieldStyle(.plain)
                            .foregroundStyle(GenEngineTheme.ivory)
                            .autocorrectionDisabled()
                            .accessibilityLabel(searchPrompt)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(GenEngineTheme.secondaryText)
                            .accessibilityLabel("Effacer la recherche")
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .hudSurface(cornerRadius: 18)
                    if let categories = state.experience?.document.categories.filter(\.isVisible), !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(categories) { category in
                                    let scenarioIDs = Set(category.scenarioIds ?? [])
                                    let stories = state.stories.filter { story in story.scenarioID.map(scenarioIDs.contains) == true }
                                    let started = stories.filter { story in state.savedSessions.contains { saved in if case let .published(versionID) = story.availability { saved.scenarioVersionId == versionID } else { false } } }.count
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(category.name).font(.headline).foregroundStyle(GenEngineTheme.ivory)
                                        Text("\(started) commencé\(started > 1 ? "s" : "") · \(stories.count) scénario\(stories.count > 1 ? "s" : "")").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                                        ProgressView(value: stories.isEmpty ? 0 : Double(started) / Double(stories.count)).tint(GenEngineTheme.verdigris)
                                    }.padding(16).frame(width: 230, alignment: .leading).glassPanel()
                                }
                            }
                        }
                    }
                    if state.isAuthenticated && !state.savedSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            EyebrowText(text: state.copy("library.resume", fallback: "Reprendre le fil"), color: GenEngineTheme.amber)
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
                    // La bibliothèque est la surface exhaustive du catalogue : elle charge
                    // page après page au défilement, jusqu'au dernier récit publié.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 18)], spacing: 18) {
                        ForEach(state.stories) { story in
                            LibraryStoryCard(story: story) { Task { await state.open(story) } }
                                .onAppear {
                                    guard story.id == state.stories.last?.id else { return }
                                    Task { await state.loadMorePublishedStories() }
                                }
                        }
                    }
                    catalogFooter
                }
                .padding(22)
                .padding(.bottom, 24)
                .frame(maxWidth: 1_024)
                .frame(maxWidth: .infinity)
            }
        }
        .task { await state.loadCatalog() }
        // Recherche serveur, non un filtrage de la page affichée : sur un catalogue de
        // plusieurs centaines de récits, filtrer localement ne verrait qu'une page.
        // La frappe est amortie pour ne pas déclencher une requête par caractère.
        .task(id: query) {
            guard query != state.catalogQuery else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await state.searchCatalog(query)
        }
    }

    /// Pied de liste : progression réelle du chargement et bouton de repli si le
    /// défilement automatique n'a pas déclenché la page suivante.
    @ViewBuilder private var catalogFooter: some View {
        if state.isLoadingMoreCatalog {
            HStack(spacing: 10) {
                ProgressView().tint(GenEngineTheme.amber)
                Text("Chargement des récits suivants…").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        } else if state.hasMorePublishedStories {
            Button { Task { await state.loadMorePublishedStories() } } label: {
                Label("Charger la suite", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .tint(GenEngineTheme.amber)
        }
        if state.catalogTotal > 0 {
            Text("\(state.publishedStories.count) sur \(state.catalogTotal) \(state.copy("entity.story.plural", fallback: "récits").lowercased())")
                .font(.caption)
                .foregroundStyle(GenEngineTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(state.publishedStories.count) récits affichés sur \(state.catalogTotal)")
        }
    }

    private var searchPrompt: String {
        "Rechercher \(state.copy("entity.story.singular", fallback: "une histoire").lowercased())"
    }
}

private struct LibraryStoryCard: View {
    @Environment(AppState.self) private var state
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
        switch story.availability { case .comingSoon: state.copy("status.soon", fallback: "Bientôt"); default: state.copy("action.start", fallback: "Commencer") }
    }
    private var buttonSymbol: String {
        switch story.availability { case .comingSoon: "hourglass"; default: "play.fill" }
    }
}
