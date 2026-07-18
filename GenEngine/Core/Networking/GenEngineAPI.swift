import Foundation

protocol GenEngineAPI: Sendable {
    func update(endpoints: ServiceEndpoints) async
    func setToken(_ token: String?) async
    func register(userName: String, password: String) async throws -> AccessToken
    func login(userName: String, password: String) async throws -> AccessToken
    func authenticationProviders() async throws -> AuthenticationProvidersView
    func exchangeEntra(accessToken: String) async throws -> AccessToken
    func access() async throws -> UserAccessView
    func publicExperience(frontId: String) async throws -> PublishedExperienceView
    func playerExperience(frontId: String) async throws -> PlayerExperienceView
    func playerBootstrap(frontId: String) async throws -> PlayerBootstrapView
    func completeOnboardingStep(frontId: String, stepId: UUID) async throws -> OnboardingStateView
    func skipOnboarding(frontId: String) async throws -> OnboardingStateView
    func resetOnboarding(frontId: String) async throws -> OnboardingStateView
    func journal(frontId: String) async throws -> JournalView
    func contextualHelp(frontId: String, request: ContextualHelpRequest) async throws -> ContextualHelpView
    func configureFamiliar(frontId: String, request: ConfigureFamiliarRequest) async throws -> PlayerExperienceView
    func purchase(frontId: String, request: PurchaseRequest) async throws -> PlayerExperienceView
    func adminConfiguration(frontId: String) async throws -> ExperienceConfigurationView
    func updateConfiguration(frontId: String, request: UpdateConfigurationRequest) async throws -> ExperienceConfigurationView
    func publishConfiguration(frontId: String, request: PublishConfigurationRequest) async throws -> ExperienceConfigurationView
    func permissions() async throws -> [PermissionView]
    func roles() async throws -> [RoleView]
    func createRole(request: RoleRequest) async throws -> RoleView
    func assignRole(userId: UUID, request: AssignRoleRequest) async throws
    func users(query: String) async throws -> PagedUsersView
    func setUserActive(userId: UUID, isActive: Bool) async throws -> AdminUserView
    func deleteUser(userId: UUID) async throws
    func deleteRole(roleId: UUID) async throws
    func organizationFront(frontId: String) async throws -> OrganizationFrontView
    func organizationUnits(frontId: String) async throws -> [OrganizationUnitView]
    func memberships(frontId: String) async throws -> PagedMembershipsView
    func assignments(frontId: String) async throws -> PagedAssignmentsView
    func upsertUnit(frontId: String, id: UUID, request: UpsertUnitRequest) async throws -> OrganizationUnitView
    func upsertMembership(frontId: String, id: UUID, request: UpsertMembershipRequest) async throws -> MembershipView
    func deleteMembership(frontId: String, id: UUID) async throws
    func upsertAssignment(frontId: String, id: UUID, request: UpsertAssignmentRequest) async throws -> ContentAssignmentView
    func deleteAssignment(frontId: String, id: UUID) async throws
    func scenarios(query: String) async throws -> PagedScenariosView
    func updateScenario(scenarioId: UUID, expectedRevision: Int, document: Data) async throws -> ScenarioView
    func archiveScenario(scenarioId: UUID, expectedRevision: Int) async throws
    func generateScenario(request: ScenarioGenerationRequest) async throws -> ScenarioView
    func listPublishedStories() async throws -> [PublishedScenarioView]
    func importScenario(rawJSON: Data) async throws -> ScenarioView
    func validate(scenarioId: UUID) async throws -> ValidationReport
    func analyze(scenarioId: UUID) async throws -> NarrativeStructureReport
    func preview(scenarioId: UUID, request: ScenarioPreviewRequest) async throws -> ScenarioPreview
    func publish(scenarioId: UUID, expectedRevision: Int) async throws -> ScenarioVersionView
    func startSession(scenarioVersionId: UUID, seed: UInt64) async throws -> SessionView
    func session(sessionId: UUID) async throws -> SessionView
    func currentStep(sessionId: UUID) async throws -> CurrentStep
    func sessionTree(sessionId: UUID) async throws -> NarrativeTree
    func submitChoice(sessionId: UUID, commandId: UUID, expectedRevision: Int, choiceId: String) async throws -> InputResult
    func continueInteraction(sessionId: UUID, commandId: UUID, expectedRevision: Int) async throws -> InputResult
    func submitAnswer(sessionId: UUID, commandId: UUID, expectedRevision: Int, answerId: String) async throws -> InputResult
    func submitText(sessionId: UUID, commandId: UUID, expectedRevision: Int, text: String) async throws -> InputResult
    func confirmTextAnalysis(sessionId: UUID, commandId: UUID, expectedRevision: Int, confirmed: Bool) async throws -> InputResult
    func pause(sessionId: UUID, expectedRevision: Int) async throws -> SessionView
    func resume(sessionId: UUID, expectedRevision: Int) async throws -> SessionView
}

