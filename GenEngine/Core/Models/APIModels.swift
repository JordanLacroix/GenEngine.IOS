import Foundation

enum MembershipKind: String, Codable, CaseIterable, Sendable { case participant = "Participant", supervisor = "Supervisor" }
enum AssignedContentType: String, Codable, CaseIterable, Sendable { case journey = "Journey", category = "Category", scenario = "Scenario" }
struct OrganizationFrontView: Codable, Sendable { let id: UUID; let frontId: String; let name: String; let type: String; let isActive: Bool; let revision: Int; let updatedAt: Date }
struct OrganizationUnitView: Codable, Identifiable, Sendable { let id: UUID; let frontId: String; let parentId: UUID?; let name: String; let type: String; let code: String; let isActive: Bool; let revision: Int; let updatedAt: Date }
struct OperatingPeriodView: Codable, Identifiable, Sendable { let id: UUID; let frontId: String; let name: String; let code: String; let startsAt: Date; let endsAt: Date; let isActive: Bool; let revision: Int; let updatedAt: Date }
struct MembershipView: Codable, Identifiable, Sendable { let id: UUID; let frontId: String; let unitId: UUID; let userId: UUID; let periodId: UUID?; let kind: MembershipKind; let startsAt: Date; let endsAt: Date?; let isActive: Bool; let revision: Int; let updatedAt: Date }
struct ContentAssignmentView: Codable, Identifiable, Sendable { let id: UUID; let frontId: String; let unitId: UUID; let contentType: AssignedContentType; let contentId: UUID; let name: String; let required: Bool; let availableFrom: Date?; let dueAt: Date?; let isActive: Bool; let revision: Int; let updatedAt: Date }
struct PagedMembershipsView: Codable, Sendable { let items: [MembershipView]; let page: Int; let pageSize: Int; let total: Int }
struct PagedAssignmentsView: Codable, Sendable { let items: [ContentAssignmentView]; let page: Int; let pageSize: Int; let total: Int }
struct PlayerOrganizationContextView: Codable, Sendable { let frontId: String; let isMember: Bool; let unitIds: [UUID]; let supervisedUnitIds: [UUID]; let assignments: [ContentAssignmentView]; let hasGlobalScope: Bool }
struct UpsertUnitRequest: Codable, Sendable { let parentId: UUID?; let name: String; let type: String; let code: String; let isActive: Bool; let expectedRevision: Int? }
struct UpsertPeriodRequest: Codable, Sendable { let name: String; let code: String; let startsAt: Date; let endsAt: Date; let isActive: Bool; let expectedRevision: Int? }
struct UpsertMembershipRequest: Codable, Sendable { let unitId: UUID; let userId: UUID; let periodId: UUID?; let kind: MembershipKind; let startsAt: Date; let endsAt: Date?; let isActive: Bool; let expectedRevision: Int? }
struct MembershipImportRow: Codable, Identifiable, Sendable { let id: UUID; let unitId: UUID; let userId: UUID; let periodId: UUID?; let kind: MembershipKind; let startsAt: Date; let endsAt: Date? }
struct MembershipImportError: Codable, Sendable { let row: Int; let code: String; let message: String }
struct MembershipImportView: Codable, Sendable { let dryRun: Bool; let received: Int; let created: Int; let unchanged: Int; let errors: [MembershipImportError] }
struct ImportMembershipsRequest: Codable, Sendable { let dryRun: Bool; let rows: [MembershipImportRow] }
struct UpsertAssignmentRequest: Codable, Sendable { let unitId: UUID; let contentType: AssignedContentType; let contentId: UUID; let name: String; let required: Bool; let availableFrom: Date?; let dueAt: Date?; let isActive: Bool; let expectedRevision: Int? }

struct CredentialsRequest: Encodable, Sendable { let userName: String; let password: String }
struct AccessToken: Decodable, Sendable { let token: String; let expiresAt: Date; let tokenType: String? }
struct ScenarioView: Decodable, Sendable { let id: UUID; let title: String; let revision: Int; let draftJson: String; let frontId: String?; let categoryId: UUID?; let creationBrief: String?; let isArchived: Bool?; let updatedAt: Date? }
struct PagedScenariosView: Decodable, Sendable { let items: [ScenarioView]; let total: Int; let page: Int; let pageSize: Int }
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
    let categoryId: UUID?
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
struct SessionView: Decodable, Sendable { let id: UUID; let scenarioId: UUID; let scenarioVersionId: UUID; var frontId: String? = nil; let snapshotHash: String; let status: SessionStatus; let revision: Int; let turn: Int }
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

