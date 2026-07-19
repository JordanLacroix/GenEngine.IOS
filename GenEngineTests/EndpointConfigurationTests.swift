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

    @Test("Basculer de mode ne perd jamais la saisie")
    func switchingModeKeepsInput() throws {
        // Six URLs saisies en unitaire disparaissaient au premier contact avec « Groupé »,
        // et l'enregistrement repartait en silence sur les valeurs d'origine.
        var draft = EndpointDraft(scatteredEndpoints)
        #expect(draft.mode == .individual)
        draft.switchMode(to: .grouped)
        draft.switchMode(to: .individual)
        #expect(draft.resolvedURL(for: .play) == "https://play.exemple.test")
        #expect(draft.resolvedURL(for: .organization) == "https://org.exemple.test")

        // Dans l'autre sens, l'hôte et les ports saisis en groupé deviennent le point de
        // départ du mode unitaire, au lieu de laisser six champs périmés.
        var grouped = EndpointDraft(groupedEndpoints)
        grouped.host = "10.0.0.9"
        grouped.switchMode(to: .individual)
        #expect(grouped.resolvedURL(for: .identity) == "https://10.0.0.9:5203")

        // Et six URLs qui partagent l'hôte sont adoptées, pas ignorées.
        var adopted = EndpointDraft(scatteredEndpoints)
        for service in ServiceKind.allCases {
            adopted.urls[service] = "http://192.168.1.42:\(service.defaultPort)"
        }
        adopted.switchMode(to: .grouped)
        #expect(adopted.host == "192.168.1.42")
        #expect(adopted.scheme == "http")
        #expect(adopted.resolvedURL(for: .play) == "http://192.168.1.42:5202")
    }

    @Test("Un hôte collé avec son port est refusé au lieu de produire une URL cassée")
    func rejectsHostCarryingItsPort() {
        var draft = EndpointDraft(groupedEndpoints)
        draft.host = "192.168.1.10:5201"
        // Sans ce contrôle : « https://192.168.1.10:5201:5201 », six services injoignables.
        #expect(draft.validationMessage?.contains("port") == true)
        #expect(draft.endpoints() == nil)
    }

    @Test("Des ports vides ou dupliqués sont refusés")
    func rejectsEmptyOrDuplicatePorts() {
        var draft = EndpointDraft(groupedEndpoints)
        draft.ports[.play] = ""
        #expect(draft.validationMessage?.contains("Play") == true)

        var duplicated = EndpointDraft(groupedEndpoints)
        duplicated.ports[.play] = duplicated.ports[.identity]
        // Six services sur la même origine : l'application taperait à côté partout.
        #expect(duplicated.validationMessage?.contains("5203") == true)
        #expect(duplicated.endpoints() == nil)
    }

    @Test("Les six services portent chacun un port de référence distinct")
    func defaultPortsAreDistinct() {
        let ports = ServiceKind.allCases.map(\.defaultPort)
        #expect(Set(ports).count == ServiceKind.allCases.count)
        #expect(ports.allSatisfy { (5201...5206).contains($0) })
    }
}

/// Viewports réels. Un test posé en coordonnées monde ne peut structurellement pas
/// détecter un chevauchement : celui-ci n'existe qu'après projection, et relativement à la
/// taille écran des portes. Ces assertions sont donc toutes en points écran.
private let viewports: [(name: String, size: CGSize)] = [
    ("iPhone portrait", CGSize(width: 393, height: 852)),
    ("iPhone paysage", CGSize(width: 852, height: 393)),
    ("iPhone SE portrait", CGSize(width: 375, height: 667)),
    ("iPad portrait", CGSize(width: 834, height: 1_194)),
    ("iPad paysage", CGSize(width: 1_194, height: 834))
]

private func doorRects(_ placement: PlayerExperiencePresentation.DoorPlacement) -> [CGRect] {
    placement.positions.map { center in
        CGRect(
            x: center.x - placement.size.width / 2,
            y: center.y - placement.size.height / 2,
            width: placement.size.width,
            height: placement.size.height)
    }
}

