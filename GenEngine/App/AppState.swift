import Foundation
import Observation

enum AppTab: Hashable {
    case home
    case library
    case experience
    case studio
    case administration
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
    private(set) var tree: NarrativeTree?
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
    private(set) var savedSessions: [SavedSession] = SessionStore.load()
    private(set) var access: UserAccessView?
    private(set) var experience: PublishedExperienceView?
    private(set) var playerExperience: PlayerExperienceView?
    private(set) var adminConfiguration: ExperienceConfigurationView?
    private(set) var permissionsCatalog: [PermissionView] = []
    private(set) var roles: [RoleView] = []
    private(set) var adminUsers: [AdminUserView] = []
    private(set) var adminUsersTotal = 0
    private(set) var authorScenarios: [ScenarioView] = []
    private(set) var authorScenariosTotal = 0
    private(set) var generatedScenario: ScenarioView?
    let frontId = "default"
    private let microsoftSignIn = MicrosoftSignInCoordinator()

    var hasProductAccess: Bool { isAuthenticated || isDemoAccess }
    var gameName: String { experience?.document.game.name ?? "GenEngine" }
    func copy(_ key: String, fallback: String) -> String {
        guard let value = experience?.document.language.labels[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return fallback }
        return value
    }
    func hasPermission(_ permission: String) -> Bool { access?.permissions.contains(permission) == true }
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
        if token != nil { Task { await self.loadPlatformContext() } }
        else { Task { await self.loadPublicExperience() } }
    }

    func loadPublicExperience() async {
        do { experience = try await api.publicExperience(frontId: frontId) }
        catch is CancellationError { }
        catch { developerLog.insert("✗ Configuration publique: \(error.localizedDescription)", at: 0) }
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
            try await self.refreshPlatformContext()
        }
    }

    func register() async {
        await run("Création du compte") {
            let access = try await self.api.register(userName: self.userName, password: self.password)
            try self.vault.save(access.token)
            self.password = ""
            self.isAuthenticated = true
            try await self.refreshPlatformContext()
        }
    }

    func loginWithMicrosoft() async {
        await run("Connexion Microsoft") {
            let providers = try await self.api.authenticationProviders()
            guard providers.entraEnabled, let authority = providers.authority, let clientId = providers.clientId else {
                throw APIError.invalidScenario("La connexion Microsoft n’est pas activée pour ce jeu.")
            }
            let externalToken = try await self.microsoftSignIn.signIn(authority: authority, clientId: clientId)
            let access = try await self.api.exchangeEntra(accessToken: externalToken)
            try self.vault.save(access.token)
            self.isAuthenticated = true
            try await self.refreshPlatformContext()
        }
    }

    func loadPlatformContext() async {
        do { try await refreshPlatformContext() }
        catch is CancellationError { }
        catch { developerLog.insert("✗ Plateforme: \(error.localizedDescription)", at: 0) }
    }

    func saveFamiliar(_ selection: FamiliarSelection) async {
        guard let playerExperience else { return }
        await run("Familier configuré") {
            self.playerExperience = try await self.api.configureFamiliar(
                frontId: self.frontId,
                request: ConfigureFamiliarRequest(expectedRevision: playerExperience.revision, selection: selection))
        }
    }

    func purchase(_ offer: OfferDefinition) async {
        await run("Achat \(offer.name)") {
            self.playerExperience = try await self.api.purchase(
                frontId: self.frontId,
                request: PurchaseRequest(offerId: offer.id, idempotencyKey: UUID().uuidString.lowercased()))
        }
    }

    func loadAdministration() async {
        guard hasPermission("config.read") else { return }
        await run("Administration chargée") {
            self.adminConfiguration = try await self.api.adminConfiguration(frontId: self.frontId)
            if self.hasPermission("rbac.manage") {
                async let permissions = self.api.permissions()
                async let roles = self.api.roles()
                self.permissionsCatalog = try await permissions
                self.roles = try await roles
            }
            if self.hasPermission("identity.user.read") || self.hasPermission("identity.user.manage") {
                let page = try await self.api.users(query: "")
                self.adminUsers = page.items
                self.adminUsersTotal = page.total
            }
        }
    }

    func saveConfiguration(_ document: ExperienceDocument) async {
        guard let current = adminConfiguration else { return }
        await run("Configuration enregistrée") {
            self.adminConfiguration = try await self.api.updateConfiguration(
                frontId: self.frontId,
                request: UpdateConfigurationRequest(expectedRevision: current.revision, document: document))
        }
    }

    func publishConfiguration() async {
        guard let current = adminConfiguration else { return }
        await run("Configuration publiée") {
            self.adminConfiguration = try await self.api.publishConfiguration(
                frontId: self.frontId,
                request: PublishConfigurationRequest(expectedRevision: current.revision))
            self.experience = try await self.api.publicExperience(frontId: self.frontId)
        }
    }

    func createRole(name: String, description: String, permissions: [String]) async {
        await run("Rôle créé") {
            _ = try await self.api.createRole(request: RoleRequest(name: name, description: description, permissions: permissions))
            self.roles = try await self.api.roles()
        }
    }

    func assignRole(userId: UUID, roleId: UUID, scope: String?) async {
        await run("Rôle affecté") {
            try await self.api.assignRole(userId: userId, request: AssignRoleRequest(roleId: roleId, scope: scope, expiresAt: nil))
        }
    }

    func searchUsers(_ query: String) async {
        await run("Utilisateurs chargés") {
            let page = try await self.api.users(query: query)
            self.adminUsers = page.items
            self.adminUsersTotal = page.total
        }
    }

    func setUserActive(_ user: AdminUserView, isActive: Bool) async {
        await run(isActive ? "Compte réactivé" : "Compte désactivé") {
            _ = try await self.api.setUserActive(userId: user.id, isActive: isActive)
            let page = try await self.api.users(query: "")
            self.adminUsers = page.items
            self.adminUsersTotal = page.total
        }
    }

    func deleteUser(_ user: AdminUserView) async {
        await run("Compte supprimé") {
            try await self.api.deleteUser(userId: user.id)
            let page = try await self.api.users(query: "")
            self.adminUsers = page.items
            self.adminUsersTotal = page.total
        }
    }

    func deleteRole(_ role: RoleView) async {
        await run("Rôle supprimé") {
            try await self.api.deleteRole(roleId: role.id)
            self.roles = try await self.api.roles()
        }
    }

    func generateScenario(categoryId: UUID, prompt: String, provider: String, targetMinutes: Int, tone: String) async {
        await run("Scénario généré") {
            self.generatedScenario = try await self.api.generateScenario(request: ScenarioGenerationRequest(
                frontId: self.frontId,
                categoryId: categoryId,
                prompt: prompt,
                provider: provider,
                targetMinutes: targetMinutes,
                tone: tone))
            try await self.refreshScenarios()
        }
    }

    func searchScenarios(_ query: String = "") async {
        await run("Bibliothèque du Studio chargée") { try await self.refreshScenarios(query: query) }
    }

    func selectScenario(_ scenario: ScenarioView) { generatedScenario = scenario }

    func updateScenario(document: Data) async {
        guard let current = generatedScenario else { return }
        await run("Brouillon enregistré") {
            self.generatedScenario = try await self.api.updateScenario(
                scenarioId: current.id,
                expectedRevision: current.revision,
                document: document)
            try await self.refreshScenarios()
        }
    }

    func archiveScenario(_ scenario: ScenarioView) async {
        await run("Scénario archivé") {
            try await self.api.archiveScenario(scenarioId: scenario.id, expectedRevision: scenario.revision)
            if self.generatedScenario?.id == scenario.id { self.generatedScenario = nil }
            try await self.refreshScenarios()
        }
    }

    func signOut() {
        try? vault.clear()
        Task { await api.setToken(nil) }
        isAuthenticated = false
        isDemoAccess = false
        access = nil
        playerExperience = nil
        adminConfiguration = nil
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
            self.remember(result.session)
            await self.refreshTree()
        }
    }

    func continueInteraction() async {
        guard let session, !isDemoSession else { return }
        await performInput("Narration continuée") {
            try await self.api.continueInteraction(sessionId: session.id, commandId: UUID(), expectedRevision: session.revision)
        }
    }

    func submit(answerID: String) async {
        guard let session, !isDemoSession else { return }
        await performInput("Réponse envoyée") {
            try await self.api.submitAnswer(sessionId: session.id, commandId: UUID(), expectedRevision: session.revision, answerId: answerID)
        }
    }

    func submit(text: String) async {
        guard let session, !isDemoSession else { return }
        await performInput("Texte analysé") {
            try await self.api.submitText(sessionId: session.id, commandId: UUID(), expectedRevision: session.revision, text: text)
        }
    }

    func confirmTextAnalysis(_ confirmed: Bool) async {
        guard let session, !isDemoSession else { return }
        await performInput(confirmed ? "Analyse confirmée" : "Nouvelle saisie demandée") {
            try await self.api.confirmTextAnalysis(sessionId: session.id, commandId: UUID(), expectedRevision: session.revision, confirmed: confirmed)
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
            if let updated = self.session { self.remember(updated) }
        }
    }

    func resume(_ saved: SavedSession) async {
        await run("Reprise de l’histoire") {
            let session = try await self.api.session(sessionId: saved.id)
            let story = self.stories.first { item in
                if case let .published(versionID) = item.availability { return versionID == session.scenarioVersionId }
                return false
            } ?? StorySummary(id: session.scenarioVersionId.uuidString.lowercased(), title: saved.title, eyebrow: "Session sauvegardée", synopsis: "Reprenez cette histoire depuis le moteur GenEngine.", duration: "Tour \(session.turn + 1)", symbol: "bookmark.fill", accent: .verdigris, availability: .published(session.scenarioVersionId))
            self.currentStory = story
            self.isDemoSession = false
            self.session = session
            self.step = try await self.api.currentStep(sessionId: session.id)
            self.remember(session)
            await self.refreshTree()
        }
    }

    func loadTree() async { await refreshTree() }

    func endSession() {
        session = nil
        step = nil
        currentStory = nil
        isDemoSession = false
        tree = nil
    }

    #if DEBUG
    func importAndPublish(_ data: Data, label: String) async {
        await run("Import \(label)") {
            let scenario = try await self.api.importScenario(rawJSON: data)
            let validation = try await self.api.validate(scenarioId: scenario.id)
            guard validation.isValid else {
                let errors = validation.issues.filter(\.isError).map(\.code).joined(separator: ", ")
                throw APIError.invalidScenario("Validation refusée : \(errors)")
            }
            let analysis = try await self.api.analyze(scenarioId: scenario.id)
            self.developerLog.insert("Analysis: \(analysis.loops.count) loop(s), \(analysis.conditionalDeadEnds.count) conditional dead end(s)", at: 0)
            if let document = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let initialNodeID = document["initialNodeId"] as? String {
                do {
                    let preview = try await self.api.preview(scenarioId: scenario.id, request: ScenarioPreviewRequest(nodeId: initialNodeID, turn: 0, variables: [:], characteristics: [:], inventory: [], evidence: [], relations: [:], rewards: [], visitedNodes: []))
                    self.developerLog.insert("Preview: \(preview.currentStep.kind) at \(preview.currentStep.nodeId)", at: 0)
                } catch {
                    self.developerLog.insert("Preview unavailable for empty injected state: \(error.localizedDescription)", at: 0)
                }
            }
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
            self.remember(session)
            await self.refreshTree()
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

    private func performInput(_ label: String, operation: @escaping @MainActor () async throws -> InputResult) async {
        await run(label) {
            let result = try await operation()
            self.session = result.session
            self.step = result.currentStep
            self.remember(result.session)
            await self.refreshTree()
        }
    }

    private func refreshTree() async {
        guard let session, !isDemoSession else { tree = nil; return }
        do { tree = try await api.sessionTree(sessionId: session.id) }
        catch is CancellationError { }
        catch { developerLog.insert("✗ Arbre: \(error.localizedDescription)", at: 0) }
    }

    private func refreshScenarios(query: String = "") async throws {
        let page = try await api.scenarios(query: query)
        authorScenarios = page.items
        authorScenariosTotal = page.total
    }

    private func refreshPlatformContext() async throws {
        async let access = api.access()
        async let experience = api.publicExperience(frontId: frontId)
        self.access = try await access
        self.experience = try await experience
        if hasPermission("session.play") {
            self.playerExperience = try await api.playerExperience(frontId: frontId)
        }
    }

    private func remember(_ session: SessionView) {
        let title = currentStory?.title ?? savedSessions.first(where: { $0.id == session.id })?.title ?? "Histoire GenEngine"
        let saved = SavedSession(id: session.id, scenarioVersionId: session.scenarioVersionId, title: title, status: session.status.label, revision: session.revision, turn: session.turn, updatedAt: .now)
        savedSessions.removeAll { $0.id == session.id }
        savedSessions.insert(saved, at: 0)
        savedSessions = Array(savedSessions.prefix(20))
        SessionStore.save(savedSessions)
    }
}

private enum SessionStore {
    private static let key = "genengine.saved-sessions.v1"

    static func load() -> [SavedSession] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedSession].self, from: data)) ?? []
    }

    static func save(_ sessions: [SavedSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