// MARK: - Structure d'une version publiée, hors session

/// Topologie d'une version publiée (`GET /scenario-versions/{id}/tree`).
/// Ce contrat ne porte volontairement ni état de scène ni évaluation de condition :
/// les deux dépendent d'un état de monde qui n'existe pas en dehors d'une session.
/// Ce type reste donc distinct de `NarrativeTree` et ne prétend porter aucun état.
struct ScenarioStructureNode: Decodable, Identifiable, Equatable, Sendable { let id: String; let text: String; let isEnding: Bool }
struct ScenarioStructureEdge: Decodable, Equatable, Sendable {
    let sourceNodeId: String
    let targetNodeId: String
    let inputId: String
    let text: String
}
struct ScenarioStructure: Decodable, Equatable, Sendable {
    let initialNodeId: String
    let nodes: [ScenarioStructureNode]
    let edges: [ScenarioStructureEdge]
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
struct RoleAssignmentView: Decodable, Identifiable, Sendable { var id: String { "\(roleId)-\(scope)" }; let roleId: UUID; let roleName: String; let scope: String; let expiresAt: Date?; let assignedAt: Date }
struct AdminUserView: Decodable, Identifiable, Sendable { let id: UUID; let userName: String; let createdAt: Date; let isActive: Bool; let deletedAt: Date?; let externalProvider: String?; let roleAssignments: [RoleAssignmentView] }
struct PagedUsersView: Decodable, Sendable { let items: [AdminUserView]; let page: Int; let pageSize: Int; let total: Int }
struct UserStatusRequest: Encodable, Sendable { let isActive: Bool }

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
    var imageUrl: String? = nil
    var tags: [String]? = nil
    var scenarioIds: [UUID]? = nil
}
struct JourneyDefinition: Codable, Identifiable, Hashable, Sendable { let id: UUID; var name: String; var description: String; var accent: String; var imageUrl: String?; var order: Int; var isVisible: Bool; var categoryIds: [UUID]; var prerequisiteJourneyIds: [UUID]; var tags: [String] }
struct CatalogAssignmentDefinition: Codable, Identifiable, Hashable, Sendable { let id: UUID; var organizationUnitId: UUID; var contentType: String; var contentId: UUID; var name: String; var required: Bool; var availableFrom: Date?; var dueAt: Date? }
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
    var portraitUrl: String? = nil
    var avatarUrl: String? = nil
    var backgroundUrl: String? = nil
    var license: String? = nil
    var attribution: String? = nil
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
struct IntroSceneDefinition: Codable, Identifiable, Sendable { let id: UUID; var eyebrow: String; var title: String; var body: String; var imageUrl: String?; var order: Int }
struct IntroDefinition: Codable, Sendable { var enabled: Bool; var displayPolicy: String; var allowSkip: Bool; var minimumDisplaySeconds: Int; var scenes: [IntroSceneDefinition] }
struct NavigationItemDefinition: Codable, Identifiable, Sendable { var id: String { destination }; var destination: String; var labelKey: String; var icon: String; var order: Int; var enabled: Bool; var requiredModule: String? }
struct PlayerShellDefinition: Codable, Sendable { var navigation: [NavigationItemDefinition] }
struct DemoExperienceDefinition: Codable, Sendable { var enabled: Bool; var scenarioSlug: String; var targetMinutes: Int; var familiarId: UUID?; var callToActionLabelKey: String }
struct HelpArticleDefinition: Codable, Identifiable, Sendable { let id: UUID; var slug: String; var title: String; var summary: String; var body: String; var contexts: [String]; var tags: [String]; var order: Int; var published: Bool }
struct GlossaryEntryDefinition: Codable, Identifiable, Sendable { var id: String { term }; var term: String; var definition: String }
struct HelpCenterDefinition: Codable, Sendable { var enabled: Bool; var articles: [HelpArticleDefinition]; var glossary: [GlossaryEntryDefinition] }
struct OnboardingStepDefinition: Codable, Identifiable, Sendable { let id: UUID; var title: String; var body: String; var target: String; var action: String; var order: Int; var required: Bool }
struct OnboardingDefinition: Codable, Sendable { var id: UUID; var version: Int; var enabled: Bool; var allowSkip: Bool; var requiredAfterUpgrade: Bool; var steps: [OnboardingStepDefinition] }
struct AssistantPolicyDefinition: Codable, Sendable { var enabled: Bool; var requireFirstRunConfiguration: Bool; var proactive: Bool; var warnOnKnownPath: Bool; var defaultFrequency: Int; var offlineCapabilities: [String] }
struct JournalPolicyDefinition: Codable, Sendable { var enabled: Bool; var allowExport: Bool; var retentionDays: Int; var showStoryTimeline: Bool }
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
    var journeys: [JourneyDefinition]? = nil
    var assignments: [CatalogAssignmentDefinition]? = nil
    var intro: IntroDefinition
    var playerShell: PlayerShellDefinition
    var demo: DemoExperienceDefinition
    var help: HelpCenterDefinition
    var onboarding: OnboardingDefinition
    var assistantPolicy: AssistantPolicyDefinition
    var journal: JournalPolicyDefinition
}
struct PublishedExperienceView: Decodable, Sendable {
    let version: Int
    let publishedAt: Date
    let document: ExperienceDocument
}