struct DoorLayoutTests {
    @Test("Aucune porte ne sort du cadre, sur aucun appareil")
    func everyDoorStaysOnScreen() {
        for (name, viewport) in viewports {
            for total in [1, 3, 5, 6, 9, 15, 50] {
                let placement = PlayerExperiencePresentation.doorPlacement(total: total, viewport: viewport)
                for rect in doorRects(placement) {
                    #expect(rect.minX >= 0, "\(name), \(total) portes : \(rect.minX) hors cadre à gauche")
                    #expect(rect.maxX <= viewport.width, "\(name), \(total) portes : \(rect.maxX) dépasse \(viewport.width)")
                    #expect(rect.minY >= 0, "\(name), \(total) portes : \(rect.minY) hors cadre en haut")
                    #expect(rect.maxY <= viewport.height, "\(name), \(total) portes : \(rect.maxY) dépasse \(viewport.height)")
                }
            }
        }
    }

    @Test("Deux portes ne se recouvrent jamais, donc aucune ne vole le tap d’une autre")
    func doorsNeverOverlap() {
        for (name, viewport) in viewports {
            for total in [2, 5, 6, 9, 15, 50] {
                let placement = PlayerExperiencePresentation.doorPlacement(total: total, viewport: viewport)
                let rects = doorRects(placement)
                for (index, rect) in rects.enumerated() {
                    for other in rects.dropFirst(index + 1) {
                        #expect(!rect.intersects(other), "\(name), \(total) portes : recouvrement \(rect) / \(other)")
                    }
                }
            }
        }
    }

    @Test("Une porte reste au moins aussi grande que la cible tactile")
    func doorsStayTappable() {
        for (name, viewport) in viewports {
            for total in [1, 6, 15, 50] {
                let placement = PlayerExperiencePresentation.doorPlacement(total: total, viewport: viewport)
                guard !placement.positions.isEmpty else { continue }
                #expect(placement.size.width >= HUDMetrics.minimumTarget, "\(name), \(total) portes : largeur \(placement.size.width)")
                #expect(placement.size.height >= HUDMetrics.minimumTarget, "\(name), \(total) portes : hauteur \(placement.size.height)")
            }
        }
    }

    @Test("Toute catégorie est atteignable : la somme des pages couvre le total")
    func paginationCoversEveryCategory() {
        for (name, viewport) in viewports {
            for total in [1, 6, 15, 50] {
                var seen: Set<Int> = []
                let first = PlayerExperiencePresentation.doorPlacement(total: total, viewport: viewport)
                for page in 0..<first.pageCount {
                    let placement = PlayerExperiencePresentation.doorPlacement(total: total, page: page, viewport: viewport)
                    #expect(placement.positions.count == placement.range.count)
                    seen.formUnion(placement.range)
                }
                #expect(seen == Set(0..<total), "\(name), \(total) portes : \(total - seen.count) catégorie(s) inatteignable(s)")
            }
        }
    }

    @Test("Les ancrages de la carte ne servent que là où ils tiennent")
    func handmadeAnchorsOnlyWhereTheyFit() {
        // iPhone portrait : la carte est rognée par l'aspect-fill, les ancrages projetés
        // sortaient du cadre. C'était le défaut — ils étaient posés sans aucun contrôle.
        let phone = CGSize(width: 393, height: 852)
        let portrait = PlayerExperiencePresentation.doorPlacement(total: 5, viewport: phone)
        let projected = PlayerExperiencePresentation.doorAnchors(for: phone)
            .prefix(5)
            .map { PlayerExperiencePresentation.projectMapPoint($0, into: phone) }
        #expect(portrait.positions != Array(projected))
        for rect in doorRects(portrait) { #expect(rect.minX >= 0 && rect.maxX <= phone.width) }
    }

    @Test("Sur un grand écran, la carte garde ses ancrages dessinés")
    func handmadeAnchorsSurviveOnLargeScreens() {
        // Sans cette assertion, le chemin des ancrages pourrait devenir du code mort sans
        // que rien ne le signale : la grille de repli satisfait toutes les autres règles.
        let placement = PlayerExperiencePresentation.doorPlacement(total: 5, viewport: CGSize(width: 1_194, height: 834))
        #expect(placement.usesMapAnchors)
        #expect(placement.positions.count == 5)
    }

    @Test("Une page ne promet jamais plus de portes qu’elle n’en place")
    func pageRangeMatchesPositions() {
        for (_, viewport) in viewports {
            for total in [1, 7, 23] {
                let placement = PlayerExperiencePresentation.doorPlacement(total: total, viewport: viewport)
                #expect(placement.range.count == placement.positions.count)
                #expect(placement.range.upperBound <= total)
            }
        }
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
