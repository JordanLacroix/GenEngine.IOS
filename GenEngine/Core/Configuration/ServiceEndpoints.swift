import Foundation

struct ServiceEndpoints: Codable, Equatable, Sendable {
    var identity: String
    var authoring: String
    var play: String
    var configuration: String
    var playerExperience: String

    static let local = ServiceEndpoints(
        identity: "http://localhost:5203",
        authoring: "http://localhost:5201",
        play: "http://localhost:5202",
        configuration: "http://localhost:5204",
        playerExperience: "http://localhost:5205"
    )
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
