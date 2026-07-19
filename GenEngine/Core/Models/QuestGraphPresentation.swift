import Foundation

/// État d'une scène dans le graphe de quête, dérivé du contrat serveur et de la mémoire cumulée.
enum QuestNodeState: String, Equatable, Sendable, CaseIterable {
    case current
    case takenThisRun
    case discoveredBefore
    case locked
    case unseen
}

/// État d'un chemin entre deux scènes.
enum QuestEdgeState: String, Equatable, Sendable, CaseIterable {
    case takenThisRun
    case discoveredBefore
    case unavailable
}

struct QuestGraphNode: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let isEnding: Bool
    let state: QuestNodeState
    let rank: Int
    let x: Double
    let y: Double
}

struct QuestGraphEdge: Identifiable, Equatable, Sendable {
    let sourceNodeId: String
    let targetNodeId: String
    let inputId: String
    let text: String
    let state: QuestEdgeState
    let isAvailable: Bool
    let explanation: String
    let isRemembered: Bool
    let sourceX: Double
    let sourceY: Double
    let targetX: Double
    let targetY: Double

    var id: String { "\(sourceNodeId)→\(targetNodeId)#\(inputId)" }
}

struct QuestGraph: Equatable, Sendable {
    let nodes: [QuestGraphNode]
    let edges: [QuestGraphEdge]
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double

    var isEmpty: Bool { nodes.isEmpty }
    var width: Double { maxX - minX }
    var height: Double { maxY - minY }

    func count(of state: QuestNodeState) -> Int { nodes.count { $0.state == state } }

    /// Part de scènes connues (parcourues maintenant ou découvertes lors d'une partie précédente).
    var knownRatio: Double {
        guard !nodes.isEmpty else { return 0 }
        let known = nodes.count { $0.state == .current || $0.state == .takenThisRun || $0.state == .discoveredBefore }
        return Double(known) / Double(nodes.count)
    }
}

/// Projection pure et déterministe d'une topologie narrative en graphe présentable.
/// Aucune règle narrative n'est recalculée ici : les états viennent du serveur,
/// seule la mise en page et la fusion avec la mémoire cumulée sont dérivées.
///
/// Deux contrats alimentent la même projection :
/// - `NarrativeTree` en partie, qui porte les états de scène et l'évaluation des conditions ;
/// - `ScenarioStructure` hors partie, qui n'en porte aucun. Un adaptateur explicite les
///   convertit vers la même forme interne, de sorte qu'une seule mise en page existe.
enum QuestGraphPresentation {
    /// Au-delà de ce nombre de scènes, l'interface bascule sur la liste textuelle.
    static let renderableNodeLimit = 60

    /// Forme interne neutre : les faits bruts nécessaires à la projection, sans contrat particulier.
    private struct SourceNode {
        let id: String
        let text: String
        let isEnding: Bool
        let isCurrent: Bool
        let isVisitedThisRun: Bool
        let isLocked: Bool
    }

    private struct SourceEdge {
        let sourceNodeId: String
        let targetNodeId: String
        let inputId: String
        let text: String
        let isAvailable: Bool
        let explanation: String
    }

    private struct Source {
        let initialNodeId: String
        let nodes: [SourceNode]
        let edges: [SourceEdge]
    }

    // MARK: - Adaptateurs de contrat

    /// Projection d'une partie en cours : les états de scène et les conditions viennent du serveur.
    static func build(tree: NarrativeTree, masteryNodeIds: Set<String> = [], masteryChoiceIds: Set<String> = []) -> QuestGraph {
        let source = Source(
            initialNodeId: tree.initialNodeId,
            nodes: tree.nodes.map { node in
                let serverState = node.state.lowercased()
                return SourceNode(
                    id: node.id,
                    text: node.text,
                    isEnding: node.isEnding,
                    isCurrent: node.id == tree.currentNodeId,
                    isVisitedThisRun: serverState == "visited",
                    isLocked: serverState == "locked")
            },
            edges: tree.edges.map {
                SourceEdge(
                    sourceNodeId: $0.sourceNodeId,
                    targetNodeId: $0.targetNodeId,
                    inputId: $0.inputId,
                    text: $0.text,
                    isAvailable: $0.isAvailable,
                    explanation: $0.evaluation.explanation)
            })
        return build(source: source, masteryNodeIds: masteryNodeIds, masteryChoiceIds: masteryChoiceIds)
    }

    /// Projection hors partie : la structure ne publie aucun état de monde. Chaque scène est
    /// donc soit `discoveredBefore` si la mémoire la contient, soit `unseen`. Il n'y a ni scène
    /// courante, ni passage de la partie en cours, et rien n'est déclaré verrouillé : une
    /// condition ne peut pas être évaluée sans état de monde.
    static func build(structure: ScenarioStructure, masteryNodeIds: Set<String> = [], masteryChoiceIds: Set<String> = []) -> QuestGraph {
        let source = Source(
            initialNodeId: structure.initialNodeId,
            nodes: structure.nodes.map {
                SourceNode(id: $0.id, text: $0.text, isEnding: $0.isEnding, isCurrent: false, isVisitedThisRun: false, isLocked: false)
            },
            edges: structure.edges.map {
                SourceEdge(sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId, inputId: $0.inputId, text: $0.text, isAvailable: true, explanation: "")
            })
        return build(source: source, masteryNodeIds: masteryNodeIds, masteryChoiceIds: masteryChoiceIds)
    }

