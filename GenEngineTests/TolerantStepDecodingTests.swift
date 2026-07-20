import Foundation
import Testing
@testable import GenEngine

/// Décodage tolérant de `CurrentStep`.
///
/// Ces tests gardent un défaut réel et bloquant : `InteractionKind` jetait sur toute
/// valeur inconnue, si bien que le `kind: "Document"` du schéma v6 faisait échouer le
/// décodage **entier** de `CurrentStep`. La session ne se dégradait pas, elle se
/// bloquait. Le moteur reste autoritatif sur les états narratifs et en ajoutera
/// d'autres : le client doit continuer de jouer sans les comprendre.
struct TolerantStepDecodingTests {
    private func decodeStep(_ json: String) throws -> CurrentStep {
        try JSONDecoder().decode(CurrentStep.self, from: Data(json.utf8))
    }

    private func step(kind: String, extra: String = "") -> String {
        """
        {"nodeId":"n1","text":"Un texte","status":"AwaitingInput","choices":[],"turn":0,"kind":\(kind)\(extra)}
        """
    }

    // MARK: - Le défaut d'origine

    @Test func documentKindIsRecognised() throws {
        #expect(try decodeStep(step(kind: "\"Document\"")).kind == .document)
    }

    /// La garantie qui vaut pour les valeurs qui n'existent pas encore : un `kind`
    /// inconnu ne jette pas, il dégrade.
    @Test func anUnknownKindDoesNotThrow() throws {
        let decoded = try decodeStep(step(kind: "\"Hologram\""))
        #expect(decoded.kind == .unknown("Hologram"))
        #expect(decoded.text == "Un texte", "le reste du pas doit rester lisible")
    }

    @Test func anUnknownNumericKindDoesNotThrow() throws {
        #expect(try decodeStep(step(kind: "99")).kind == .unknown("99"))
    }

    @Test func anUnknownSessionStatusDoesNotThrow() throws {
        let json = """
        {"nodeId":"n1","text":"Un texte","status":"AwaitingArbitration","choices":[],"turn":0,"kind":"Narration"}
        """
        let decoded = try decodeStep(json)
        #expect(decoded.status == .unknown("AwaitingArbitration"))
        #expect(decoded.status.label == "État inconnu")
    }

    @Test func knownKindsAndStatusesStillDecode() throws {
        #expect(try decodeStep(step(kind: "\"FreeText\"")).kind == .freeText)
        #expect(try decodeStep(step(kind: "5")).kind == .freeText)
        #expect(try JSONDecoder().decode(SessionStatus.self, from: Data("\"AwaitingValidation\"".utf8)) == .awaitingValidation)
    }

    // MARK: - Champs du schéma v6

    @Test func optionalityAndExitChoicesDefaultToAbsent() throws {
        let decoded = try decodeStep(step(kind: "\"Narration\""))
        #expect(decoded.isOptional == false)
        #expect(decoded.exitChoices.isEmpty)
        #expect(decoded.document == nil)
    }

    @Test func exitChoicesAndOptionalityAreRead() throws {
        let extra = #","isOptional":true,"exitChoices":[{"id":"c1","text":"Partir sans lire"}]"#
        let decoded = try decodeStep(step(kind: "\"Document\"", extra: extra))
        #expect(decoded.isOptional)
        #expect(decoded.exitChoices.map(\.id) == ["c1"])
    }

    // MARK: - Le document lui-même

    @Test func aDocumentDecodesWithAllItsBlockShapes() throws {
        let json = """
        {"nodeId":"n1","text":"t","status":"AwaitingInput","choices":[],"turn":0,"kind":"Document","document":{
          "title":"Classement automatique","nature":"Table",
          "headers":[{"name":"Source","value":"Outil de présélection"}],
          "excerpt":{"shownUnits":6,"totalUnits":412,"unit":"Rows"},
          "blocks":[
            {"$type":"paragraph","text":"Un paragraphe."},
            {"$type":"lines","lines":[{"text":"boot","marker":"Info","label":"08:03"},{"text":"nu"}]},
            {"$type":"table","columns":["Rang","Score"],"rows":[{"cells":["1","94"]}]}
          ]}}
        """
        let document = try #require(try decodeStep(json).document)
        #expect(document.title == "Classement automatique")
        #expect(document.headers.map(\.name) == ["Source"])
        #expect(document.excerpt?.totalUnits == 412)
        #expect(document.blocks.count == 3)
        #expect(document.blocks[0] == .paragraph(text: "Un paragraphe."))
        #expect(document.blocks[1] == .lines([DocumentLine(text: "boot", marker: "Info", label: "08:03"), DocumentLine(text: "nu")]))
        #expect(document.blocks[2] == .table(columns: ["Rang", "Score"], rows: [DocumentTableRow(cells: ["1", "94"])]))
    }

    /// Un `$type` inconnu occupe toujours son rang — seule identité qu'un bloc possède —
    /// et les blocs connus qui l'entourent se rendent quand même.
    @Test func anUnknownBlockTypeIsKeptInPlaceAndIgnoredAtRender() throws {
        let json = """
        {"nodeId":"n1","text":"t","status":"AwaitingInput","choices":[],"turn":0,"kind":"Document","document":{
          "title":"T","nature":"Memo","blocks":[
            {"$type":"paragraph","text":"avant"},
            {"$type":"chart","series":[1,2,3]},
            {"$type":"paragraph","text":"après"}
          ]}}
        """
        let document = try #require(try decodeStep(json).document)
        #expect(document.blocks.count == 3)
        #expect(document.blocks[1] == .unsupported(type: "chart"))
        #expect(document.blocks[0] == .paragraph(text: "avant"))
        #expect(document.blocks[2] == .paragraph(text: "après"))
        #expect(DocumentPresentation.blockKey(document.blocks[2], index: 2) == "2-paragraph")
    }

    /// La nature, le marqueur et l'unité sont `X | string` au contrat : les décoder en
    /// énumération fermée ferait échouer tout le document sur une valeur ajoutée.
    @Test func openStringFieldsNeverBreakDecoding() throws {
        let json = """
        {"nodeId":"n1","text":"t","status":"AwaitingInput","choices":[],"turn":0,"kind":"Document","document":{
          "title":"T","nature":"Ordonnance","excerpt":{"shownUnits":2,"totalUnits":9,"unit":"Octets"},
          "blocks":[{"$type":"lines","lines":[{"text":"x","marker":"Deprecated"}]}]}}
        """
        let document = try #require(try decodeStep(json).document)
        #expect(document.nature == "Ordonnance")
        #expect(document.excerpt?.unit == "Octets")
        #expect(DocumentPresentation.natureLabel(document.nature) == "Document")
        let excerpt = try #require(document.excerpt)
        #expect(DocumentPresentation.excerptSentence(excerpt) == "2 éléments affichés sur 9")
    }

    /// Un bloc dont la charge utile est malformée ne doit pas emporter le document.
    @Test func aMalformedBlockPayloadDegradesAlone() throws {
        let json = """
        {"nodeId":"n1","text":"t","status":"AwaitingInput","choices":[],"turn":0,"kind":"Document","document":{
          "title":"T","nature":"Log","blocks":[{"$type":"table","columns":"pas-un-tableau"},{"$type":"paragraph","text":"lisible"}]}}
        """
        let document = try #require(try decodeStep(json).document)
        #expect(document.blocks[0] == .unsupported(type: "table"))
        #expect(document.blocks[1] == .paragraph(text: "lisible"))
    }
}
