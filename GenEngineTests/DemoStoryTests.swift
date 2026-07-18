import Foundation
import Testing
@testable import GenEngine

struct DemoStoryTests {
    @Test func everyChoiceTargetsAnExistingNode() {
        var visited = Set<String>()
        var pending = [DemoStory.openingNodeID]
        while let id = pending.popLast() {
            guard visited.insert(id).inserted else { continue }
            let node = DemoStory.node(id: id)
            #expect(node != nil)
            pending.append(contentsOf: node?.choices.map(\.target) ?? [])
        }
        #expect(visited.count == 13)
    }

    @Test func demoEndingsStopInsteadOfLooping() {
        #expect(DemoStory.node(id: "dawn")?.choices.isEmpty == true)
        #expect(DemoStory.node(id: "watch")?.choices.isEmpty == true)
        #expect(DemoStory.node(id: "shore")?.interaction != nil)
    }

    @Test func familiarAssetPackRequiresHTTPSOrBundledAsset() throws {
        #expect(throws: FamiliarAssetPackError.self) {
            _ = try FamiliarAssetPack(schemaVersion: 1, id: "unsafe", name: "Unsafe", targetFamiliarId: nil, bundledAssetName: nil, portraitUrl: URL(string: "http://example.test/pet.png"), license: "Test", attribution: "Test").validated()
        }
        #expect(try FamiliarAssetPack.aster.validated().id == "genengine.aster.original")
    }

    @Test func worldDoorAnchorsFollowTheScaledMap() {
        let center = PlayerExperiencePresentation.projectMapPoint(CGPoint(x: 768, y: 512), into: CGSize(width: 2048, height: 930))
        let lighthouse = PlayerExperiencePresentation.projectMapPoint(CGPoint(x: 390, y: 330), into: CGSize(width: 2048, height: 930))
        #expect(center.x == 1024)
        #expect(center.y == 465)
        #expect(abs(lighthouse.x - 520) < 0.01)
        #expect(abs(lighthouse.y - 222.333) < 0.01)
        #expect(PlayerExperiencePresentation.doorAnchors(for: CGSize(width: 768, height: 1024))[1] == CGPoint(x: 770, y: 570))
    }

    @Test func playerExperienceValuesAreLocalized() {
        #expect(PlayerExperiencePresentation.journalTypeLabel("ChoiceSelected") == "Choix effectué")
        #expect(PlayerExperiencePresentation.familiarOptionLabel("spark") == "Étincelle")
        #expect(PlayerExperiencePresentation.familiarOptionLabel("Mysterious") == "Mystérieux")
    }

    @Test(arguments: [("\"AwaitingInput\"", SessionStatus.awaitingInput), ("2", SessionStatus.completed)])
    func sessionStatusAcceptsStringAndNumericContracts(json: String, expected: SessionStatus) throws {
        let decoded = try JSONDecoder().decode(SessionStatus.self, from: Data(json.utf8))
        #expect(decoded == expected)
    }

    @Test(arguments: [
        ("\"AwaitingExternalInput\"", SessionStatus.awaitingExternalInput),
        ("\"AwaitingValidation\"", SessionStatus.awaitingValidation),
        ("4", SessionStatus.awaitingExternalInput),
        ("5", SessionStatus.awaitingValidation)
    ])
    func sessionStatusAcceptsTypedInteractionStates(json: String, expected: SessionStatus) throws {
        let decoded = try JSONDecoder().decode(SessionStatus.self, from: Data(json.utf8))
        #expect(decoded == expected)
    }

    @Test func currentStepDecodesFreeTextAnalysis() throws {
        let json = #"{"nodeId":"clue","text":"Que retenez-vous ?","status":"AwaitingValidation","choices":[],"turn":2,"interactionId":"testimony","kind":"FreeText","pendingTextAnalysis":{"interactionId":"testimony","isAccepted":true,"matchedTerms":["lanterne"],"minimumMatches":1,"explanation":"1 required term matched."}}"#
        let step = try JSONDecoder().decode(CurrentStep.self, from: Data(json.utf8))
        #expect(step.kind == .freeText)
        #expect(step.pendingTextAnalysis?.isAccepted == true)
        #expect(step.pendingTextAnalysis?.matchedTerms == ["lanterne"])
    }

    @Test func publishedContractMapsToPlayableStory() {
        let versionID = UUID()
        let published = PublishedScenarioView(
            scenarioId: UUID(),
            versionId: versionID,
            versionNumber: 3,
            title: "Le récit publié",
            description: "Une ouverture venue du moteur.",
            estimatedMinutes: 9,
            publishedAt: .now,
            snapshotHash: "hash",
            categoryId: nil)

        let story = StorySummary(published: published)

        #expect(story.id == versionID.uuidString.lowercased())
        #expect(story.title == "Le récit publié")
        #expect(story.duration == "9 min")
        #expect(story.availability == .published(versionID))
    }

    @Test func catalogRemovesDuplicateScenarioVersionsAndDemoTitles() {
        let scenarioID = UUID()
        let first = StorySummary(id: "v2", title: "Les braises sous la brume", eyebrow: "Publié", synopsis: "A", duration: "15 min", symbol: "book", accent: .ember, availability: .published(UUID()), scenarioID: scenarioID)
        let older = StorySummary(id: "v1", title: "Ancien titre", eyebrow: "Publié", synopsis: "B", duration: "15 min", symbol: "book", accent: .ember, availability: .published(UUID()), scenarioID: scenarioID)
        let demo = StorySummary(id: "demo", title: "LES BRAISES SOUS LA BRUME", eyebrow: "Démo", synopsis: "C", duration: "15 min", symbol: "book", accent: .ember, availability: .demo)

        let result = StoryCatalog.unique([first, older, demo])

        #expect(result.map(\.id) == ["v2"])
    }

    @Test func legacyEndpointPreferencesKeepPhysicalDeviceHost() throws {
        let json = #"{"identity":"http://192.168.1.20:5203","authoring":"http://192.168.1.20:5201","play":"http://192.168.1.20:5202","configuration":"http://192.168.1.20:5204","playerExperience":"http://192.168.1.20:5205"}"#

        let endpoints = try JSONDecoder().decode(ServiceEndpoints.self, from: Data(json.utf8))

        #expect(endpoints.organization == "http://192.168.1.20:5206")
        #expect(endpoints.identity == "http://192.168.1.20:5203")
    }
}
