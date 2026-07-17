import Foundation

struct CredentialsRequest: Encodable, Sendable { let userName: String; let password: String }
struct AccessToken: Decodable, Sendable { let token: String; let expiresAt: Date; let tokenType: String? }
struct ScenarioView: Decodable, Sendable { let id: UUID; let title: String; let revision: Int; let draftJson: String }
struct PublishRequest: Encodable, Sendable { let expectedRevision: Int }
struct ScenarioVersionView: Decodable, Sendable { let id: UUID; let scenarioId: UUID; let number: Int; let snapshotHash: String; let publishedAt: Date }
struct ValidationIssue: Decodable, Sendable { let code: String; let path: String; let message: String; let isError: Bool }
struct ValidationReport: Decodable, Sendable { let issues: [ValidationIssue]; let isValid: Bool }
struct NarrativeLoop: Decodable, Sendable { let nodeIds: [String]; let hasExit: Bool; let hasGuaranteedExit: Bool }
struct ConditionalDeadEndRisk: Decodable, Sendable { let nodeId: String; let conditionalInputIds: [String]; let explanation: String }
struct NarrativeStructureReport: Decodable, Sendable {
    let loops: [NarrativeLoop]
    let conditionalDeadEnds: [ConditionalDeadEndRisk]
    let unreachableEndingNodeIds: [String]
    let nodesWithoutEndingPath: [String]
}
struct ScenarioPreviewRequest: Encodable, Sendable {
    let nodeId: String
    let turn: Int
    let variables: [String: Int]
    let characteristics: [String: Int]
    let inventory: [String]
    let evidence: [String]
    let relations: [String: Int]
    let rewards: [String]
    let visitedNodes: [String]
}
struct ScenarioPreview: Decodable, Sendable { let currentStep: CurrentStep }
struct PublishedScenarioView: Decodable, Sendable {
    let scenarioId: UUID
    let versionId: UUID
    let versionNumber: Int
    let title: String
    let description: String
    let estimatedMinutes: Int
    let publishedAt: Date
    let snapshotHash: String
}

enum SessionStatus: Equatable, Sendable {
    case awaitingInput, paused, completed, abandoned, awaitingExternalInput, awaitingValidation
    var label: String {
        switch self {
        case .awaitingInput: "En cours"
        case .paused: "En pause"
        case .completed: "Terminé"
        case .abandoned: "Abandonné"
        case .awaitingExternalInput: "Saisie attendue"
        case .awaitingValidation: "Validation attendue"
        }
    }
}

enum InteractionKind: Equatable, Sendable {
    case legacyChoice, narration, choiceSet, quiz, characteristicGate, freeText, completed
}

extension InteractionKind: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            switch raw.lowercased() {
            case "legacychoice": self = .legacyChoice
            case "narration": self = .narration
            case "choiceset": self = .choiceSet
            case "quiz": self = .quiz
            case "characteristicgate": self = .characteristicGate
            case "freetext": self = .freeText
            case "completed": self = .completed
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown interaction kind: \(raw)")
            }
            return
        }
        switch try container.decode(Int.self) {
        case 0: self = .legacyChoice
        case 1: self = .narration
        case 2: self = .choiceSet
        case 3: self = .quiz
        case 4: self = .characteristicGate
        case 5: self = .freeText
        case 6: self = .completed
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown numeric interaction kind")
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
            case "awaitingexternalinput": self = .awaitingExternalInput
            case "awaitingvalidation": self = .awaitingValidation
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown session status: \(raw)")
            }
            return
        }
        switch try container.decode(Int.self) {
        case 0: self = .awaitingInput
        case 1: self = .paused
        case 2: self = .completed
        case 3: self = .abandoned
        case 4: self = .awaitingExternalInput
        case 5: self = .awaitingValidation
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown numeric session status")
        }
    }
}

struct StartSessionRequest: Encodable, Sendable { let scenarioVersionId: UUID; let seed: UInt64 }
struct SessionView: Decodable, Sendable { let id: UUID; let scenarioVersionId: UUID; let snapshotHash: String; let status: SessionStatus; let revision: Int; let turn: Int }
struct VisibleChoice: Decodable, Identifiable, Equatable, Sendable { let id: String; let text: String }
struct TextAnalysisResult: Decodable, Equatable, Sendable {
    let interactionId: String
    let isAccepted: Bool
    let matchedTerms: [String]
    let minimumMatches: Int
    let explanation: String
}
struct CurrentStep: Decodable, Equatable, Sendable {
    let nodeId: String
    let text: String
    let status: SessionStatus
    let choices: [VisibleChoice]
    let turn: Int
    let interactionId: String?
    let kind: InteractionKind
    let pendingTextAnalysis: TextAnalysisResult?

    init(nodeId: String, text: String, status: SessionStatus, choices: [VisibleChoice], turn: Int, interactionId: String? = nil, kind: InteractionKind = .legacyChoice, pendingTextAnalysis: TextAnalysisResult? = nil) {
        self.nodeId = nodeId
        self.text = text
        self.status = status
        self.choices = choices
        self.turn = turn
        self.interactionId = interactionId
        self.kind = kind
        self.pendingTextAnalysis = pendingTextAnalysis
    }
}
struct SubmitChoiceRequest: Encodable, Sendable { let commandId: UUID; let expectedRevision: Int; let choiceId: String }
struct ContinueInteractionRequest: Encodable, Sendable { let commandId: UUID; let expectedRevision: Int }
struct SubmitAnswerRequest: Encodable, Sendable { let commandId: UUID; let expectedRevision: Int; let answerId: String }
struct SubmitTextRequest: Encodable, Sendable { let commandId: UUID; let expectedRevision: Int; let text: String }
struct ConfirmTextAnalysisRequest: Encodable, Sendable { let commandId: UUID; let expectedRevision: Int; let confirmed: Bool }
struct RevisionRequest: Encodable, Sendable { let expectedRevision: Int }
struct InputResult: Decodable, Sendable { let session: SessionView; let currentStep: CurrentStep; let replayed: Bool }

struct ConditionEvaluation: Decodable, Equatable, Sendable {
    let `operator`: String
    let result: Bool
    let explanation: String
    let children: [ConditionEvaluation]
}
struct NarrativeTreeNode: Decodable, Identifiable, Equatable, Sendable { let id: String; let text: String; let isEnding: Bool; let state: String }
struct NarrativeTreeEdge: Decodable, Equatable, Sendable {
    let sourceNodeId: String
    let targetNodeId: String
    let inputId: String
    let text: String
    let isAvailable: Bool
    let evaluation: ConditionEvaluation
}
struct NarrativeTree: Decodable, Equatable, Sendable {
    let initialNodeId: String
    let currentNodeId: String
    let nodes: [NarrativeTreeNode]
    let edges: [NarrativeTreeEdge]
}

struct SavedSession: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let scenarioVersionId: UUID
    let title: String
    var status: String
    var revision: Int
    var turn: Int
    var updatedAt: Date
}
struct ProblemDetails: Decodable, Error, Sendable { let title: String?; let detail: String?; let status: Int? }