extension GenEngineAPI {
    func authenticationProviders() async throws -> AuthenticationProvidersView { throw APIError.invalidScenario("Fonction indisponible.") }
    func exchangeEntra(accessToken _: String) async throws -> AccessToken { throw APIError.invalidScenario("Fonction indisponible.") }
    func access() async throws -> UserAccessView { throw APIError.invalidScenario("Fonction indisponible.") }
    func publicExperience(frontId _: String) async throws -> PublishedExperienceView { throw APIError.invalidScenario("Fonction indisponible.") }
    func playerExperience(frontId _: String) async throws -> PlayerExperienceView { throw APIError.invalidScenario("Fonction indisponible.") }
    func playerBootstrap(frontId _: String) async throws -> PlayerBootstrapView { throw APIError.invalidScenario("Fonction indisponible.") }
    func completeOnboardingStep(frontId _: String, stepId _: UUID) async throws -> OnboardingStateView { throw APIError.invalidScenario("Fonction indisponible.") }
    func skipOnboarding(frontId _: String) async throws -> OnboardingStateView { throw APIError.invalidScenario("Fonction indisponible.") }
    func resetOnboarding(frontId _: String) async throws -> OnboardingStateView { throw APIError.invalidScenario("Fonction indisponible.") }
    func journal(frontId _: String) async throws -> JournalView { throw APIError.invalidScenario("Fonction indisponible.") }
    func contextualHelp(frontId _: String, request _: ContextualHelpRequest) async throws -> ContextualHelpView { throw APIError.invalidScenario("Fonction indisponible.") }
    func configureFamiliar(frontId _: String, request _: ConfigureFamiliarRequest) async throws -> PlayerExperienceView { throw APIError.invalidScenario("Fonction indisponible.") }
    func purchase(frontId _: String, request _: PurchaseRequest) async throws -> PlayerExperienceView { throw APIError.invalidScenario("Fonction indisponible.") }
    func adminConfiguration(frontId _: String) async throws -> ExperienceConfigurationView { throw APIError.invalidScenario("Fonction indisponible.") }
    func updateConfiguration(frontId _: String, request _: UpdateConfigurationRequest) async throws -> ExperienceConfigurationView { throw APIError.invalidScenario("Fonction indisponible.") }
    func publishConfiguration(frontId _: String, request _: PublishConfigurationRequest) async throws -> ExperienceConfigurationView { throw APIError.invalidScenario("Fonction indisponible.") }
    func permissions() async throws -> [PermissionView] { throw APIError.invalidScenario("Fonction indisponible.") }
    func roles() async throws -> [RoleView] { throw APIError.invalidScenario("Fonction indisponible.") }
    func createRole(request _: RoleRequest) async throws -> RoleView { throw APIError.invalidScenario("Fonction indisponible.") }
    func assignRole(userId _: UUID, request _: AssignRoleRequest) async throws { throw APIError.invalidScenario("Fonction indisponible.") }
    func users(query _: String) async throws -> PagedUsersView { throw APIError.invalidScenario("Fonction indisponible.") }
    func setUserActive(userId _: UUID, isActive _: Bool) async throws -> AdminUserView { throw APIError.invalidScenario("Fonction indisponible.") }
    func deleteUser(userId _: UUID) async throws { throw APIError.invalidScenario("Fonction indisponible.") }
    func deleteRole(roleId _: UUID) async throws { throw APIError.invalidScenario("Fonction indisponible.") }
    func organizationFront(frontId _: String) async throws -> OrganizationFrontView { throw APIError.invalidScenario("Fonction indisponible.") }
    func organizationUnits(frontId _: String) async throws -> [OrganizationUnitView] { throw APIError.invalidScenario("Fonction indisponible.") }
    func memberships(frontId _: String) async throws -> PagedMembershipsView { throw APIError.invalidScenario("Fonction indisponible.") }
    func assignments(frontId _: String) async throws -> PagedAssignmentsView { throw APIError.invalidScenario("Fonction indisponible.") }
    func upsertUnit(frontId _: String, id _: UUID, request _: UpsertUnitRequest) async throws -> OrganizationUnitView { throw APIError.invalidScenario("Fonction indisponible.") }
    func upsertMembership(frontId _: String, id _: UUID, request _: UpsertMembershipRequest) async throws -> MembershipView { throw APIError.invalidScenario("Fonction indisponible.") }
    func deleteMembership(frontId _: String, id _: UUID) async throws { throw APIError.invalidScenario("Fonction indisponible.") }
    func upsertAssignment(frontId _: String, id _: UUID, request _: UpsertAssignmentRequest) async throws -> ContentAssignmentView { throw APIError.invalidScenario("Fonction indisponible.") }
    func deleteAssignment(frontId _: String, id _: UUID) async throws { throw APIError.invalidScenario("Fonction indisponible.") }
    func scenarios(query _: String) async throws -> PagedScenariosView { throw APIError.invalidScenario("Fonction indisponible.") }
    func updateScenario(scenarioId _: UUID, expectedRevision _: Int, document _: Data) async throws -> ScenarioView { throw APIError.invalidScenario("Fonction indisponible.") }
    func archiveScenario(scenarioId _: UUID, expectedRevision _: Int) async throws { throw APIError.invalidScenario("Fonction indisponible.") }
    func generateScenario(request _: ScenarioGenerationRequest) async throws -> ScenarioView { throw APIError.invalidScenario("Fonction indisponible.") }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidScenario(String)
    case http(Int, ProblemDetails?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "L’adresse du service est invalide."
        case let .invalidScenario(message): message
        case let .http(code, problem):
            "Le service a répondu \(code)" + [problem?.title, problem?.detail].compactMap { $0 }.filter { !$0.isEmpty }.map { " — \($0)" }.joined()
        case let .decoding(message): "La réponse du service est incompatible — \(message)"
        case let .transport(message): "Connexion impossible — \(message)"
        }
    }
}