    // MARK: - Projection unique

    private static func build(source: Source, masteryNodeIds: Set<String>, masteryChoiceIds: Set<String>) -> QuestGraph {
        var seen = Set<String>()
        let uniqueNodes = source.nodes.filter { seen.insert($0.id).inserted }
        let ranks = ranks(source: source, nodes: uniqueNodes)
        let positions = positions(nodes: uniqueNodes, ranks: ranks)
        let nodes = uniqueNodes.map { node -> QuestGraphNode in
            let position = positions[node.id] ?? .init(rank: 0, x: 0, y: 0)
            return QuestGraphNode(
                id: node.id,
                text: node.text,
                isEnding: node.isEnding,
                state: state(for: node, masteryNodeIds: masteryNodeIds),
                rank: position.rank,
                x: position.x,
                y: position.y)
        }

        let statesById = Dictionary(nodes.map { ($0.id, $0.state) }, uniquingKeysWith: { first, _ in first })
        let positionsById = Dictionary(nodes.map { ($0.id, ($0.x, $0.y)) }, uniquingKeysWith: { first, _ in first })

        let edges = source.edges.compactMap { edge -> QuestGraphEdge? in
            guard let source = positionsById[edge.sourceNodeId], let target = positionsById[edge.targetNodeId] else { return nil }
            return QuestGraphEdge(
                sourceNodeId: edge.sourceNodeId,
                targetNodeId: edge.targetNodeId,
                inputId: edge.inputId,
                text: edge.text,
                state: state(for: edge, statesById: statesById),
                isAvailable: edge.isAvailable,
                explanation: edge.explanation,
                isRemembered: masteryChoiceIds.contains(edge.inputId),
                sourceX: source.0,
                sourceY: source.1,
                targetX: target.0,
                targetY: target.1)
        }

        return QuestGraph(
            nodes: nodes,
            edges: edges,
            minX: nodes.map(\.x).min() ?? 0,
            maxX: nodes.map(\.x).max() ?? 0,
            minY: nodes.map(\.y).min() ?? 0,
            maxY: nodes.map(\.y).max() ?? 0)
    }

    // MARK: - États

    private static func state(for node: SourceNode, masteryNodeIds: Set<String>) -> QuestNodeState {
        if node.isCurrent { return .current }
        if node.isVisitedThisRun { return .takenThisRun }
        if masteryNodeIds.contains(node.id) { return .discoveredBefore }
        if node.isLocked { return .locked }
        return .unseen
    }

    private static func state(for edge: SourceEdge, statesById: [String: QuestNodeState]) -> QuestEdgeState {
        guard let source = statesById[edge.sourceNodeId], let target = statesById[edge.targetNodeId] else { return .unavailable }
        let taken: Set<QuestNodeState> = [.current, .takenThisRun]
        if taken.contains(source) && taken.contains(target) { return .takenThisRun }
        let known: Set<QuestNodeState> = [.current, .takenThisRun, .discoveredBefore]
        if known.contains(source) && known.contains(target) { return .discoveredBefore }
        return .unavailable
    }

    // MARK: - Mise en page

    private struct Position { let rank: Int; let x: Double; let y: Double }

    /// Distance BFS depuis la scène initiale ; les scènes inatteignables reçoivent `max + 1`.
    private static func ranks(source: Source, nodes: [SourceNode]) -> [String: Int] {
        var adjacency: [String: [String]] = [:]
        for edge in source.edges { adjacency[edge.sourceNodeId, default: []].append(edge.targetNodeId) }
        let existing = Set(nodes.map(\.id))

        var ranks: [String: Int] = [:]
        if existing.contains(source.initialNodeId) {
            ranks[source.initialNodeId] = 0
            var queue = [source.initialNodeId]
            var head = 0
            while head < queue.count {
                let current = queue[head]
                head += 1
                let next = (ranks[current] ?? 0) + 1
                for neighbour in adjacency[current] ?? [] where existing.contains(neighbour) && ranks[neighbour] == nil {
                    ranks[neighbour] = next
                    queue.append(neighbour)
                }
            }
        }

        let fallback = (ranks.values.max().map { $0 + 1 }) ?? 0
        for node in nodes where ranks[node.id] == nil { ranks[node.id] = fallback }
        return ranks
    }

    /// `x = rank`, `y = index dans le rang - (effectif du rang - 1) / 2`, ordre stable sur `nodes`.
    private static func positions(nodes: [SourceNode], ranks: [String: Int]) -> [String: Position] {
        var byRank: [Int: [String]] = [:]
        for node in nodes { byRank[ranks[node.id] ?? 0, default: []].append(node.id) }

        var positions: [String: Position] = [:]
        for (rank, ids) in byRank {
            let count = Double(ids.count)
            for (index, id) in ids.enumerated() where positions[id] == nil {
                positions[id] = Position(rank: rank, x: Double(rank), y: Double(index) - (count - 1) / 2)
            }
        }
        return positions
    }
}
