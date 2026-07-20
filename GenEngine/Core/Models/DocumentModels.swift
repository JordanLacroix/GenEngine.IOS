import Foundation

// MARK: - Documents consultables (schéma de scénario v6)

/// Le contenu est porté par le scénario publié — donc versionné, hashé et rejoué comme
/// le reste. Le client ne va rien chercher et n'invente rien : il rend ce que le moteur
/// envoie, y compris l'aveu d'échantillonnage.
///
/// **Aucun de ces types n'utilise d'énumération fermée sur une valeur servie.** La
/// nature, le marqueur de ligne et l'unité d'échantillon sont déclarés `X | string`
/// côté contrat : le moteur peut en ajouter sans nous prévenir. Ils sont donc décodés
/// en `String` et interprétés à la présentation, où une valeur imprévue dégrade en un
/// libellé neutre au lieu de faire échouer le décodage de toute la session.

struct DocumentHeader: Decodable, Equatable, Sendable {
    let name: String
    let value: String
}

/// Aveu d'échantillonnage. `shownUnits` est **strictement** inférieur à `totalUnits` —
/// le moteur refuse l'égalité, parce qu'une mention qui ne retranche rien ne dirait
/// rien. Un document montré intégralement n'en porte pas, et l'absence du bloc est donc
/// l'information « c'est tout ».
struct DocumentExcerpt: Decodable, Equatable, Sendable {
    let shownUnits: Int
    let totalUnits: Int
    let unit: String
}

struct DocumentLine: Decodable, Equatable, Sendable {
    let text: String
    /// Couvre le diff (`Added`, `Removed`, `Context`) et le journal (`Warning`…).
    let marker: String?
    let label: String?

    init(text: String, marker: String? = nil, label: String? = nil) {
        self.text = text
        self.marker = marker
        self.label = label
    }
}

struct DocumentTableRow: Decodable, Equatable, Sendable {
    let cells: [String]

    init(cells: [String]) { self.cells = cells }
}

/// Bloc de contenu, discriminé par `$type`.
///
/// Un `$type` inconnu — ou un bloc dont la charge utile ne se décode pas — devient
/// `.unsupported`, que la vue ignore silencieusement. Le rang du bloc reste occupé :
/// c'est la seule identité qu'un bloc possède, et la perdre décalerait les clés de
/// rendu de tous les blocs suivants.
enum DocumentBlock: Equatable, Sendable {
    case paragraph(text: String)
    case lines([DocumentLine])
    case table(columns: [String], rows: [DocumentTableRow])
    case unsupported(type: String)

    /// Discriminant tel qu'il a été servi, y compris pour un bloc non rendu.
    var typeName: String {
        switch self {
        case .paragraph: "paragraph"
        case .lines: "lines"
        case .table: "table"
        case .unsupported(let type): type
        }
    }
}

extension DocumentBlock: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case text, lines, columns, rows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? container.decode(String.self, forKey: .type)) ?? ""
        switch type {
        case "paragraph":
            guard let text = try? container.decode(String.self, forKey: .text) else {
                self = .unsupported(type: type)
                return
            }
            self = .paragraph(text: text)
        case "lines":
            guard let lines = try? container.decode([DocumentLine].self, forKey: .lines) else {
                self = .unsupported(type: type)
                return
            }
            self = .lines(lines)
        case "table":
            guard let columns = try? container.decode([String].self, forKey: .columns),
                  let rows = try? container.decode([DocumentTableRow].self, forKey: .rows) else {
                self = .unsupported(type: type)
                return
            }
            self = .table(columns: columns, rows: rows)
        default:
            self = .unsupported(type: type)
        }
    }
}

struct ConsultableDocument: Decodable, Equatable, Sendable {
    let title: String
    let nature: String
    let headers: [DocumentHeader]
    let excerpt: DocumentExcerpt?
    let blocks: [DocumentBlock]

    init(title: String, nature: String, headers: [DocumentHeader] = [], excerpt: DocumentExcerpt? = nil, blocks: [DocumentBlock]) {
        self.title = title
        self.nature = nature
        self.headers = headers
        self.excerpt = excerpt
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey { case title, nature, headers, excerpt, blocks }

    /// Enveloppe qui absorbe l'échec d'un bloc isolé. `DocumentBlock` ne jette
    /// pratiquement jamais, mais un élément qui ne serait même pas un objet JSON ferait
    /// échouer tout le tableau — donc tout le document, donc toute la session.
    private struct TolerantBlock: Decodable {
        let block: DocumentBlock
        init(from decoder: Decoder) throws {
            block = (try? DocumentBlock(from: decoder)) ?? .unsupported(type: "")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        nature = try container.decodeIfPresent(String.self, forKey: .nature) ?? "Other"
        headers = try container.decodeIfPresent([DocumentHeader].self, forKey: .headers) ?? []
        excerpt = try container.decodeIfPresent(DocumentExcerpt.self, forKey: .excerpt)
        blocks = (try container.decodeIfPresent([TolerantBlock].self, forKey: .blocks) ?? []).map(\.block)
    }
}
