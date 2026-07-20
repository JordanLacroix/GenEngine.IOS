import Foundation
import Testing
@testable import GenEngine

/// Contrat de pagination unifié du backend (GenEngine#55) : `page` base 1,
/// `pageSize` clampé à `[1, 100]`, enveloppe `{ items, page, pageSize, total }`,
/// `total` portant sur l'ensemble filtré.
///
/// Ces tests sont écrits **contre le contrat documenté**, pas contre un serveur :
/// la PR backend n'est pas fusionnée et aucune vérification de bout en bout n'a eu lieu.
@MainActor
struct PaginatedCatalogTests {
    // MARK: - Décodage de l'enveloppe

    private func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test func envelopeCarriesPageMetadata() throws {
        let page: PagedList<String> = try decode(#"{"items":["a","b"],"page":2,"pageSize":2,"total":213}"#)
        #expect(page.items == ["a", "b"])
        #expect(page.page == 2)
        #expect(page.pageSize == 2)
        #expect(page.total == 213)
        #expect(page.hasMore)
        #expect(page.nextPage == 3)
    }

    @Test func lastPageDeclaresNoSuccessor() throws {
        let page: PagedList<String> = try decode(#"{"items":["z"],"page":3,"pageSize":2,"total":5}"#)
        #expect(page.hasMore == false)
        #expect(page.nextPage == nil)
    }

    /// Une page au-delà du dernier élément renvoie `items` vide et le `total` réel :
    /// ce n'est pas une erreur, le contrat le dit explicitement.
    @Test func pageBeyondTheEndIsEmptyAndNotAnError() throws {
        let page: PagedList<String> = try decode(#"{"items":[],"page":99,"pageSize":25,"total":213}"#)
        #expect(page.items.isEmpty)
        #expect(page.total == 213)
    }

    /// Décodage tolérant : un tableau nu, contrat antérieur à GenEngine#55, reste lisible.
    @Test func bareArrayIsReadAsASingleCompletePage() throws {
        let page: PagedList<String> = try decode(#"["a","b","c"]"#)
        #expect(page.items.count == 3)
        #expect(page.page == 1)
        #expect(page.total == 3)
        #expect(page.hasMore == false)
    }

    /// Décodage tolérant : une métadonnée absente ne fait pas échouer la réponse entière.
    @Test func missingMetadataFallsBackOnTheItems() throws {
        let page: PagedList<String> = try decode(#"{"items":["a","b"]}"#)
        #expect(page.items.count == 2)
        #expect(page.page == 1)
        #expect(page.total == 2)
    }

    /// Un `total` incohérent ne doit jamais faire croire que la page affichée est vide.
    @Test func inconsistentTotalNeverHidesLoadedItems() throws {
        let page: PagedList<String> = try decode(#"{"items":["a","b"],"page":3,"pageSize":2,"total":0}"#)
        #expect(page.total == 6)
    }

    // MARK: - Comportement de l'état applicatif

    @Test func firstLoadKeepsTheServerTotalAndNotThePageSize() async {
        let state = makeState(catalog: CatalogStub(count: 213))
        await state.loadCatalog()
        #expect(state.publishedStories.count == state.catalogPageSize)
        #expect(state.catalogTotal == 213)
        #expect(state.hasMorePublishedStories)
    }

    @Test func scrollingReachesEveryPublishedStory() async {
        let state = makeState(catalog: CatalogStub(count: 213))
        await state.loadCatalog()
        var guardRail = 0
        while state.hasMorePublishedStories, guardRail < 50 {
            await state.loadMorePublishedStories()
            guardRail += 1
        }
        #expect(state.publishedStories.count == 213)
        #expect(Set(state.publishedStories.map(\.id)).count == 213)
        // Le 213ᵉ récit, inatteignable sous l'ancien plafond de 100, est chargé.
        #expect(state.stories.contains { $0.title == "Récit 213" })
    }

    @Test func searchIsAppliedByTheServerAndResetsToTheFirstPage() async {
        let stub = CatalogStub(count: 213)
        let state = makeState(catalog: stub)
        await state.loadCatalog()
        await state.loadMorePublishedStories()
        #expect(state.publishedStories.count > state.catalogPageSize)

        await state.searchCatalog("Récit 1")
        #expect(await stub.lastQuery == "Récit 1")
        #expect(state.catalogPage == 1)
        // Le total est celui de l'ensemble filtré côté serveur, pas de la page affichée.
        // « Récit 1 », « Récit 10 » à « Récit 19 », « Récit 100 » à « Récit 199 ».
        #expect(state.catalogTotal == 111)
        #expect(state.publishedStories.count == state.catalogPageSize)
    }

    /// Un filtrage purement client donnerait ici un résultat faux : les correspondances
    /// situées au-delà de la première page seraient invisibles.
    @Test func serverSearchFindsMatchesBeyondTheFirstPage() async {
        let state = makeState(catalog: CatalogStub(count: 213))
        await state.loadCatalog()
        await state.searchCatalog("Récit 200")
        #expect(state.publishedStories.contains { $0.title == "Récit 200" })
    }

    @Test func requestedPageSizeStaysWithinTheServerBounds() async {
        let state = makeState(catalog: CatalogStub(count: 213))
        #expect(state.catalogPageSize >= 1)
        #expect(state.catalogPageSize <= 100)
    }

    // MARK: - Outillage

    private func makeState(catalog: CatalogStub) -> AppState {
        AppState(api: catalog, vault: StubVault())
    }

    private struct StubVault: TokenStoring {
        func load() -> String? { "token" }
        func save(_ token: String) throws {}
        func clear() throws {}
    }

    /// Reproduit la sémantique documentée : tri stable, filtre `query` insensible à la
    /// casse, `Skip`/`Take`, `total` sur l'ensemble filtré.
    private actor CatalogStub: GenEngineAPI {
        private let all: [PublishedScenarioView]
        private(set) var lastQuery = ""

        init(count: Int) {
            all = (1...count).map { index in
                PublishedScenarioView(
                    scenarioId: UUID(),
                    versionId: UUID(),
                    versionNumber: 1,
                    title: "Récit \(index)",
                    description: "Description \(index)",
                    estimatedMinutes: 20,
                    publishedAt: Date(timeIntervalSince1970: TimeInterval(count - index)),
                    snapshotHash: "hash-\(index)",
                    categoryId: nil)
            }
        }

        func update(endpoints _: ServiceEndpoints) async {}
        func setToken(_: String?) async {}
        func register(userName _: String, password _: String) async throws -> AccessToken { throw APIError.invalidScenario("stub") }
        func login(userName _: String, password _: String) async throws -> AccessToken { throw APIError.invalidScenario("stub") }
        func importScenario(rawJSON _: Data) async throws -> ScenarioView { throw APIError.invalidScenario("stub") }
        func validate(scenarioId _: UUID) async throws -> ValidationReport { throw APIError.invalidScenario("stub") }
        func analyze(scenarioId _: UUID) async throws -> NarrativeStructureReport { throw APIError.invalidScenario("stub") }
        func preview(scenarioId _: UUID, request _: ScenarioPreviewRequest) async throws -> ScenarioPreview { throw APIError.invalidScenario("stub") }
        func publish(scenarioId _: UUID, expectedRevision _: Int) async throws -> ScenarioVersionView { throw APIError.invalidScenario("stub") }
        func startSession(scenarioVersionId _: UUID, seed _: UInt64) async throws -> SessionView { throw APIError.invalidScenario("stub") }
        func session(sessionId _: UUID) async throws -> SessionView { throw APIError.invalidScenario("stub") }
        func currentStep(sessionId _: UUID) async throws -> CurrentStep { throw APIError.invalidScenario("stub") }
        func sessionTree(sessionId _: UUID) async throws -> NarrativeTree { throw APIError.invalidScenario("stub") }
        func submitChoice(sessionId _: UUID, commandId _: UUID, expectedRevision _: Int, choiceId _: String) async throws -> InputResult { throw APIError.invalidScenario("stub") }
        func continueInteraction(sessionId _: UUID, commandId _: UUID, expectedRevision _: Int) async throws -> InputResult { throw APIError.invalidScenario("stub") }
        func consultDocument(sessionId _: UUID, commandId _: UUID, expectedRevision _: Int) async throws -> InputResult { throw APIError.invalidScenario("stub") }
        func submitAnswer(sessionId _: UUID, commandId _: UUID, expectedRevision _: Int, answerId _: String) async throws -> InputResult { throw APIError.invalidScenario("stub") }
        func submitText(sessionId _: UUID, commandId _: UUID, expectedRevision _: Int, text _: String) async throws -> InputResult { throw APIError.invalidScenario("stub") }
        func confirmTextAnalysis(sessionId _: UUID, commandId _: UUID, expectedRevision _: Int, confirmed _: Bool) async throws -> InputResult { throw APIError.invalidScenario("stub") }
        func pause(sessionId _: UUID, expectedRevision _: Int) async throws -> SessionView { throw APIError.invalidScenario("stub") }
        func resume(sessionId _: UUID, expectedRevision _: Int) async throws -> SessionView { throw APIError.invalidScenario("stub") }

        func listPublishedStories(page: Int, pageSize: Int, query: String) async throws -> PagedPublishedScenariosView {
            lastQuery = query
            let requestedPage = max(page, 1)
            let size = min(max(pageSize, 1), 100)
            let filtered = query.isEmpty ? all : all.filter { $0.title.localizedCaseInsensitiveContains(query) }
            let start = min((requestedPage - 1) * size, filtered.count)
            let end = min(start + size, filtered.count)
            return PagedPublishedScenariosView(
                items: Array(filtered[start..<end]),
                page: requestedPage,
                pageSize: size,
                total: filtered.count)
        }
    }
}
