import Foundation

struct CredentialsRequest: Encodable, Sendable { let userName: String; let password: String }
struct AccessToken: Decodable, Sendable { let token: String; let expiresAt: Date; let tokenType: String? }
struct ScenarioView: Decodable, Sendable { let id: UUID; let title: String; let revision: Int; let draftJson: String }
struct PublishRequest: Encodable, Sendable { let expectedRevision: Int }
struct ScenarioVersionView: Decodable, Sendable { let id: UUID; let scenarioId: UUID; let number: Int; let snapshotHash: String; let publishedAt: Date }

enum SessionStatus: Equatable, Sendable {
    case awaitingInput, paused, completed, abandoned
    var label: String {
        switch self {
        case .awaitingInput: "En cours"
        case .paused: "En pause"
        case .completed: "Terminé"
        case .abandoned: "Abandonné"
        }
    }
}

extension SessionStatus: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            switch raw.lowercased() {
            case "awaitinginput": self = .awaitingInput
            case "paused": self = .paused
            case "completed": self = .completed
            case "abandoned": self = .abandoned
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown session status: \(raw)")
            }
            return
        }
        switch try container.decode(Int.self) {
        case 0: self = .awaitingInput
        case 1: self = .paused
        case 2: self = .completed
        case 3: self = .abandoned
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown numeric session status")
        }
    }
}

struct StartSessionRequest: Encodable, Sendable { let scenarioVersionId: UUID; let seed: UInt64 }
struct SessionView: Decodable, Sendable { let id: UUID; let scenarioVersionId: UUID; let snapshotHash: String; let status: SessionStatus; let revision: Int; let turn: Int }
struct VisibleChoice: Decodable, Identifiable, Equatable, Sendable { let id: String; let text: String }
struct CurrentStep: Decodable, Equatable, Sendable { let nodeId: String; let text: String; let status: SessionStatus; let choices: [VisibleChoice]; let turn: Int }
struct SubmitChoiceRequest: Encodable, Sendable { let commandId: UUID; let expectedRevision: Int; let choiceId: String }
struct RevisionRequest: Encodable, Sendable { let expectedRevision: Int }
struct InputResult: Decodable, Sendable { let session: SessionView; let currentStep: CurrentStep; let replayed: Bool }
struct ProblemDetails: Decodable, Error, Sendable { let title: String?; let detail: String?; let status: Int? }
