import SwiftUI

/// Rendu d'un document consultable (schéma de scénario v6).
///
/// Le document est présenté **avec** les choix de sortie, jamais à leur place :
/// consulter n'est jamais imposé. Cette vue ne porte donc aucune action de sortie —
/// l'appelant garde les `exitChoices` visibles pendant que le document est ouvert.
struct DocumentSheetView: View {
    let document: ConsultableDocument
    let busy: Bool
    let onConsult: () -> Void

    private var layout: DocumentPresentation.Layout { DocumentPresentation.layout(for: document) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { index, block in
                DocumentBlockView(block: block, layout: layout)
                    .id(DocumentPresentation.blockKey(block, index: index))
            }
            // L'aveu d'échantillonnage est un élément du document, pas une note de bas
            // de page : il est rendu dans le cadre, sous le contenu qu'il qualifie.
            if let excerpt = document.excerpt { excerptFooter(excerpt) }
            Button("Consulter ce document", action: onConsult)
                .buttonStyle(PrimaryActionStyle())
                .disabled(busy)
                .accessibilityHint("Consulter consomme un tour de jeu")
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: 720)
        .glassPanel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document : \(document.title)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(DocumentPresentation.natureLabel(document.nature), systemImage: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GenEngineTheme.amber)
            Text(document.title)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(GenEngineTheme.ivory)
                .accessibilityAddTraits(.isHeader)
            ForEach(document.headers, id: \.name) { entry in
                // Le couple nom/valeur est lu d'un seul tenant : « Source : … » plutôt
                // que deux éléments qu'un lecteur d'écran parcourrait séparément.
                (Text(entry.name + " : ").font(.caption.weight(.semibold)) + Text(entry.value).font(.caption))
                    .foregroundStyle(GenEngineTheme.secondaryText)
                    .accessibilityLabel("\(entry.name) : \(entry.value)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func excerptFooter(_ excerpt: DocumentExcerpt) -> some View {
        let sentence = DocumentPresentation.excerptSentence(excerpt)
        let percent = DocumentPresentation.excerptPercent(excerpt)
        return VStack(alignment: .leading, spacing: 6) {
            Label(sentence, systemImage: "scanner")
                .font(.caption.weight(.medium))
                .foregroundStyle(GenEngineTheme.amber)
            // La jauge ne fait que doubler la phrase ; elle est donc décorative, et la
            // phrase reste la seule porteuse de l'information.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(GenEngineTheme.ivory.opacity(0.14))
                    Capsule().fill(GenEngineTheme.amber)
                        .frame(width: max(2, proxy.size.width * Double(percent) / 100))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sentence)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Un bloc de `$type` inconnu ne rend rien et n'interrompt pas la liste : le reste du
/// document reste lisible.
private struct DocumentBlockView: View {
    let block: DocumentBlock
    let layout: DocumentPresentation.Layout

    var body: some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(.body, design: layout == .code ? .monospaced : .default))
                .foregroundStyle(GenEngineTheme.ivory)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .lines(let lines):
            DocumentLinesView(lines: lines)
        case .table(let columns, let rows):
            DocumentTableView(columns: columns, rows: rows)
        case .unsupported:
            EmptyView()
        }
    }
}

/// Lignes marquées : diff, journal applicatif, extrait de code.
///
/// La gouttière (`+`, `−`, `!`) et la couleur sont **décoratives** : le marqueur est
/// aussi énoncé en toutes lettres dans le libellé d'accessibilité, de sorte qu'aucune
/// information ne repose sur la seule couleur ni sur le seul symbole.
private struct DocumentLinesView: View {
    let lines: [DocumentLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let marker = DocumentPresentation.markerPresentation(line.marker)
                HStack(alignment: .top, spacing: 8) {
                    Text(marker?.gutter ?? " ")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(tint(for: line))
                        .frame(width: 14, alignment: .center)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        if let label = line.label, !label.isEmpty {
                            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(GenEngineTheme.secondaryText)
                        }
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GenEngineTheme.ivory)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(tint(for: line).opacity(DocumentPresentation.isNeutralLine(line) ? 0 : 0.12), in: RoundedRectangle(cornerRadius: 4))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(line: line, marker: marker, index: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accessibilityLabel(line: DocumentLine, marker: DocumentPresentation.Marker?, index: Int) -> String {
        var parts = ["Ligne \(index + 1)"]
        if let marker { parts.append(marker.label) }
        if let label = line.label, !label.isEmpty { parts.append(label) }
        parts.append(line.text)
        return parts.joined(separator: ", ")
    }

    private func tint(for line: DocumentLine) -> Color {
        switch line.marker {
        case "Added": GenEngineTheme.verdigris
        case "Removed", "Error": GenEngineTheme.ember
        case "Warning": GenEngineTheme.amber
        default: GenEngineTheme.secondaryText
        }
    }
}

/// Table de données.
///
/// Le moteur garantit que chaque rangée a l'arité des colonnes
/// (`document_row_arity_mismatch` au refus), donc aucune règle de remplissage n'est
/// inventée ici. La table défile dans son propre conteneur : le corps de l'écran ne
/// défile jamais horizontalement.
private struct DocumentTableView: View {
    let columns: [String]
    let rows: [DocumentTableRow]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        Text(column)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GenEngineTheme.amber)
                            .frame(width: 140, alignment: .leading)
                            .padding(8)
                    }
                }
                .background(GenEngineTheme.ivory.opacity(0.06))
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption)
                                .foregroundStyle(GenEngineTheme.ivory)
                                .frame(width: 140, alignment: .leading)
                                .padding(8)
                        }
                    }
                    .background(index.isMultiple(of: 2) ? Color.clear : GenEngineTheme.ivory.opacity(0.03))
                    // Une rangée est lue en entier, colonne par colonne : sans cela un
                    // lecteur d'écran énonce des cellules sans jamais dire de quoi.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(rowLabel(row, index: index))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table de \(rows.count) rangées et \(columns.count) colonnes")
    }

    private func rowLabel(_ row: DocumentTableRow, index: Int) -> String {
        let pairs = zip(columns, row.cells).map { "\($0) : \($1)" }
        return "Rangée \(index + 1), " + pairs.joined(separator: ", ")
    }
}
