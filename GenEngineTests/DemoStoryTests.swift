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
        #expect(visited.count == 23)
        #expect(DemoStory.orderedNodes.count == 23)
    }

    @Test func openingHubSamplesThreeUseCases() {
        let hub = DemoStory.node(id: DemoStory.openingNodeID)
        #expect(hub?.choices.map(\.posture) == ["Lucidité", "Courage", "Transmission"])
        #expect(hub?.choices.map(\.target) == ["note-arrivee", "reunion-table", "spec-demande"])
    }

    @Test func demoEndingsStopInsteadOfLooping() {
        let endings = DemoStory.orderedNodes.filter(\.isEnding)
        #expect(endings.count == 12)
        #expect(endings.allSatisfy { $0.choices.isEmpty })
        #expect(DemoStory.node(id: "note-arrivee")?.interaction != nil)
        #expect(DemoStory.node(id: "reunion-table")?.interaction != nil)
        #expect(DemoStory.node(id: "spec-affirmations")?.interaction != nil)
    }

    @Test func everyEndingDeclaresItsOutcomeFollowingTheCanonicalNaming() {
        for node in DemoStory.orderedNodes {
            if node.isEnding {
                let outcome = try? #require(node.outcome)
                #expect(outcome != nil, "ending \(node.id) has no outcome")
                if let outcome { #expect(node.id.hasPrefix("fin-\(outcome.rawValue)")) }
            } else {
                #expect(node.outcome == nil, "non-ending \(node.id) declares an outcome")
            }
        }
    }

    @Test func eachSituationReachesAFailureEnding() {
        for prefix in ["note", "reunion", "spec"] {
            let reaches = DemoStory.orderedNodes.contains { node in
                node.id.hasPrefix(prefix) && node.choices.contains { DemoStory.node(id: $0.target)?.outcome == .rupture }
            }
            #expect(reaches, "situation \(prefix) has no failure ending")
        }
        #expect(DemoStory.orderedNodes.filter { $0.outcome == .rupture }.count == 6)
    }

    @Test func choiceTonesOnlyUseDiapasonPostures() {
        for node in DemoStory.orderedNodes {
            for choice in node.choices {
                #expect(PlayerExperiencePresentation.diapasonPostures.contains(choice.posture), "unknown posture \(choice.posture)")
            }
        }
    }

    @Test func demoCarriesNoWordingFromTheStoryDiapasonReplaced() {
        let corpus = DemoStory.orderedNodes
            .map { "\($0.title) \($0.text) \($0.choices.map(\.text).joined(separator: " "))" }
            .joined(separator: " ")
            .lowercased()
        for word in ["phare", "brume", "lueur", "beacon", "maritime", "oiseaux", "braises"] {
            #expect(!corpus.contains(word), "legacy wording \"\(word)\" is still present")
        }
        #expect(!DemoStory.summary.title.lowercased().contains("brume"))
    }

    @Test func ruptureEndingIsAnnouncedAsUnrecoverable() {
        #expect(PlayerExperiencePresentation.demoOutcomeTitle(.rupture) == "La situation ne peut plus être rattrapée.")
        #expect(PlayerExperiencePresentation.demoOutcomeNote(.rupture).contains("depuis le début"))
        #expect(PlayerExperiencePresentation.demoFrequencyLabel(.rupture).hasPrefix("Aucune fréquence"))
        #expect(PlayerExperiencePresentation.demoFrequencyLabel(.accord).hasPrefix("Fréquence du doute :"))
    }

    @Test func demoPosturesFollowTheTraversedPath() {
        #expect(PlayerExperiencePresentation.demoPostures(["accueil"]).isEmpty)
        #expect(PlayerExperiencePresentation.demoPostures(["accueil", "spec-demande", "spec-affirmations"]) == ["Transmission"])
        #expect(PlayerExperiencePresentation.demoPostures(["accueil", "note-arrivee", "note-provenance"]) == ["Lucidité"])
    }

    @Test func narrativeTreeProjectionUsesSceneTitles() {
        let tree = DemoStory.narrativeTree(path: ["accueil", "spec-demande"])
        #expect(tree.initialNodeId == "accueil")
        #expect(tree.currentNodeId == "spec-demande")
        #expect(tree.nodes.count == 23)
        #expect(tree.nodes.first { $0.id == "spec-demande" }?.text == "La spécification avant le code")
        #expect(tree.nodes.first { $0.id == "fin-rupture-relais" }?.isEnding == true)
        #expect(tree.nodes.first { $0.id == "accueil" }?.state == "Visited")
    }

    @Test func familiarAssetPackRequiresHTTPSOrBundledAsset() throws {
        #expect(throws: FamiliarAssetPackError.self) {
            _ = try FamiliarAssetPack(schemaVersion: 1, id: "unsafe", name: "Unsafe", targetFamiliarId: nil, bundledAssetName: nil, portraitUrl: URL(string: "http://example.test/pet.png"), license: "Test", attribution: "Test").validated()
        }
        #expect(try FamiliarAssetPack.tierce.validated().id == "genengine.tierce.original")
    }

    @Test func worldDoorAnchorsFollowTheScaledMap() {
        let center = PlayerExperiencePresentation.projectMapPoint(CGPoint(x: 768, y: 512), into: CGSize(width: 2048, height: 930))
        let domain = PlayerExperiencePresentation.projectMapPoint(CGPoint(x: 392, y: 430), into: CGSize(width: 2048, height: 930))
        #expect(center.x == 1024)
        #expect(center.y == 465)
        #expect(abs(domain.x - 522.667) < 0.01)
        #expect(abs(domain.y - 355.667) < 0.01)
        #expect(PlayerExperiencePresentation.doorAnchors(for: CGSize(width: 768, height: 1024))[1] == CGPoint(x: 879, y: 416))
    }

    /// En portrait, le plan est recadré en `cover` sur la largeur : une ancre
    /// trop excentrée sort du champ et sa porte devient invisible. C'était le
    /// cas des anciennes ancres compactes en `x: 390` et `x: 1070`. Les bornes
    /// verticales tiennent compte du titre de la carte et de la barre d'onglets.
    @Test func compactDoorAnchorsStayInsideAPortraitViewport() {
        for viewport in [CGSize(width: 390, height: 844), CGSize(width: 375, height: 812)] {
            for anchor in PlayerExperiencePresentation.doorAnchors(for: viewport) {
                let point = PlayerExperiencePresentation.projectMapPoint(anchor, into: viewport)
                #expect(point.x > 55 && point.x < viewport.width - 55)
                #expect(point.y > 250 && point.y < viewport.height - 120)
            }
        }
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
        let first = StorySummary(id: "v2", title: "Le Diapason — trois situations", eyebrow: "Publié", synopsis: "A", duration: "15 min", symbol: "book", accent: .ember, availability: .published(UUID()), scenarioID: scenarioID)
        let older = StorySummary(id: "v1", title: "Ancien titre", eyebrow: "Publié", synopsis: "B", duration: "15 min", symbol: "book", accent: .ember, availability: .published(UUID()), scenarioID: scenarioID)
        let demo = StorySummary(id: "demo", title: "LE DIAPASON — TROIS SITUATIONS", eyebrow: "Démo", synopsis: "C", duration: "15 min", symbol: "book", accent: .ember, availability: .demo)

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