actor LiveGenEngineAPI: GenEngineAPI {
    private var endpoints: ServiceEndpoints
    private var token: String?
    private let session: URLSession

    init(endpoints: ServiceEndpoints, token: String? = nil) {
        self.endpoints = endpoints
        self.token = token
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func update(endpoints: ServiceEndpoints) { self.endpoints = endpoints }
    func setToken(_ token: String?) { self.token = token }

    func register(userName: String, password: String) async throws -> AccessToken {
        try await sendVoid(method: "POST", base: endpoints.identity, path: "/auth/register", body: CredentialsRequest(userName: userName, password: password), authenticated: false)
        return try await login(userName: userName, password: password)
    }

    func login(userName: String, password: String) async throws -> AccessToken {
        let access: AccessToken = try await send(method: "POST", base: endpoints.identity, path: "/auth/login", body: CredentialsRequest(userName: userName, password: password), authenticated: false)
        token = access.token
        return access
    }

    func authenticationProviders() async throws -> AuthenticationProvidersView {
        try await perform(method: "GET", base: endpoints.identity, path: "/auth/providers", body: nil, authenticated: false)
    }

    func exchangeEntra(accessToken: String) async throws -> AccessToken {
        let access: AccessToken = try await perform(method: "POST", base: endpoints.identity, path: "/auth/entra/exchange", body: nil, authenticated: false, bearer: accessToken)
        token = access.token
        return access
    }

    func access() async throws -> UserAccessView {
        try await perform(method: "GET", base: endpoints.identity, path: "/me", body: nil, authenticated: true)
    }

    func publicExperience(frontId: String) async throws -> PublishedExperienceView {
        try await perform(method: "GET", base: endpoints.configuration, path: "/experience/\(escaped(frontId))", body: nil, authenticated: false)
    }

    func playerExperience(frontId: String) async throws -> PlayerExperienceView {
        try await perform(method: "GET", base: endpoints.playerExperience, path: "/me/experience?frontId=\(escaped(frontId))", body: nil, authenticated: true)
    }

    func playerBootstrap(frontId: String) async throws -> PlayerBootstrapView {
        try await perform(method: "GET", base: endpoints.playerExperience, path: "/me/experience/bootstrap?frontId=\(escaped(frontId))", body: nil, authenticated: true)
    }

    func completeOnboardingStep(frontId: String, stepId: UUID) async throws -> OnboardingStateView {
        try await send(method: "POST", base: endpoints.playerExperience, path: "/me/experience/onboarding/steps/\(stepId.uuidString.lowercased())/complete?frontId=\(escaped(frontId))", body: OnboardingCommandRequest(idempotencyKey: UUID().uuidString.lowercased()))
    }

    func skipOnboarding(frontId: String) async throws -> OnboardingStateView {
        try await send(method: "POST", base: endpoints.playerExperience, path: "/me/experience/onboarding/skip?frontId=\(escaped(frontId))", body: OnboardingCommandRequest(idempotencyKey: UUID().uuidString.lowercased()))
    }

    func resetOnboarding(frontId: String) async throws -> OnboardingStateView {
        try await perform(method: "POST", base: endpoints.playerExperience, path: "/me/experience/onboarding/reset?frontId=\(escaped(frontId))", body: nil, authenticated: true)
    }

    func journal(frontId: String) async throws -> JournalView {
        try await perform(method: "GET", base: endpoints.playerExperience, path: "/me/experience/journal?frontId=\(escaped(frontId))&limit=100", body: nil, authenticated: true)
    }

    func contextualHelp(frontId: String, request: ContextualHelpRequest) async throws -> ContextualHelpView {
        try await send(method: "POST", base: endpoints.playerExperience, path: "/me/experience/assistant/contextual-help?frontId=\(escaped(frontId))", body: request)
    }

    func configureFamiliar(frontId: String, request: ConfigureFamiliarRequest) async throws -> PlayerExperienceView {
        try await send(method: "PUT", base: endpoints.playerExperience, path: "/me/experience/familiar?frontId=\(escaped(frontId))", body: request)
    }

    func purchase(frontId: String, request: PurchaseRequest) async throws -> PlayerExperienceView {
        try await send(method: "POST", base: endpoints.playerExperience, path: "/me/experience/shop/purchases?frontId=\(escaped(frontId))", body: request)
    }

    func adminConfiguration(frontId: String) async throws -> ExperienceConfigurationView {
        try await perform(method: "GET", base: endpoints.configuration, path: "/admin/configuration/\(escaped(frontId))", body: nil, authenticated: true)
    }

    func updateConfiguration(frontId: String, request: UpdateConfigurationRequest) async throws -> ExperienceConfigurationView {
        try await send(method: "PUT", base: endpoints.configuration, path: "/admin/configuration/\(escaped(frontId))", body: request)
    }

    func publishConfiguration(frontId: String, request: PublishConfigurationRequest) async throws -> ExperienceConfigurationView {
        try await send(method: "POST", base: endpoints.configuration, path: "/admin/configuration/\(escaped(frontId))/publish", body: request)
    }

    func permissions() async throws -> [PermissionView] {
        try await perform(method: "GET", base: endpoints.identity, path: "/admin/access/permissions", body: nil, authenticated: true)
    }

    func roles() async throws -> [RoleView] {
        try await perform(method: "GET", base: endpoints.identity, path: "/admin/access/roles", body: nil, authenticated: true)
    }

    func createRole(request: RoleRequest) async throws -> RoleView {
        try await send(method: "POST", base: endpoints.identity, path: "/admin/access/roles", body: request)
    }

    func assignRole(userId: UUID, request: AssignRoleRequest) async throws {
        try await sendVoid(method: "POST", base: endpoints.identity, path: "/admin/access/users/\(userId.uuidString.lowercased())/roles", body: request, authenticated: true)
    }

    func users(query: String) async throws -> PagedUsersView {
        try await perform(method: "GET", base: endpoints.identity, path: "/admin/users?query=\(escaped(query))&pageSize=50", body: nil, authenticated: true)
    }

    func setUserActive(userId: UUID, isActive: Bool) async throws -> AdminUserView {
        try await send(method: "PATCH", base: endpoints.identity, path: "/admin/users/\(userId.uuidString.lowercased())/status", body: UserStatusRequest(isActive: isActive))
    }

    func deleteUser(userId: UUID) async throws {
        try await performVoid(method: "DELETE", base: endpoints.identity, path: "/admin/users/\(userId.uuidString.lowercased())")
    }

    func deleteRole(roleId: UUID) async throws {
        try await performVoid(method: "DELETE", base: endpoints.identity, path: "/admin/access/roles/\(roleId.uuidString.lowercased())")
    }

    func organizationFront(frontId: String) async throws -> OrganizationFrontView {
        try await perform(method: "GET", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))", body: nil, authenticated: true)
    }

    func organizationUnits(frontId: String) async throws -> [OrganizationUnitView] {
        try await perform(method: "GET", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/units", body: nil, authenticated: true)
    }

    func memberships(frontId: String) async throws -> PagedMembershipsView {
        try await perform(method: "GET", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/memberships?pageSize=100", body: nil, authenticated: true)
    }

    func assignments(frontId: String) async throws -> PagedAssignmentsView {
        try await perform(method: "GET", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/assignments?pageSize=100", body: nil, authenticated: true)
    }

    func upsertUnit(frontId: String, id: UUID, request: UpsertUnitRequest) async throws -> OrganizationUnitView {
        try await send(method: "PUT", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/units/\(id.uuidString.lowercased())", body: request)
    }

    func upsertMembership(frontId: String, id: UUID, request: UpsertMembershipRequest) async throws -> MembershipView {
        try await send(method: "PUT", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/memberships/\(id.uuidString.lowercased())", body: request)
    }

    func deleteMembership(frontId: String, id: UUID) async throws {
        try await performVoid(method: "DELETE", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/memberships/\(id.uuidString.lowercased())")
    }

    func upsertAssignment(frontId: String, id: UUID, request: UpsertAssignmentRequest) async throws -> ContentAssignmentView {
        try await send(method: "PUT", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/assignments/\(id.uuidString.lowercased())", body: request)
    }

    func deleteAssignment(frontId: String, id: UUID) async throws {
        try await performVoid(method: "DELETE", base: endpoints.organization, path: "/admin/organization/\(escaped(frontId))/assignments/\(id.uuidString.lowercased())")
    }

    func scenarios(query: String) async throws -> PagedScenariosView {
        try await perform(method: "GET", base: endpoints.authoring, path: "/scenarios?query=\(escaped(query))&pageSize=50", body: nil, authenticated: true)
    }

    func updateScenario(scenarioId: UUID, expectedRevision: Int, document: Data) async throws -> ScenarioView {
        guard let object = try JSONSerialization.jsonObject(with: document) as? [String: Any] else {
            throw APIError.invalidScenario("Le document narratif est invalide.")
        }
        let body = try JSONSerialization.data(withJSONObject: ["expectedRevision": expectedRevision, "document": object])
        return try await perform(method: "PUT", base: endpoints.authoring, path: scenarioPath(scenarioId), body: body, authenticated: true)
    }

    func archiveScenario(scenarioId: UUID, expectedRevision: Int) async throws {
        try await performVoid(method: "DELETE", base: endpoints.authoring, path: "\(scenarioPath(scenarioId))?expectedRevision=\(expectedRevision)")
    }

    func generateScenario(request: ScenarioGenerationRequest) async throws -> ScenarioView {
        try await send(method: "POST", base: endpoints.authoring, path: "/scenarios/generate", body: request)
    }

    func listPublishedStories() async throws -> [PublishedScenarioView] {
        try await perform(
            method: "GET",
            base: endpoints.authoring,
            path: "/catalog",
            body: nil,
            authenticated: false)
    }

    func importScenario(rawJSON: Data) async throws -> ScenarioView {
        try await perform(method: "POST", base: endpoints.authoring, path: "/scenarios/import", body: rawJSON, authenticated: true)
    }

    func validate(scenarioId: UUID) async throws -> ValidationReport {
        try await postWithoutBody(base: endpoints.authoring, path: scenarioPath(scenarioId) + "/validate")
    }

    func analyze(scenarioId: UUID) async throws -> NarrativeStructureReport {
        try await postWithoutBody(base: endpoints.authoring, path: scenarioPath(scenarioId) + "/analyze")
    }

    func preview(scenarioId: UUID, request: ScenarioPreviewRequest) async throws -> ScenarioPreview {
        try await send(method: "POST", base: endpoints.authoring, path: scenarioPath(scenarioId) + "/preview", body: request)
    }

    func publish(scenarioId: UUID, expectedRevision: Int) async throws -> ScenarioVersionView {
        try await send(method: "POST", base: endpoints.authoring, path: "/scenarios/\(scenarioId.uuidString.lowercased())/publish", body: PublishRequest(expectedRevision: expectedRevision))
    }

    func startSession(scenarioVersionId: UUID, seed: UInt64) async throws -> SessionView {
        try await send(method: "POST", base: endpoints.play, path: "/sessions", body: StartSessionRequest(scenarioVersionId: scenarioVersionId, seed: seed))
    }

    func session(sessionId: UUID) async throws -> SessionView {
        try await perform(method: "GET", base: endpoints.play, path: sessionPath(sessionId), body: nil, authenticated: true)
    }

    func currentStep(sessionId: UUID) async throws -> CurrentStep {
        try await perform(method: "GET", base: endpoints.play, path: sessionPath(sessionId) + "/current-step", body: nil, authenticated: true)
    }

    func sessionTree(sessionId: UUID) async throws -> NarrativeTree {
        try await perform(method: "GET", base: endpoints.play, path: sessionPath(sessionId) + "/tree", body: nil, authenticated: true)
    }

    func submitChoice(sessionId: UUID, commandId: UUID, expectedRevision: Int, choiceId: String) async throws -> InputResult {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/inputs", body: SubmitChoiceRequest(commandId: commandId, expectedRevision: expectedRevision, choiceId: choiceId))
    }

    func continueInteraction(sessionId: UUID, commandId: UUID, expectedRevision: Int) async throws -> InputResult {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/continue", body: ContinueInteractionRequest(commandId: commandId, expectedRevision: expectedRevision))
    }

    func submitAnswer(sessionId: UUID, commandId: UUID, expectedRevision: Int, answerId: String) async throws -> InputResult {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/answers", body: SubmitAnswerRequest(commandId: commandId, expectedRevision: expectedRevision, answerId: answerId))
    }

    func submitText(sessionId: UUID, commandId: UUID, expectedRevision: Int, text: String) async throws -> InputResult {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/text-inputs", body: SubmitTextRequest(commandId: commandId, expectedRevision: expectedRevision, text: text))
    }

    func confirmTextAnalysis(sessionId: UUID, commandId: UUID, expectedRevision: Int, confirmed: Bool) async throws -> InputResult {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/text-inputs/confirm", body: ConfirmTextAnalysisRequest(commandId: commandId, expectedRevision: expectedRevision, confirmed: confirmed))
    }

    func pause(sessionId: UUID, expectedRevision: Int) async throws -> SessionView {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/pause", body: RevisionRequest(expectedRevision: expectedRevision))
    }

    func resume(sessionId: UUID, expectedRevision: Int) async throws -> SessionView {
        try await send(method: "POST", base: endpoints.play, path: sessionPath(sessionId) + "/resume", body: RevisionRequest(expectedRevision: expectedRevision))
    }

    private func send<Body: Encodable & Sendable, Response: Decodable>(method: String, base: String, path: String, body: Body, authenticated: Bool = true) async throws -> Response {
        let data = try JSONEncoder().encode(body)
        return try await perform(method: method, base: base, path: path, body: data, authenticated: authenticated)
    }

    private func sendVoid<Body: Encodable & Sendable>(method: String, base: String, path: String, body: Body, authenticated: Bool) async throws {
        let data = try JSONEncoder().encode(body)
        _ = try await request(method: method, base: base, path: path, body: data, authenticated: authenticated)
    }

    private func postWithoutBody<Response: Decodable>(base: String, path: String) async throws -> Response {
        try await perform(method: "POST", base: base, path: path, body: nil, authenticated: true)
    }

    private func performVoid(method: String, base: String, path: String) async throws {
        _ = try await request(method: method, base: base, path: path, body: nil, authenticated: true)
    }

    private func perform<Response: Decodable>(method: String, base: String, path: String, body: Data?, authenticated: Bool, bearer: String? = nil) async throws -> Response {
        let data = try await request(method: method, base: base, path: path, body: body, authenticated: authenticated, bearer: bearer)
        do { return try makeDecoder().decode(Response.self, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    private func request(method: String, base: String, path: String, body: Data?, authenticated: Bool, bearer: String? = nil) async throws -> Data {
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        else if authenticated, let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Réponse non HTTP") }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, try? makeDecoder().decode(ProblemDetails.self, from: data))
        }
        return data
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = Self.parseDate(value) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(value)"))
            }
            return date
        }
        return decoder
    }

    private static func parseDate(_ value: String) -> Date? {
        let normalized = normalizeFraction(value)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: normalized) { return date }
        let regular = ISO8601DateFormatter()
        regular.formatOptions = [.withInternetDateTime]
        return regular.date(from: normalized)
    }

    private static func normalizeFraction(_ value: String) -> String {
        guard let dot = value.firstIndex(of: ".") else { return value }
        var cursor = value.index(after: dot)
        var count = 0
        while cursor < value.endIndex, value[cursor].isNumber { cursor = value.index(after: cursor); count += 1 }
        guard count > 3 else { return value }
        let kept = value.index(value.index(after: dot), offsetBy: 3)
        return String(value[..<kept]) + String(value[cursor...])
    }

    private func sessionPath(_ id: UUID) -> String { "/sessions/\(id.uuidString.lowercased())" }
    private func scenarioPath(_ id: UUID) -> String { "/scenarios/\(id.uuidString.lowercased())" }
    private func escaped(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value }
}
