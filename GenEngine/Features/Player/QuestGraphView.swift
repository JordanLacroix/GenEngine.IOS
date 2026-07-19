import SwiftUI

/// Carte de mémoire de quête : le graphe complet du scénario, ce qui a été parcouru
/// pendant la partie en cours et ce qui reste connu des parties précédentes.
struct QuestGraphView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let graph: QuestGraph
    var title = "Mémoire de quête"
    var subtitle: String?
    @State private var showsDetails = false

    private var isDrawable: Bool {
        !graph.isEmpty && graph.nodes.count <= QuestGraphPresentation.renderableNodeLimit && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if isDrawable {
                drawing
            } else if !graph.isEmpty {
                Text(oversizeNotice)
                    .font(.caption)
                    .foregroundStyle(GenEngineTheme.secondaryText)
            }
            legend
            DisclosureGroup(isExpanded: $showsDetails) {
                details
            } label: {
                Text("Détail des scènes et des chemins")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GenEngineTheme.ivory)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .tint(GenEngineTheme.amber)
        }
        .padding(20)
        .frame(maxWidth: 720, alignment: .leading)
        .glassPanel()
    }

    private var oversizeNotice: String {
        graph.nodes.count > QuestGraphPresentation.renderableNodeLimit
            ? "Ce scénario compte \(graph.nodes.count) scènes : le tracé est remplacé par la liste ci-dessous."
            : "Le tracé est remplacé par la liste ci-dessous pour rester lisible à cette taille de texte."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: title, color: GenEngineTheme.amber)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }
            Text(summary)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(GenEngineTheme.ivory)
            ProgressView(value: graph.knownRatio)
                .tint(GenEngineTheme.verdigris)
                .accessibilityLabel("Part du scénario connue")
                .accessibilityValue("\(Int((graph.knownRatio * 100).rounded())) pour cent")
        }
    }

    private var summary: String {
        "\(graph.count(of: .takenThisRun) + graph.count(of: .current)) scène(s) parcourue(s) cette fois · \(graph.count(of: .discoveredBefore)) déjà connue(s) · \(graph.count(of: .unseen) + graph.count(of: .locked)) à découvrir"
    }

    // MARK: - Tracé

    private var drawing: some View {
        let columns = max(graph.width + 1, 1)
        let rows = max(graph.height + 1, 1)
        let cell = CGSize(width: 116, height: 74)
        let canvasSize = CGSize(width: columns * cell.width, height: max(rows * cell.height, cell.height))

        return ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Canvas { context, size in draw(in: &context, size: size) }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(canvasSize.height + 16, 360))
        .accessibilityElement()
        .accessibilityLabel("Carte du scénario")
        .accessibilityValue(summary)
        .accessibilityHint("Le détail scène par scène est disponible juste en dessous.")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let radius: CGFloat = 13
        func point(x: Double, y: Double) -> CGPoint {
            let columns = max(graph.width, 0)
            let rows = max(graph.height, 0)
            let stepX = columns == 0 ? 0 : (size.width - radius * 4) / columns
            let stepY = rows == 0 ? 0 : (size.height - radius * 4) / rows
            return CGPoint(
                x: radius * 2 + (x - graph.minX) * stepX + (columns == 0 ? (size.width - radius * 4) / 2 : 0),
                y: radius * 2 + (y - graph.minY) * stepY + (rows == 0 ? (size.height - radius * 4) / 2 : 0))
        }

        for edge in graph.edges {
            let start = point(x: edge.sourceX, y: edge.sourceY)
            let end = point(x: edge.targetX, y: edge.targetY)
            var path = Path()
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: (start.x + end.x) / 2, y: start.y),
                control2: CGPoint(x: (start.x + end.x) / 2, y: end.y))
            context.stroke(
                path,
                with: .color(color(for: edge.state)),
                style: StrokeStyle(
                    lineWidth: edge.state == .takenThisRun ? 3 : 1.6,
                    lineCap: .round,
                    dash: edge.isAvailable ? [] : [4, 4]))
        }

        for node in graph.nodes {
            let center = point(x: node.x, y: node.y)
            let tint = color(for: node.state)
            let box = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let shape = node.isEnding
                ? Path(roundedRect: box, cornerRadius: 4)
                : Path(ellipseIn: box)
            switch node.state {
            case .current, .takenThisRun:
                context.fill(shape, with: .color(tint))
            case .discoveredBefore:
                context.fill(shape, with: .color(tint.opacity(0.35)))
                context.stroke(shape, with: .color(tint), lineWidth: 2)
            case .locked, .unseen:
                context.stroke(shape, with: .color(tint), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            if node.state == .current {
                let halo = Path(ellipseIn: box.insetBy(dx: -6, dy: -6))
                context.stroke(halo, with: .color(tint.opacity(reduceMotion ? 0.9 : 0.6)), lineWidth: 2)
            }
        }
    }

    // MARK: - Légende et détail

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 8) { legendItems }
        }
    }

    @ViewBuilder
    private var legendItems: some View {
        ForEach(QuestNodeState.allCases, id: \.self) { state in
            Label {
                Text(label(for: state)).font(.caption)
            } icon: {
                Circle().fill(color(for: state)).frame(width: 9, height: 9)
            }
            .foregroundStyle(GenEngineTheme.secondaryText)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(graph.nodes) { node in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: symbol(for: node.state)).foregroundStyle(color(for: node.state))
                        Text(label(for: node.state)).font(.caption.weight(.semibold)).foregroundStyle(color(for: node.state))
                        Spacer()
                        if node.isEnding { Text("Fin").font(.caption2).foregroundStyle(GenEngineTheme.amber) }
                    }
                    Text(node.state == .unseen ? "Scène non découverte" : node.text)
                        .font(.footnote)
                        .foregroundStyle(GenEngineTheme.ivory)
                        .lineLimit(3)
                    ForEach(graph.edges.filter { $0.sourceNodeId == node.id }) { edge in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(edge.text, systemImage: edge.isAvailable ? "arrow.turn.down.right" : "lock.fill")
                                .font(.caption)
                                .foregroundStyle(color(for: edge.state))
                            if !edge.isAvailable && !edge.explanation.isEmpty {
                                Text(edge.explanation).font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
                            }
                            if edge.isRemembered && edge.state != .takenThisRun {
                                Text("Déjà emprunté lors d’une partie précédente.").font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
                            }
                        }
                        .padding(.leading, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 10)
    }

    private func label(for state: QuestNodeState) -> String {
        switch state {
        case .current: "Position actuelle"
        case .takenThisRun: "Parcourue cette fois"
        case .discoveredBefore: "Déjà découverte"
        case .locked: "Verrouillée"
        case .unseen: "Jamais atteinte"
        }
    }

    private func symbol(for state: QuestNodeState) -> String {
        switch state {
        case .current: "location.fill"
        case .takenThisRun: "checkmark.circle.fill"
        case .discoveredBefore: "clock.arrow.circlepath"
        case .locked: "lock.fill"
        case .unseen: "circle.dotted"
        }
    }

    private func color(for state: QuestNodeState) -> Color {
        switch state {
        case .current: GenEngineTheme.ember
        case .takenThisRun: GenEngineTheme.verdigris
        case .discoveredBefore: GenEngineTheme.violet
        case .locked: GenEngineTheme.secondaryText
        case .unseen: GenEngineTheme.amber.opacity(0.75)
        }
    }

    private func color(for state: QuestEdgeState) -> Color {
        switch state {
        case .takenThisRun: GenEngineTheme.verdigris
        case .discoveredBefore: GenEngineTheme.violet.opacity(0.8)
        case .unavailable: GenEngineTheme.ivory.opacity(0.22)
        }
    }
}
