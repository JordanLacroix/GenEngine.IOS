import Foundation
import Testing
@testable import GenEngine

/// Présentation d'un document consultable (schéma de scénario v6).
///
/// La fixture reprend la charge utile réellement servie par
/// `GET /sessions/{id}/current-step` sur « Le tri des candidatures », relevée côté
/// client Web. Une fixture inventée ne prouverait rien du contrat.
struct DocumentPresentationTests {
    private let rankingDocument = ConsultableDocument(
        title: "Classement automatique — 412 candidatures, 12 postes",
        nature: "Table",
        headers: [DocumentHeader(name: "Source", value: "Outil de présélection, exécution du lundi 08:03")],
        excerpt: DocumentExcerpt(shownUnits: 6, totalUnits: 412, unit: "Rows"),
        blocks: [
            .table(columns: ["Rang", "Dossier", "Score", "Explication produite par l'outil"],
                   rows: [DocumentTableRow(cells: ["1", "C-0148", "94", "Parcours conforme aux profils recrutés"])]),
            .paragraph(text: "L'explication produite par l'outil est une phrase choisie dans une liste de neuf."),
        ])

    private func document(nature: String, blocks: [DocumentBlock]? = nil) -> ConsultableDocument {
        ConsultableDocument(title: rankingDocument.title, nature: nature, headers: rankingDocument.headers,
                            excerpt: rankingDocument.excerpt, blocks: blocks ?? rankingDocument.blocks)
    }

    // MARK: - Nature

    @Test func natureLabelNamesEveryDeclaredNature() {
        #expect(DocumentPresentation.natureLabel("Table") == "Table de données")
        #expect(DocumentPresentation.natureLabel("Diff") == "Correctif")
        #expect(DocumentPresentation.natureLabel("Log") == "Journal applicatif")
    }

    /// `Other` garde la taxonomie ouverte : une nature ajoutée côté moteur ne doit pas
    /// casser le rendu d'un client déjà déployé.
    @Test func natureLabelStaysNeutralForAnUnexpectedNature() {
        #expect(DocumentPresentation.natureLabel("Other") == "Document")
        #expect(DocumentPresentation.natureLabel("Ordonnance") == "Document")
    }

    // MARK: - Famille de rendu

    @Test func layoutRendersATableAsATable() {
        #expect(DocumentPresentation.layout(for: rankingDocument) == .table)
    }

    @Test func layoutDistinguishesDiffFromLog() {
        #expect(DocumentPresentation.layout(for: document(nature: "Diff")) == .diff)
        #expect(DocumentPresentation.layout(for: document(nature: "Log")) == .log)
    }

    /// La nature nomme ce que le document *est* ; les blocs disent comment il se
    /// dessine. Une nature inconnue portant une table se rend donc en table.
    @Test func layoutFallsBackToTheBlocksWhenTheNatureDoesNotSayIt() {
        #expect(DocumentPresentation.layout(for: document(nature: "Inconnue")) == .table)
        #expect(DocumentPresentation.layout(for: document(nature: "Inconnue", blocks: [.lines([DocumentLine(text: "démarrage", marker: "Info")])])) == .log)
        #expect(DocumentPresentation.layout(for: document(nature: "Inconnue", blocks: [.paragraph(text: "Bonjour.")])) == .prose)
    }

    // MARK: - Aveu d'échantillonnage

