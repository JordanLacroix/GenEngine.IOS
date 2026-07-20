import Foundation
import Testing
@testable import GenEngine

/// Tests de la couche réseau : **chemins réellement construits** et **parcours des pages**.
///
/// Ils interceptent les requêtes avec un `URLProtocol` plutôt que de doubler `GenEngineAPI` :
/// un faux client n'aurait rien dit des deux défauts visés ici, qui vivent tous les deux dans
/// `LiveGenEngineAPI` — une route inexistante et un plafond de pagination silencieux.
@Suite(.serialized)
struct AuthoringRouteTests {
    // MARK: - Bug 1 — la sauvegarde de brouillon vise `/draft`

    /// Le moteur n'expose pas `PUT /scenarios/{id}` : la ressource modifiable est le brouillon.
    /// Ce test échoue si l'on revient au chemin nu.
    @Test func savingADraftTargetsTheDraftResource() async throws {
        let recorder = RequestRecorder()
        RouteStub.install { request in
            recorder.record(request)
            return (200, Fixtures.scenario)
        }
        defer { RouteStub.reset() }

        let api = makeAPI()
        _ = try await api.updateScenario(
            scenarioId: Self.scenarioId,
            expectedRevision: 3,
            document: Data(#"{"schemaVersion":6}"#.utf8))

        let calls = recorder.calls
        #expect(calls.count == 1)
        #expect(calls[0].method == "PUT")
        #expect(calls[0].path == "/scenarios/\(Self.scenarioId.uuidString.lowercased())/draft")
        // Le chemin nu est celui du défaut : il ne doit plus jamais être émis.
        #expect(calls[0].path.hasSuffix("/draft"))
        #expect(calls[0].path != "/scenarios/\(Self.scenarioId.uuidString.lowercased())")
    }

    /// Le corps attendu par `UpdateDraftRequest` est `{ expectedRevision, document }`, le
    /// document étant un objet JSON et non une chaîne.
    @Test func draftBodyCarriesRevisionAndDocumentObject() async throws {
        let recorder = RequestRecorder()
        RouteStub.install { request in
            recorder.record(request)
            return (200, Fixtures.scenario)
        }
        defer { RouteStub.reset() }

        _ = try await makeAPI().updateScenario(
            scenarioId: Self.scenarioId,
            expectedRevision: 7,
            document: Data(#"{"schemaVersion":6,"title":"Le Diapason"}"#.utf8))

        let body = try #require(recorder.calls.first?.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["expectedRevision"] as? Int == 7)
        let document = try #require(object["document"] as? [String: Any])
        #expect(document["title"] as? String == "Le Diapason")
    }

    /// L'archivage, lui, vise bien la ressource nue : le correctif ne doit pas déborder.
    @Test func archivingStillTargetsThePlainResource() async throws {
        let recorder = RequestRecorder()
        RouteStub.install { request in
            recorder.record(request)
            return (204, Data())
        }
        defer { RouteStub.reset() }

        try await makeAPI().archiveScenario(scenarioId: Self.scenarioId, expectedRevision: 2)

        let path = try #require(recorder.calls.first?.path)
        #expect(path == "/scenarios/\(Self.scenarioId.uuidString.lowercased())?expectedRevision=2")
    }

    // MARK: - Bug 2 — plus aucune liste plafonnée en silence

    /// 213 scénarios répartis en pages de 100 : les trois pages sont demandées et le total
    /// annoncé est l'effectif réel, pas la taille d'une page.


    /// La recherche reste appliquée par le serveur, sur chaque page demandée.




    /// Une liste tenant sur une seule page ne déclenche pas d'appel supplémentaire.

    // MARK: - Le plafond restant est annoncé, jamais silencieux

    /// Au-delà du plafond de 100 pages, le client refuse de rendre une collection tronquée.
    /// C'est tout l'objet du correctif : une liste incomplète ne doit pas se lire comme
    /// complète.

    /// Et le message dit ce qui manque, plutôt que d'être un échec opaque.

    // MARK: - Tolérance de décodage héritée de `PagedList`

    /// Un serveur antérieur à l'enveloppe paginée répond par un tableau nu. Le parcours doit
    /// le lire comme une page unique complète, et non échouer.

    // MARK: - Outillage

    private static let scenarioId = UUID(uuidString: "1D9E4C2A-6B7F-4E1A-9C3D-8F2A5B6C7D8E")!

    private func makeAPI() -> LiveGenEngineAPI {
        LiveGenEngineAPI(
            endpoints: ServiceEndpoints(
                identity: "https://stub.invalid",
                authoring: "https://stub.invalid",
                play: "https://stub.invalid",
                configuration: "https://stub.invalid",
                playerExperience: "https://stub.invalid",
                organization: "https://stub.invalid"),
            token: "jeton",
            protocolClasses: [RouteStub.self])
    }

    private struct Call: Sendable {
        let method: String
        let path: String
        let url: URL
        let body: Data?

        func queryValue(_ name: String) -> String? {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == name }?.value
        }
    }

    /// Enregistreur synchrone : le `URLProtocol` note la requête sur le fil de la session,
    /// sans saut de contexte.
    private final class RequestRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [Call] = []

        var calls: [Call] {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }

        func record(_ request: URLRequest) {
            guard let url = request.url else { return }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let path = (components?.path ?? "") + (components?.query.map { "?\($0)" } ?? "")
            let call = Call(
                method: request.httpMethod ?? "",
                path: path,
                url: url,
                body: request.httpBody ?? request.bodyStreamData())
            lock.lock()
            defer { lock.unlock() }
            stored.append(call)
        }
    }
}

// MARK: - Interception réseau

/// `URLProtocol` d'interception, injecté dans la configuration de session par
/// `LiveGenEngineAPI(protocolClasses:)`.
final class RouteStub: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    private static let lock = NSLock()

    /// Synchrone à dessein : `NSLock` est indisponible depuis un contexte asynchrone.
    /// La suite est sérialisée, donc un seul gestionnaire est posé à la fois.
    static func install(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// Les rappels sont délivrés **de façon synchrone**, sur le fil que `URLSession` utilise
    /// déjà pour `startLoading()`. Les poster depuis une `Task` détachée faisait courir le
    /// chargement et la session en parallèle et faisait tomber le processus de test.
    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    /// `URLSession` déplace le corps dans `httpBodyStream` : sans cela les tests de corps
    /// liraient systématiquement `nil`.
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Réponses de service simulées

private enum Fixtures {
    static let scenario = Data(#"""
    {"id":"1d9e4c2a-6b7f-4e1a-9c3d-8f2a5b6c7d8e","title":"Le Diapason","revision":4,"draftJson":"{}"}
    """#.utf8)

    static func bareScenarioArray(count: Int) -> Data {
        let items = (0..<count).map { scenarioItem(index: $0) }.joined(separator: ",")
        return Data("[\(items)]".utf8)
    }

    /// Sert la tranche demandée d'un ensemble de `total` éléments, en respectant le contrat
    /// paginé du moteur : `page` en base 1, enveloppe `{ items, page, pageSize, total }`.
    static func page(of total: Int, at url: URL?, key: String) -> Data {
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let page = Int(components?.queryItems?.first { $0.name == "page" }?.value ?? "1") ?? 1
        let pageSize = Int(components?.queryItems?.first { $0.name == "pageSize" }?.value ?? "100") ?? 100
        let start = min((page - 1) * pageSize, total)
        let end = min(start + pageSize, total)
        let items = (start..<end).map { item(key: key, index: $0) }.joined(separator: ",")
        let totals = key == "journal" ? #","totalsByType":{"ScenarioCompleted":\#(total)}"# : ""
        return Data(#"{"items":[\#(items)],"page":\#(page),"pageSize":\#(pageSize),"total":\#(total)\#(totals)}"#.utf8)
    }

    private static func item(key: String, index: Int) -> String {
        switch key {
        case "scenario": scenarioItem(index: index)
        case "user": userItem(index: index)
        case "membership": membershipItem(index: index)
        case "assignment": assignmentItem(index: index)
        default: journalItem(index: index)
        }
    }

    private static func uuid(_ index: Int) -> String {
        String(format: "00000000-0000-4000-8000-%012d", index)
    }

    private static let date = "2026-07-20T10:00:00Z"

    private static func scenarioItem(index: Int) -> String {
        #"{"id":"\#(uuid(index))","title":"Récit \#(index)","revision":1,"draftJson":"{}"}"#
    }

    private static func userItem(index: Int) -> String {
        #"{"id":"\#(uuid(index))","userName":"joueur\#(index)","createdAt":"\#(date)","isActive":true,"deletedAt":null,"externalProvider":null,"roleAssignments":[]}"#
    }

    private static func membershipItem(index: Int) -> String {
        #"""
        {"id":"\#(uuid(index))","frontId":"default","unitId":"\#(uuid(0))","userId":"\#(uuid(index))","periodId":null,"kind":"Participant","startsAt":"\#(date)","endsAt":null,"isActive":true,"revision":1,"updatedAt":"\#(date)"}
        """#
    }

    private static func assignmentItem(index: Int) -> String {
        #"""
        {"id":"\#(uuid(index))","frontId":"default","unitId":"\#(uuid(0))","contentType":"Scenario","contentId":"\#(uuid(index))","name":"Contenu \#(index)","required":true,"availableFrom":null,"dueAt":null,"isActive":true,"revision":1,"updatedAt":"\#(date)"}
        """#
    }

    private static func journalItem(index: Int) -> String {
        #"""
        {"id":"\#(uuid(index))","type":"ScenarioCompleted","title":"Entrée \#(index)","summary":"Résumé","journeyId":null,"categoryId":null,"scenarioId":null,"scenarioVersionId":null,"sessionId":null,"referenceId":null,"occurredAt":"\#(date)"}
        """#
    }
}
