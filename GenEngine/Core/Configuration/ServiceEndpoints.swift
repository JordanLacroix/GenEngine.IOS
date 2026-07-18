import Foundation

struct ServiceEndpoints: Codable, Equatable, Sendable {
    var identity: String
    var authoring: String
    var play: String
    var configuration: String
    var playerExperience: String
    var organization: String

    init(identity: String, authoring: String, play: String, configuration: String, playerExperience: String, organization: String) {
        self.identity = identity
        self.authoring = authoring
        self.play = play
        self.configuration = configuration
        self.playerExperience = playerExperience
        self.organization = organization
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identity = try values.decode(String.self, forKey: .identity)
        authoring = try values.decode(String.self, forKey: .authoring)
        play = try values.decode(String.self, forKey: .play)
        configuration = try values.decode(String.self, forKey: .configuration)
        playerExperience = try values.decode(String.self, forKey: .playerExperience)
        organization = try values.decodeIfPresent(String.self, forKey: .organization)
            ?? inferredOrganizationURL(from: configuration)
    }

    static let local = ServiceEndpoints(
        identity: "http://localhost:5203",
        authoring: "http://localhost:5201",
        play: "http://localhost:5202",
        configuration: "http://localhost:5204",
        playerExperience: "http://localhost:5205",
        organization: "http://localhost:5206"
    )
}

private func inferredOrganizationURL(from configurationURL: String) -> String {
    guard var components = URLComponents(string: configurationURL) else { return "http://localhost:5206" }
    if components.port == 5204 { components.port = 5206 }
    return components.string ?? "http://localhost:5206"
}

enum EndpointStore {
    private static let key = "genengine.service-endpoints"

    static func load() -> ServiceEndpoints {
        guard let data = UserDefaults.standard.data(forKey: key),
              let endpoints = try? JSONDecoder().decode(ServiceEndpoints.self, from: data)
        else { return .local }
        return endpoints
    }

    static func save(_ endpoints: ServiceEndpoints) {
        guard let data = try? JSONEncoder().encode(endpoints) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