    /// « 6 lignes sur 412 » : un échantillon présenté comme un tout serait un mensonge
    /// d'interface, et le jeu porte sur la lucidité face à l'information. C'est la
    /// garantie la plus importante de ce module.
    @Test func excerptSentenceStatesTheSamplingInFullWords() {
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 6, totalUnits: 412, unit: "Rows")) == "6 lignes affichées sur 412")
    }

    /// Le séparateur de milliers est l'espace fine insécable (U+202F), convention
    /// française, et non une espace ordinaire.
    @Test func excerptSentenceGroupsThousandsTheFrenchWay() {
        let sentence = DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 4, totalUnits: 27_000, unit: "Paragraphs"))
        #expect(sentence == "4 paragraphes affichés sur 27\u{202F}000")
    }

    /// Relevé à l'écran côté Web sur « La note de service » : le rendu disait
    /// « 4 paragraphes affichées sur 27 ». Une faute d'accord dans la seule phrase qui
    /// demande d'être crue affaiblit ce qu'elle affirme.
    @Test func excerptSentenceAgreesTheParticipleWithTheGenderOfTheUnit() {
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 4, totalUnits: 27, unit: "Paragraphs")) == "4 paragraphes affichés sur 27")
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 9, totalUnits: 1_348, unit: "Entries")) == "9 entrées affichées sur 1\u{202F}348")
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 3, totalUnits: 40, unit: "Messages")) == "3 messages affichés sur 40")
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 2, totalUnits: 9, unit: "Octets")) == "2 éléments affichés sur 9")
    }

    @Test func excerptSentenceAgreesTheSingularToo() {
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 1, totalUnits: 12, unit: "Lines")) == "1 ligne affichée sur 12")
        #expect(DocumentPresentation.excerptSentence(DocumentExcerpt(shownUnits: 1, totalUnits: 12, unit: "Paragraphs")) == "1 paragraphe affiché sur 12")
    }

    @Test func excerptUnitLabelNamesEveryUnitDeclaredByTheEngine() {
        #expect(DocumentPresentation.excerptUnitLabel("Lines", count: 3) == "lignes")
        #expect(DocumentPresentation.excerptUnitLabel("Messages", count: 1) == "message")
        #expect(DocumentPresentation.excerptUnitLabel("Entries", count: 2) == "entrées")
        #expect(DocumentPresentation.excerptUnitLabel("Paragraphs", count: 4) == "paragraphes")
        #expect(DocumentPresentation.excerptUnitLabel("Octets", count: 4) == "éléments")
    }

    /// 6 sur 412 arrondirait à 0 % ; une jauge vide se lit comme « rien n'est montré »
    /// alors que six lignes le sont.
    @Test func excerptPercentStaysVisibleForATinySample() {
        #expect(DocumentPresentation.excerptPercent(DocumentExcerpt(shownUnits: 6, totalUnits: 412, unit: "Rows")) == 1)
        #expect(DocumentPresentation.excerptPercent(DocumentExcerpt(shownUnits: 1, totalUnits: 10_000, unit: "Rows")) == 1)
    }

    @Test func excerptPercentDoesNotDivideByAnAbsentTotal() {
        #expect(DocumentPresentation.excerptPercent(DocumentExcerpt(shownUnits: 0, totalUnits: 0, unit: "Rows")) == 0)
    }

    @Test func excerptPercentReflectsARealShare() {
        #expect(DocumentPresentation.excerptPercent(DocumentExcerpt(shownUnits: 25, totalUnits: 100, unit: "Rows")) == 25)
    }

    // MARK: - Marqueurs

    @Test func markerPresentationCoversDiffAndLogWithTheSameSet() {
        #expect(DocumentPresentation.markerPresentation("Added") == DocumentPresentation.Marker(label: "Ajouté", gutter: "+"))
        #expect(DocumentPresentation.markerPresentation("Removed")?.gutter == "−")
        #expect(DocumentPresentation.markerPresentation("Error")?.label == "Erreur")
    }

    /// Le scénario lui a donné un sens ; l'écarter perdrait de l'information.
    @Test func markerPresentationShowsAnUnknownMarkerRatherThanErasingIt() {
        #expect(DocumentPresentation.markerPresentation("Deprecated")?.label == "Deprecated")
    }

    @Test func markerPresentationShowsNothingForAnUnmarkedLine() {
        #expect(DocumentPresentation.markerPresentation(nil) == nil)
        #expect(DocumentPresentation.markerPresentation("") == nil)
    }

    @Test func isNeutralLineTreatsContextAndAbsenceAsNeutral() {
        #expect(DocumentPresentation.isNeutralLine(DocumentLine(text: "inchangé")))
        #expect(DocumentPresentation.isNeutralLine(DocumentLine(text: "inchangé", marker: "Context")))
        #expect(DocumentPresentation.isNeutralLine(DocumentLine(text: "ajouté", marker: "Added")) == false)
    }

    // MARK: - Identité des blocs

    @Test func blockKeyIdentifiesABlockByItsRank() {
        #expect(DocumentPresentation.blockKey(rankingDocument.blocks[0], index: 0) == "0-table")
        #expect(DocumentPresentation.blockKey(rankingDocument.blocks[1], index: 1) == "1-paragraph")
    }
}
