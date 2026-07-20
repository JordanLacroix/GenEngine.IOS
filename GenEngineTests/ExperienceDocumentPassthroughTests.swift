import Foundation
import Testing
@testable import GenEngine

/// `PUT /admin/configuration` remplace le document **entier** côté moteur, sans fusion
/// (`ConfigurationService.UpsertAsync`). Un aller-retour décodage/réencodage doit donc
/// restituer tous les blocs, y compris ceux que ce client ne modélise pas — sinon
/// sauvegarder depuis un écran d'administration efface le paramétrage d'un autre.
///
/// La fixture est le document **réellement servi** par `GET /experience/{frontId}`,
/// et non une reconstitution : c'est ce qui garantit que le test suit le contrat du
/// moteur plutôt qu'une idée qu'on s'en fait.
struct ExperienceDocumentPassthroughTests {
    private func loadFixture() throws -> Data {
        let bundle = Bundle(for: FixtureAnchor.self)
        let url = try #require(
            bundle.url(forResource: "experience-document", withExtension: "json"),
            "fixture experience-document.json absente du bundle de tests")
        return try Data(contentsOf: url)
    }

    private func roundTrip() throws -> [String: Any] {
        let document = try JSONDecoder().decode(ExperienceDocument.self, from: loadFixture())
        let reencoded = try JSONEncoder().encode(document)
        return try #require(try JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
    }

    /// Le document réel doit se décoder : si le moteur ajoute un bloc, le client ne
    /// doit pas échouer, seulement l'ignorer.
    @Test func realDocumentDecodes() throws {
        let document = try JSONDecoder().decode(ExperienceDocument.self, from: loadFixture())
        #expect(document.frontId.isEmpty == false)
        #expect(document.passthrough.isEmpty == false, "aucun bloc non modélisé capté")
    }

    /// `media` porte l'ambiance sonore de l'instance. Le perdre remet le son aux défauts.
    @Test func mediaBlockSurvives() throws {
        let object = try roundTrip()
        let media = try #require(object["media"] as? [String: Any], "bloc media perdu")
        #expect(media["locations"] != nil)
        #expect(media["enabled"] != nil)
    }

    /// `finale` décrit le scénario de fin global. Absent du renvoi, il passe à `null`
    /// côté moteur — la fin de jeu de l'instance disparaît.
    @Test func finaleBlockSurvives() throws {
        let object = try roundTrip()
        #expect(object["finale"] != nil, "bloc finale perdu")
    }

    /// `branding` porte le nom, la charte et la palette de l'instance.
    @Test func brandingBlockSurvives() throws {
        let object = try roundTrip()
        #expect(object["branding"] != nil, "bloc branding perdu")
    }

    /// Aucun bloc du document servi ne doit manquer au renvoi, quels qu'ils soient :
    /// c'est la garantie qui vaudra encore pour les blocs ajoutés plus tard.
    @Test func everyServedBlockSurvives() throws {
        let original = try #require(
            try JSONSerialization.jsonObject(with: loadFixture()) as? [String: Any])
        let object = try roundTrip()

        let lost = Set(original.keys).subtracting(object.keys)
        #expect(lost.isEmpty, "blocs perdus au renvoi : \(lost.sorted().joined(separator: ", "))")
    }

    /// La préservation ne doit pas figer le document : les champs modélisés restent
    /// modifiables, et une modification n'emporte pas les blocs inconnus.
    @Test func modelledFieldsRemainEditable() throws {
        var document = try JSONDecoder().decode(ExperienceDocument.self, from: loadFixture())
        document.game.name = "Nouveau nom"

        let reencoded = try JSONEncoder().encode(document)
        let object = try #require(
            try JSONSerialization.jsonObject(with: reencoded) as? [String: Any])

        #expect((object["game"] as? [String: Any])?["name"] as? String == "Nouveau nom")
        #expect(object["media"] != nil, "modifier un champ connu ne doit pas perdre media")
        #expect(object["finale"] != nil, "modifier un champ connu ne doit pas perdre finale")
    }
}

/// Ancre de bundle pour atteindre les fixtures du bundle de tests.
private final class FixtureAnchor {}