/// Amorce cliente servie par `GET /client-bootstrap/{frontId}`, **route anonyme**.
///
/// C'est le seul contrat qui donne au client son identité (nom, accroche, charte) *avant*
/// toute authentification. Tous les champs au-delà de `frontId` sont optionnels : une
/// instance qui n'en publierait qu'une partie ne doit pas empêcher le démarrage, le client
/// retombant alors sur ses valeurs de repli documentées.
///
/// `publishedAt` n'est délibérément pas décodé : le champ n'est pas utilisé et son format
/// de date ne doit pas pouvoir faire échouer l'amorce entière.
struct ClientBootstrapView: Decodable, Sendable {
    let frontId: String
    let version: Int?
    let applicationName: String?
    let shortName: String?
    let tagline: String?
    let branding: ClientBrandingView?
    let locale: String?
    let timeZone: String?
    let labels: [String: String]?
    let authenticationMode: String?
    let demoEnabled: Bool?
    let intro: IntroDefinition?
}

struct ClientBrandingView: Decodable, Sendable {
    let applicationName: String?
    let shortName: String?
    let tagline: String?
    let brandIconUrl: String?
    let clientIconUrl: String?
    let logoUrl: String?
    let faviconUrl: String?
    let theme: ClientThemeView?
    /// Jetons d'accent nommés, tels que les portent catégories, parcours et familiers.
    let accentPalette: [String: String]?
}

struct ClientThemeView: Decodable, Sendable {
    let colors: [String: String]?
    let colorScheme: String?
    let cornerRadius: Double?
    let fontFamily: String?
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
    let customName: String?
    let interventionFrequency: Int
    let proactive: Bool
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
    let familiarDefinition: FamiliarDefinition?
    let onboarding: OnboardingStateView
    let masteries: [ScenarioMasteryView]
    let ownedOfferIds: [UUID]
    let recentEntries: [WalletEntryView]
    let recentJournal: [PlayerJournalEntryView]
}
struct OnboardingStateView: Decodable, Sendable { let tutorialId: UUID; let version: Int; let status: String; let completedStepIds: [UUID]; let completedAt: Date?; let skippedAt: Date?; let revision: Int }
struct ScenarioMasteryView: Decodable, Identifiable, Sendable { var id: UUID { scenarioVersionId }; let scenarioId: UUID; let scenarioVersionId: UUID; let choiceIds: [String]; let nodeIds: [String]; let endingIds: [String]; let discoveredObjectives: Int; let totalObjectives: Int; let masteryPercent: Int; let updatedAt: Date }
struct PlayerJournalEntryView: Decodable, Identifiable, Sendable { let id: UUID; let type: String; let title: String; let summary: String; let journeyId: UUID?; let categoryId: UUID?; let scenarioId: UUID?; let scenarioVersionId: UUID?; let sessionId: UUID?; let referenceId: String?; let occurredAt: Date }
struct PlayerBootstrapView: Decodable, Sendable { let nextAction: String; let experience: PlayerExperienceView; let tutorial: OnboardingDefinition; let assistant: AssistantPolicyDefinition }
struct JournalView: Decodable, Sendable { let items: [PlayerJournalEntryView]; let total: Int; let totalsByType: [String: Int] }
struct OnboardingCommandRequest: Encodable, Sendable { let idempotencyKey: String }
struct ContextualHelpRequest: Encodable, Sendable { let context: String; let scenarioVersionId: UUID?; let choiceId: String?; let alreadyExplored: Bool; let authorHint: String? }
struct ContextualHelpView: Decodable, Sendable { let source: String; let message: String; let isFallback: Bool; let familiarName: String; let avatarUrl: String? }
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
