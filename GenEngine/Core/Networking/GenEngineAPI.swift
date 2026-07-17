import Foundation

protocol GenEngineAPI: Sendable {
    func update(endpoints: ServiceEndpoints) async
    func setToken(_ token: String?) async
    func register(userName: String, password: String) async throws -> AccessToken
    func login(userName: String, password: String) async throws -> AccessToken
    func listPublishedStories() async throws -> [PublishedScenarioView]
    func importScenario(rawJSON: Data) async throws -> ScenarioView
    func publish(scenarioId: UUID, expectedRevision: Int) async throws -> ScenarioVersionView
    func startSession(scenarioVersionId: UUID, seed: UInt64) async throws -> SessionView
    func currentStep(sessionId: UUID) async throws -> CurrentStep
    func submitChoice(sessionId: UUID, commandId: UUID, expectedRevision: Int, choiceId: String) async throws -> InputResult
    func pause(sessionId: UUID, expectedRevision: Int) async throws -> SessionView
    func resume(sessionId: UUID, expectedRevision: Int) async throws -> SessionView
}

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, ProblemDetails?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "L’adresse du service est invalide."
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

    func publish(scenarioId: UUID, expectedRevision: Int) async throws -> ScenarioVersionView {
        try await send(method: "POST", base: endpoints.authoring, path: "/scenarios/\(scenarioId.uuidString.lowercased())/publish", body: PublishRequest(expectedRevision: expectedRevision))
    }

    func startSession(scenarioVersionId: UUID, seed: UInt64) async throws -> SessionView {
        try await send(method: "POST", base: endpoints.play, path: "/sessions", body: StartSessionRequest(scenarioVersionId: scenarioVersionId, seed: seed))
    }

    func currentStep(sessionId: UUID) async throws -> CurrentStep {
        try await perform(method: "GET", base: endpoints.play, path: "/sessions/\(sessionId.uuidString.lowercased())/current-step", body: nil, authenticated: true)
    }

    func submitChoice(sessionId: UUID, commandId: UUID, expectedRevision: Int, choiceId: String) async throws -> InputResult {
        try await send(method: "POST", base: endpoints.play, path: "/sessions/\(sessionId.uuidString.lowercased())/inputs", body: SubmitChoiceRequest(commandId: commandId, expectedRevision: expectedRevision, choiceId: choiceId))
    }

    func pause(sessionId: UUID, expectedRevision: Int) async throws -> SessionView {
        try await send(method: "POST", base: endpoints.play, path: "/sessions/\(sessionId.uuidString.lowercased())/pause", body: RevisionRequest(expectedRevision: expectedRevision))
    }

    func resume(sessionId: UUID, expectedRevision: Int) async throws -> SessionView {
        try await send(method: "POST", base: endpoints.play, path: "/sessions/\(sessionId.uuidString.lowercased())/resume", body: RevisionRequest(expectedRevision: expectedRevision))
    }

    private func send<Body: Encodable & Sendable, Response: Decodable>(method: String, base: String, path: String, body: Body, authenticated: Bool = true) async throws -> Response {
        let data = try JSONEncoder().encode(body)
        return try await perform(method: method, base: base, path: path, body: data, authenticated: authenticated)
    }

    private func sendVoid<Body: Encodable & Sendable>(method: String, base: String, path: String, body: Body, authenticated: Bool) async throws {
        let data = try JSONEncoder().encode(body)
        _ = try await request(method: method, base: base, path: path, body: data, authenticated: authenticated)
    }

    private func perform<Response: Decodable>(method: String, base: String, path: String, body: Data?, authenticated: Bool) async throws -> Response {
        let data = try await request(method: method, base: base, path: path, body: body, authenticated: authenticated)
        do { return try makeDecoder().decode(Response.self, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    private func request(method: String, base: String, path: String, body: Data?, authenticated: Bool) async throws -> Data {
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated, let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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
}
