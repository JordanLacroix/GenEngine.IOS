import CoreGraphics
import Foundation
import Testing
@testable import GenEngine

private let groupedEndpoints = ServiceEndpoints(
    identity: "https://services.exemple.test:5203",
    authoring: "https://services.exemple.test:5201",
    play: "https://services.exemple.test:5202",
    configuration: "https://services.exemple.test:5204",
    playerExperience: "https://services.exemple.test:5205",
    organization: "https://services.exemple.test:5206")

private let scatteredEndpoints = ServiceEndpoints(
    identity: "https://identity.exemple.test",
    authoring: "https://authoring.exemple.test",
    play: "https://play.exemple.test",
    configuration: "https://config.exemple.test",
    playerExperience: "https://px.exemple.test",
    organization: "https://org.exemple.test")

struct EndpointDraftTests {
    @Test("Un déploiement sur une seule machine est reconnu comme groupé")
    func detectsGroupedDeployment() {
        let draft = EndpointDraft(groupedEndpoints)
        #expect(draft.mode == .grouped)
        #expect(draft.host == "services.exemple.test")
        #expect(draft.scheme == "https")
        #expect(draft.ports[.organization] == "5206")
    }

    @Test("Un déploiement multi-machines reste en mode unitaire")
    func detectsScatteredDeployment() {
        let draft = EndpointDraft(scatteredEndpoints)
        #expect(draft.mode == .individual)
        #expect(draft.resolvedURL(for: .play) == "https://play.exemple.test")
    }

    @Test("Le mode groupé reconstruit les six adresses, organisation comprise")
    func rebuildsSixEndpoints() throws {
        var draft = EndpointDraft(groupedEndpoints)
        draft.host = "10.0.0.9"
        draft.scheme = "http"
        let endpoints = try #require(draft.endpoints())
        #expect(endpoints.authoring == "http://10.0.0.9:5201")
        #expect(endpoints.play == "http://10.0.0.9:5202")
        #expect(endpoints.identity == "http://10.0.0.9:5203")
        #expect(endpoints.configuration == "http://10.0.0.9:5204")
        #expect(endpoints.playerExperience == "http://10.0.0.9:5205")
        #expect(endpoints.organization == "http://10.0.0.9:5206")
    }

    @Test("Une saisie invalide est refusée explicitement plutôt que corrigée")
    func rejectsInvalidInput() {
        var draft = EndpointDraft(groupedEndpoints)
        draft.host = ""
        #expect(!draft.isValid)
        #expect(draft.endpoints() == nil)

        draft.host = "services.exemple.test"
        draft.ports[.play] = "99999"
        #expect(draft.validationMessage?.contains("Play") == true)

        var individual = EndpointDraft(scatteredEndpoints)
        individual.urls[.organization] = "pas-une-url"
        #expect(individual.validationMessage?.contains("Organization") == true)
    }

    @Test("Les six services portent chacun un port de référence distinct")
    func defaultPortsAreDistinct() {
        let ports = ServiceKind.allCases.map(\.defaultPort)
        #expect(Set(ports).count == ServiceKind.allCases.count)
        #expect(ports.allSatisfy { (5201...5206).contains($0) })
    }
}

struct DoorLayoutTests {
    private let landscape = CGSize(width: 1_200, height: 800)

    @Test("Aucune catégorie n’est écartée, quel que soit leur nombre")
    func placesEveryCategory() {
        for count in [1, 5, 6, 9, 17, 40] {
            let anchors = PlayerExperiencePresentation.doorAnchors(count: count, for: landscape)
            #expect(anchors.count == count)
        }
    }

    @Test("Les ancrages dessinés à la main restent utilisés tant qu’ils suffisent")
    func keepsHandmadeAnchors() {
        let anchors = PlayerExperiencePresentation.doorAnchors(count: 3, for: landscape)
        #expect(anchors == Array(PlayerExperiencePresentation.doorAnchors.prefix(3)))
    }

    @Test("Au-delà, les portes restent dans le cadre de la carte et distinctes")
    func dispersesWithoutOverlap() {
        let anchors = PlayerExperiencePresentation.doorAnchors(count: 12, for: landscape)
        let size = PlayerExperiencePresentation.worldMapSize
        for point in anchors {
            #expect(point.x >= 0 && point.x <= size.width)
            #expect(point.y >= 0 && point.y <= size.height)
        }
        #expect(Set(anchors.map { "\($0.x)|\($0.y)" }).count == anchors.count)
    }

    @Test("La progression d’une porte reprend la donnée déjà affichée ailleurs")
    func computesDoorProgress() {
        let versionID = UUID()
        let scenarioID = UUID()
        let category = CategoryDefinition(
            id: UUID(), name: "Lucidité", description: "", accent: "amber",
            order: 1, isVisible: true, imageUrl: nil, scenarioIds: [scenarioID])
        let story = StorySummary(
            id: versionID.uuidString.lowercased(), title: "Récit", eyebrow: "", synopsis: "",
            duration: "", symbol: "book", accent: .verdigris,
            availability: .published(versionID), scenarioID: scenarioID)
        let saved = SavedSession(
            id: UUID(), scenarioVersionId: versionID, title: "Récit",
            status: "En cours", revision: 1, turn: 2, updatedAt: .now)

        let untouched = PlayerExperiencePresentation.doorProgress(category: category, stories: [story], savedSessions: [])
        #expect(untouched.total == 1)
        #expect(untouched.started == 0)
        #expect(untouched.percent == 0)

        let started = PlayerExperiencePresentation.doorProgress(category: category, stories: [story], savedSessions: [saved])
        #expect(started.started == 1)
        #expect(started.percent == 100)
    }
}
