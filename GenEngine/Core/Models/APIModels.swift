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

// MARK: - Configurable platform

struct RoleView: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String
    let isSystem: Bool
    var permissions: [String]
}
struct UserAccessView: Decodable, Sendable {
    let id: UUID
    let userName: String
    let roles: [RoleView]
    let permissions: [String]
}
struct AuthenticationProvidersView: Decodable, Sendable {
    let mode: String
    let localEnabled: Bool
    let entraEnabled: Bool
    let authority: String?
    let clientId: String?
}
struct PermissionView: Codable, Identifiable, Sendable {
    var id: String { code }
    let code: String
    let description: String
}
struct RoleRequest: Encodable, Sendable { let name: String; let description: String; let permissions: [String] }
struct AssignRoleRequest: Encodable, Sendable { let roleId: UUID; let scope: String?; let expiresAt: Date? }

struct GameDefinition: Codable, Sendable {
    var name: String
    var description: String
    var globalStory: String
    var locale: String
    var timeZone: String
}
struct GameLanguageDefinition: Codable, Sendable {
    var labels: [String: String]
}
struct OrganizationUnitDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var parentId: UUID?
    var type: String
    var name: String
    var code: String
    var description: String
    var order: Int
    var enabled: Bool
}
struct OrganizationDefinition: Codable, Sendable {
    var name: String
    var description: String
    var units: [OrganizationUnitDefinition]
}
struct AuthenticationDefinition: Codable, Sendable {
    var mode: String
    var localEnabled: Bool
    var entraEnabled: Bool
    var entraTenantId: String?
    var entraClientId: String?
}
struct AIProviderDefinition: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var type: String
    var enabled: Bool
    var endpoint: String
    var deployment: String
    var authentication: String
    var secretReference: String?
    var capabilities: [String]
}
struct CategoryDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var accent: String
    var order: Int
    var isVisible: Bool
}
struct FamiliarDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var form: String
    var writingStyle: String
    var tone: String
    var accent: String
    var helpLevel: Int
    var capabilities: [String]
    var availableForms: [String]
    var availableTones: [String]
}
struct RewardRuleDefinition: Codable, Identifiable, Sendable {
    var id: String { "\(trigger)-\(referenceId)" }
    var trigger: String
    var referenceId: String
    var amount: Int
    var description: String
}
struct OfferDefinition: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var price: Int
    var rewardType: String
    var rewardReference: String
    var enabled: Bool
}
struct EconomyDefinition: Codable, Sendable {
    var currencyCode: String
    var currencyName: String
    var currencyIcon: String
    var initialBalance: Int
    var rewardRules: [RewardRuleDefinition]
    var offers: [OfferDefinition]
}
struct ModuleDefinition: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var description: String
    var enabled: Bool
    var requiredPermissions: [String]
}
struct ExperienceDocument: Codable, Sendable {
    var frontId: String
    var organizationType: String
    var organization: OrganizationDefinition
    var game: GameDefinition
    var language: GameLanguageDefinition
    var authentication: AuthenticationDefinition
    var aiProviders: [AIProviderDefinition]
    var categories: [CategoryDefinition]
    var familiars: [FamiliarDefinition]
    var economy: EconomyDefinition
    var modules: [ModuleDefinition]
}
struct PublishedExperienceView: Decodable, Sendable {
    let version: Int
    let publishedAt: Date
    let document: ExperienceDocument
}
struct ExperienceConfigurationView: Codable, Sendable {
    let id: UUID
    var revision: Int
    var publishedVersion: Int
    let updatedAt: Date
    let publishedAt: Date?
    var document: ExperienceDocument
}
struct UpdateConfigurationRequest: Encodable, Sendable { let expectedRevision: Int?; let document: ExperienceDocument }
struct PublishConfigurationRequest: Encodable, Sendable { let expectedRevision: Int }

struct FamiliarSelection: Codable, Sendable {
    let familiarId: UUID
    let form: String
    let tone: String
    let writingStyle: String
    let accent: String
    let helpLevel: Int
}
struct WalletEntryView: Decodable, Identifiable, Sendable {
    let id: UUID
    let amount: Int
    let reason: String
    let balanceAfter: Int
    let createdAt: Date
}
struct PlayerExperienceView: Decodable, Sendable {
    let id: UUID
    let frontId: String
    let revision: Int
    let balance: Int
    let currencyCode: String
    let currencyName: String
    let currencyIcon: String
    let familiar: FamiliarSelection?
    let ownedOfferIds: [UUID]
    let recentEntries: [WalletEntryView]
}
struct ConfigureFamiliarRequest: Encodable, Sendable { let expectedRevision: Int; let selection: FamiliarSelection }
struct PurchaseRequest: Encodable, Sendable { let offerId: UUID; let idempotencyKey: String }
struct ScenarioGenerationRequest: Encodable, Sendable {
    let frontId: String
    let categoryId: UUID
    let prompt: String
    let provider: String
    let targetMinutes: Int
    let tone: String
}
