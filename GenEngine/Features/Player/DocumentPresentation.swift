import Foundation

/// Présentation d'un document consultable (schéma de scénario v6).
///
/// Le moteur envoie une structure — nature, en-têtes, blocs, aveu d'échantillonnage —
/// et le client la rend telle quelle : une table en table, un diff en diff, un journal
/// en journal. Rien n'est reformulé, rien n'est complété, et surtout rien n'est
/// arrondi : l'échantillon s'annonce.
///
/// Ce type ne dépend pas de SwiftUI : c'est ce qui le rend testable sans rendu.
enum DocumentPresentation {

    // MARK: - Nature

    /// Libellé humain d'une nature. Une nature imprévue reste nommée « Document ».
    static func natureLabel(_ nature: String) -> String {
        switch nature {
        case "Memo": "Note de service"
        case "Email": "Courriel"
        case "Code": "Extrait de code"
        case "Diff": "Correctif"
        case "Log": "Journal applicatif"
        case "Table": "Table de données"
        case "Conversation": "Conversation"
        case "Report": "Rapport"
        default: "Document"
        }
    }

    // MARK: - Famille de rendu

    /// Elle dérive de la nature *et* des blocs reçus, parce que la nature nomme ce que
    /// le document **est** tandis que les blocs disent comment il se dessine : un
    /// `Report` fait de lignes marquées se lit comme un journal.
    enum Layout: Equatable, Sendable { case prose, table, diff, log, code, conversation }

    static func layout(for document: ConsultableDocument) -> Layout {
        switch document.nature {
        case "Table": return .table
        case "Diff": return .diff
        case "Log": return .log
        case "Code": return .code
        case "Conversation": return .conversation
        case "Memo", "Email", "Report": return .prose
        default:
            if document.blocks.contains(where: { if case .table = $0 { true } else { false } }) { return .table }
            if document.blocks.contains(where: { if case .lines = $0 { true } else { false } }) { return .log }
            return .prose
        }
    }

    // MARK: - Marqueurs de ligne

    /// Libellé d'un marqueur de ligne, et son symbole de gouttière.
    ///
    /// Le libellé n'est pas décoratif : c'est lui qui porte l'information pour un
    /// lecteur d'écran, la gouttière et la couleur ne devant jamais la porter seules.
    struct Marker: Equatable, Sendable {
        let label: String
        let gutter: String
    }

    static func markerPresentation(_ marker: String?) -> Marker? {
        guard let marker, !marker.isEmpty else { return nil }
        switch marker {
        case "Added": return Marker(label: "Ajouté", gutter: "+")
        case "Removed": return Marker(label: "Retiré", gutter: "−")
        case "Context": return Marker(label: "Contexte", gutter: " ")
        case "Warning": return Marker(label: "Avertissement", gutter: "!")
        case "Error": return Marker(label: "Erreur", gutter: "×")
        case "Info": return Marker(label: "Information", gutter: "·")
        // Un marqueur inconnu est **montré tel quel** plutôt qu'effacé : le scénario
        // lui a donné un sens que le client n'a pas à trancher.
        default: return Marker(label: marker, gutter: "·")
        }
    }

    /// Une ligne est-elle une continuation visuelle (`Context`) plutôt qu'un changement ?
    static func isNeutralLine(_ line: DocumentLine) -> Bool {
        guard let marker = line.marker, !marker.isEmpty else { return true }
        return marker == "Context"
    }

    // MARK: - Aveu d'échantillonnage

    /// Unités d'échantillon, avec leur genre.
    ///
    /// Le genre n'est pas décoratif : il accorde le participe de la phrase
    /// d'échantillon. Sans lui, on lit « 4 paragraphes affichées sur 27 », et une faute
    /// d'accord dans la seule phrase qui demande d'être crue affaiblit exactement ce
    /// qu'elle affirme.
    private struct Unit { let singular: String; let plural: String; let feminine: Bool }

    /// Une unité inconnue reste nommable plutôt que de faire échouer la phrase.
    private static let unknownUnit = Unit(singular: "élément", plural: "éléments", feminine: false)

    private static func unit(_ name: String) -> Unit {
        switch name {
        case "Lines": Unit(singular: "ligne", plural: "lignes", feminine: true)
        case "Rows": Unit(singular: "ligne", plural: "lignes", feminine: true)
        case "Messages": Unit(singular: "message", plural: "messages", feminine: false)
        case "Entries": Unit(singular: "entrée", plural: "entrées", feminine: true)
        case "Paragraphs": Unit(singular: "paragraphe", plural: "paragraphes", feminine: false)
        default: unknownUnit
        }
    }

    /// Unité d'échantillon au pluriel français, telle qu'elle se lit dans la phrase.
    static func excerptUnitLabel(_ name: String, count: Int) -> String {
        let unit = unit(name)
        return count > 1 ? unit.plural : unit.singular
    }

    /// Groupement des milliers à la française.
    ///
    /// Le séparateur est posé explicitement (espace fine insécable, U+202F) plutôt que
    /// délégué à `Locale` : la locale de l'appareil n'est pas forcément française, et le
    /// séparateur d'ICU pour `fr_FR` a déjà changé d'une version à l'autre. La phrase
    /// d'échantillon doit se lire pareil partout.
    static func groupedNumber(_ value: Int) -> String {
        let digits = String(abs(value))
        var grouped = ""
        for (index, digit) in digits.reversed().enumerated() {
            if index > 0, index.isMultiple(of: 3) { grouped.append("\u{202F}") }
            grouped.append(digit)
        }
        return (value < 0 ? "-" : "") + String(grouped.reversed())
    }

    /// L'aveu d'échantillonnage, en toutes lettres.
    ///
    /// « 6 lignes affichées sur 412 », jamais « 6 lignes ». Le moteur garantit
    /// `shownUnits < totalUnits`, donc cette phrase retranche toujours quelque chose ;
    /// présenter l'échantillon comme un tout serait un mensonge d'interface, et c'est
    /// précisément ce sur quoi le jeu porte.
    static func excerptSentence(_ excerpt: DocumentExcerpt) -> String {
        let unit = unit(excerpt.unit)
        let participle = "affiché" + (unit.feminine ? "e" : "") + (excerpt.shownUnits > 1 ? "s" : "")
        let noun = excerptUnitLabel(excerpt.unit, count: excerpt.shownUnits)
        return "\(groupedNumber(excerpt.shownUnits)) \(noun) \(participle) sur \(groupedNumber(excerpt.totalUnits))"
    }

    /// Part visible du document, entre 0 et 100, pour la jauge d'échantillon.
    ///
    /// Le plancher à 1 % n'est pas cosmétique : 6 sur 412 arrondit à 0, et une jauge
    /// vide se lit comme « rien n'est montré » alors que six lignes le sont.
    static func excerptPercent(_ excerpt: DocumentExcerpt) -> Int {
        guard excerpt.totalUnits > 0 else { return 0 }
        let ratio = Double(excerpt.shownUnits) / Double(excerpt.totalUnits) * 100
        return max(1, Int(ratio.rounded()))
    }

    // MARK: - Identité des blocs

    /// Clé de rendu stable d'un bloc. Les blocs n'ont pas d'identifiant : leur rang dans
    /// la liste est leur seule identité, et il est stable puisque le document appartient
    /// à un snapshot publié.
    static func blockKey(_ block: DocumentBlock, index: Int) -> String {
        "\(index)-\(block.typeName)"
    }
}
