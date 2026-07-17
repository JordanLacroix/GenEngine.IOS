import Foundation
import Observation

enum AppTab: Hashable {
    case home
    case library
    #if DEBUG
    case developer
    #endif
}

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .home
    var endpoints: ServiceEndpoints {
        didSet {
            EndpointStore.save(endpoints)
            let value = endpoints
            Task { await api.update(endpoints: value) }
        }
    }
    var userName = ""
    var password = ""
    private(set) var isAuthenticated: Bool
    private(set) var isDemoAccess = false
    private(set) var currentStory: StorySummary?
    private(set) var session: SessionView?
    private(set) var step: CurrentStep?
    private(set) var isDemoSession = false
    private(set) var scenarioVersionID: UUID?
    private(set) var publishedTitle: String?
    var seedText = "42"
    var isBusy = false
    var errorMessage: String?
    private(set) var publishedStories: [StorySummary] = []
    private(set) var isLoadingCatalog = false
    private var hasLoadedCatalog = false
    private(set) var developerLog: [String] = []

    var hasProductAccess: Bool { isAuthenticated || isDemoAccess }
    var stories: [StorySummary] {
        var items = [DemoStory.summary]
        items.append(contentsOf: publishedStories)
        items.append(contentsOf: DemoStory.library.dropFirst())
        if let scenarioVersionID, let publishedTitle {
            let id = scenarioVersionID.uuidString.lowercased()
            if !items.contains(where: { $0.id == id }) {
                items.insert(StorySummary(id: id, title: publishedTitle, eyebrow: "Publié localement", synopsis: "Une histoire connectée à votre environnement GenEngine.", duration: "À découvrir", symbol: "network", accent: .verdigris, availability: .published(scenarioVersionID)), at: 1)
            }
        }
        return items
    }

    private let api: any GenEngineAPI
    private let vault: any TokenStoring

    init(api: (any GenEngineAPI)? = nil, vault: (any TokenStoring)? = nil) {
        let endpoints = EndpointStore.load()
        let vault = vault ?? KeychainTokenVault()
        let token = vault.load()
        self.endpoints = endpoints
        self.vault = vault
        self.api = api ?? LiveGenEngineAPI(endpoints: endpoints, token: token)
        self.isAuthenticated = token != nil
    }

    func unlockDemo() {
        isDemoAccess = true
        errorMessage = nil
    }

    func loadCatalog(force: Bool = false) async {
        guard !isLoadingCatalog, force || !hasLoadedCatalog else { return }
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }
        do {
            publishedStories = try await api.listPublishedStories().map(StorySummary.init(published:))
            hasLoadedCatalog = true
            developerLog.insert("✓ Catalogue actualisé", at: 0)
        } catch is CancellationError {
            developerLog.insert("– Catalogue annulé", at: 0)
        } catch {
            developerLog.insert("✗ Catalogue: \(error.localizedDescription)", at: 0)
        }
    }

    func login() async {
        guard !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            errorMessage = "Saisissez votre identifiant et votre mot de passe."
            return
        }
        await run("Connexion") {
            let access = try await self.api.login(userName: self.userName, password: self.password)
            try self.vault.save(access.token)
            self.password = ""
            self.isAuthenticated = true
        }
    }

    func register() async {
        await run("Création du compte") {
            let access = try await self.api.register(userName: self.userName, password: self.password)
            try self.vault.save(access.token)
            self.password = ""
            self.isAuthenticated = true
        }
    }

    func signOut() {
        try? vault.clear()
        Task { await api.setToken(nil) }
        isAuthenticated = false
        isDemoAccess = false
        endSession()
    }

    func open(_ story: StorySummary) async {
        switch story.availability {
        case .demo: startDemo()
        case let .published(versionID): await startRemote(versionID: versionID, story: story)
        case .comingSoon: errorMessage = "Cette histoire est encore en cours d’écriture."
        }
    }

    func startDemo() {
        guard let node = DemoStory.node(id: DemoStory.openingNodeID) else { return }
        currentStory = DemoStory.summary
        isDemoSession = true
        session = SessionView(id: UUID(), scenarioVersionId: UUID(), snapshotHash: "demo", status: .awaitingInput, revision: 0, turn: 0)
        step = makeStep(node, turn: 0)
    }

    func submit(choiceID: String) async {
        guard let session else { return }
        if isDemoSession {
            guard let choice = DemoStory.node(id: step?.nodeId ?? "")?.choices.first(where: { $0.id == choiceID }),
                  let node = DemoStory.node(id: choice.target) else { return }
            let turn = session.turn + 1
            self.session = SessionView(id: session.id, scenarioVersionId: session.scenarioVersionId, snapshotHash: session.snapshotHash, status: node.isEnding ? .completed : .awaitingInput, revision: session.revision + 1, turn: turn)
            step = makeStep(node, turn: turn)
            return
        }
        await run("Choix envoyé") {
            let result = try await self.api.submitChoice(sessionId: session.id, commandId: UUID(), expectedRevision: session.revision, choiceId: choiceID)
            self.session = result.session
            self.step = result.currentStep
        }
    }

    func pauseOrResume() async {
        guard let session, !isDemoSession else { return }
        await run(session.status == .paused ? "Reprise" : "Pause") {
            if session.status == .paused {
                let updated = try await self.api.resume(sessionId: session.id, expectedRevision: session.revision)
                self.session = updated
                self.step = try await self.api.currentStep(sessionId: session.id)
            } else {
                self.session = try await self.api.pause(sessionId: session.id, expectedRevision: session.revision)
            }
        }
    }

    func endSession() {
        session = nil
        step = nil
        currentStory = nil
        isDemoSession = false
    }

    #if DEBUG
    func importAndPublish(_ data: Data, label: String) async {
        await run("Import \(label)") {
            let scenario = try await self.api.importScenario(rawJSON: data)
            let version = try await self.api.publish(scenarioId: scenario.id, expectedRevision: scenario.revision)
            self.scenarioVersionID = version.id
            self.publishedTitle = scenario.title
            self.developerLog.insert("Published \(version.id.uuidString.lowercased())", at: 0)
            await self.loadCatalog(force: true)
        }
    }
    #endif

    private func startRemote(versionID: UUID, story: StorySummary) async {
        await run("Démarrage de l’histoire") {
            let seed = UInt64(self.seedText) ?? 42
            let session = try await self.api.startSession(scenarioVersionId: versionID, seed: seed)
            self.currentStory = story
            self.isDemoSession = false
            self.session = session
            self.step = try await self.api.currentStep(sessionId: session.id)
        }
    }

    private func makeStep(_ node: DemoNode, turn: Int) -> CurrentStep {
        CurrentStep(nodeId: node.id, text: node.text, status: node.isEnding ? .completed : .awaitingInput, choices: node.choices.map { VisibleChoice(id: $0.id, text: $0.text) }, turn: turn)
    }

    private func run(_ label: String, operation: @escaping @MainActor () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await operation()
            developerLog.insert("✓ \(label)", at: 0)
        } catch is CancellationError {
            developerLog.insert("– \(label) annulé", at: 0)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            developerLog.insert("✗ \(label): \(error.localizedDescription)", at: 0)
        }
    }
}
