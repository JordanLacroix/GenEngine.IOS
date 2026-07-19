import Foundation
import Testing
@testable import GenEngine

private func node(_ id: String, state: String, isEnding: Bool = false) -> NarrativeTreeNode {
    NarrativeTreeNode(id: id, text: "Scène \(id)", isEnding: isEnding, state: state)
}

private func edge(_ source: String, _ target: String, input: String = "go", isAvailable: Bool = true, explanation: String = "") -> NarrativeTreeEdge {
    NarrativeTreeEdge(
        sourceNodeId: source,
        targetNodeId: target,
        inputId: input,
        text: "\(source) vers \(target)",
        isAvailable: isAvailable,
        evaluation: ConditionEvaluation(operator: "None", result: isAvailable, explanation: explanation, children: []))
}

struct QuestGraphPresentationTests {
    /// a → b → d, a → c → d : graphe orienté avec convergence.
    private let convergingTree = NarrativeTree(
        initialNodeId: "a",
        currentNodeId: "b",
        nodes: [node("a", state: "Visited"), node("b", state: "Current"), node("c", state: "Unexplored"), node("d", state: "Unexplored", isEnding: true)],
        edges: [edge("a", "b", input: "left"), edge("a", "c", input: "right"), edge("b", "d", input: "down"), edge("c", "d", input: "up")])

    @Test func nodeStatePrecedenceFollowsTheContract() {
        let tree = NarrativeTree(
            initialNodeId: "a",
            currentNodeId: "a",
            nodes: [
                node("a", state: "Visited"),
                node("b", state: "Visited"),
                node("c", state: "Unexplored"),
                node("d", state: "Locked"),
                node("e", state: "Unexplored")
            ],
            edges: [])

        let graph = QuestGraphPresentation.build(tree: tree, masteryNodeIds: ["a", "b", "c", "d"])
        let states = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.state) })

        #expect(states["a"] == .current, "la scène courante prime sur la mémoire et sur l’état serveur")
        #expect(states["b"] == .takenThisRun, "un passage de la partie en cours prime sur la mémoire")
        #expect(states["c"] == .discoveredBefore, "la mémoire prime sur Unexplored")
        #expect(states["d"] == .discoveredBefore, "la mémoire prime sur Locked")
        #expect(states["e"] == .unseen)
    }

    @Test func lockedNodeStaysLockedWithoutMastery() {
        let tree = NarrativeTree(initialNodeId: "a", currentNodeId: "a", nodes: [node("a", state: "Current"), node("z", state: "Locked")], edges: [edge("a", "z", isAvailable: false, explanation: "Clé manquante.")])
        let graph = QuestGraphPresentation.build(tree: tree)

        #expect(graph.nodes.first { $0.id == "z" }?.state == .locked)
        #expect(graph.edges.first?.state == .unavailable)
        #expect(graph.edges.first?.isAvailable == false)
        #expect(graph.edges.first?.explanation == "Clé manquante.")
    }

    @Test func masteryUnionProducesDiscoveredBeforeEdges() {
        let graph = QuestGraphPresentation.build(tree: convergingTree, masteryNodeIds: ["c", "d"], masteryChoiceIds: ["right"])
        let states = Dictionary(uniqueKeysWithValues: graph.edges.map { ($0.id, $0.state) })

        #expect(states["a→b#left"] == .takenThisRun, "deux extrémités parcourues cette fois")
        #expect(states["a→c#right"] == .discoveredBefore, "extrémités connues mais pas toutes parcourues cette fois")
        #expect(states["c→d#up"] == .discoveredBefore)
        #expect(states["b→d#down"] == .discoveredBefore, "b est courant et d est mémorisé")
        #expect(graph.edges.first { $0.inputId == "right" }?.isRemembered == true)
        #expect(graph.edges.first { $0.inputId == "up" }?.isRemembered == false)
    }

    @Test func edgeIsUnavailableWhenAnEndpointIsUnknown() {
        let graph = QuestGraphPresentation.build(tree: convergingTree)

        #expect(graph.edges.first { $0.inputId == "right" }?.state == .unavailable)
        #expect(graph.edges.first { $0.inputId == "left" }?.state == .takenThisRun)
    }

    @Test func ranksFollowShortestDistanceOnAConvergingGraph() {
        let graph = QuestGraphPresentation.build(tree: convergingTree)
        let ranks = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.rank) })

        #expect(ranks == ["a": 0, "b": 1, "c": 1, "d": 2])
        #expect(graph.nodes.count == 4, "une convergence ne duplique ni ne perd de scène")
        #expect(graph.nodes.map(\.x) == graph.nodes.map { Double($0.rank) })
    }

    @Test func cyclesDoNotLoopAndKeepTheShortestRank() {
        let tree = NarrativeTree(
            initialNodeId: "a",
            currentNodeId: "a",
            nodes: [node("a", state: "Current"), node("b", state: "Unexplored"), node("c", state: "Unexplored")],
            edges: [edge("a", "b"), edge("b", "c"), edge("c", "a"), edge("c", "b")])

        let graph = QuestGraphPresentation.build(tree: tree)
        let ranks = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.rank) })

        #expect(ranks == ["a": 0, "b": 1, "c": 2])
    }

    @Test func orderingWithinARankIsStableAndCentred() {
        let tree = NarrativeTree(
            initialNodeId: "a",
            currentNodeId: "a",
            nodes: [node("a", state: "Current"), node("x", state: "Unexplored"), node("y", state: "Unexplored"), node("z", state: "Unexplored")],
            edges: [edge("a", "x", input: "1"), edge("a", "y", input: "2"), edge("a", "z", input: "3")])

        let graph = QuestGraphPresentation.build(tree: tree)
        let positions = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.y) })

        #expect(positions["x"] == -1)
        #expect(positions["y"] == 0)
        #expect(positions["z"] == 1)
        #expect(graph.nodes.first { $0.id == "a" }?.y == 0, "un rang unique est centré sur zéro")
        #expect(graph.minY == -1)
        #expect(graph.maxY == 1)
    }

    @Test func unreachableNodesLandBehindTheLastRank() {
        let tree = NarrativeTree(
            initialNodeId: "a",
            currentNodeId: "a",
            nodes: [node("a", state: "Current"), node("b", state: "Unexplored"), node("orphan", state: "Unexplored")],
            edges: [edge("a", "b")])

        let graph = QuestGraphPresentation.build(tree: tree)

        #expect(graph.nodes.first { $0.id == "orphan" }?.rank == 2)
        #expect(graph.maxX == 2)
    }

    @Test func degenerateInputsProduceAnEmptyOrSingletonGraph() {
        let empty = QuestGraphPresentation.build(tree: NarrativeTree(initialNodeId: "a", currentNodeId: "a", nodes: [], edges: []))
        #expect(empty.isEmpty)
        #expect(empty.knownRatio == 0)

        let missingInitial = QuestGraphPresentation.build(tree: NarrativeTree(initialNodeId: "ghost", currentNodeId: "ghost", nodes: [node("a", state: "Unexplored")], edges: []))
        #expect(missingInitial.nodes.first?.rank == 0, "sans racine atteignable, tout retombe au rang zéro")

        let danglingEdge = QuestGraphPresentation.build(tree: NarrativeTree(initialNodeId: "a", currentNodeId: "a", nodes: [node("a", state: "Current")], edges: [edge("a", "nowhere")]))
        #expect(danglingEdge.edges.isEmpty, "une arête vers une scène absente est ignorée")

        let duplicated = QuestGraphPresentation.build(tree: NarrativeTree(initialNodeId: "a", currentNodeId: "a", nodes: [node("a", state: "Current"), node("a", state: "Visited")], edges: []))
        #expect(duplicated.nodes.count == 1)
    }

    @Test func knownRatioCountsCurrentRunAndMemory() {
        let graph = QuestGraphPresentation.build(tree: convergingTree, masteryNodeIds: ["c"])
        #expect(graph.count(of: .current) == 1)
        #expect(graph.count(of: .takenThisRun) == 1)
        #expect(graph.count(of: .discoveredBefore) == 1)
        #expect(graph.count(of: .unseen) == 1)
        #expect(graph.knownRatio == 0.75)
    }

    @Test func demoFixtureProjectsIntoTheSameNarrativeTreeShape() {
        let tree = DemoStory.narrativeTree(path: ["shore", "stairs"])

        #expect(tree.initialNodeId == DemoStory.openingNodeID)
        #expect(tree.currentNodeId == "stairs")
        #expect(tree.nodes.count == 13)
        #expect(tree.nodes.first { $0.id == "shore" }?.state == "Visited")
        #expect(tree.nodes.first { $0.id == "stairs" }?.state == "Current")
        #expect(tree.nodes.first { $0.id == "dawn" }?.state == "Unexplored")
        #expect(tree.nodes.first { $0.id == "dawn" }?.isEnding == true)
        #expect(tree.edges.filter { !$0.isAvailable }.isEmpty)
        #expect(Set(tree.nodes.map(\.id)).count == 13, "la projection ne duplique aucune scène")

        let graph = QuestGraphPresentation.build(tree: tree, masteryNodeIds: ["echo"], masteryChoiceIds: ["listen"])
        #expect(graph.nodes.first { $0.id == "stairs" }?.rank == 1)
        #expect(graph.nodes.first { $0.id == "convergence" }?.rank == 4, "shore → stairs → archives → truth → convergence")
        #expect(graph.nodes.first { $0.id == "dawn" }?.rank == 5)
        #expect(graph.nodes.first { $0.id == "echo" }?.state == .discoveredBefore)
        #expect(graph.nodes.count == 13)
    }

    // MARK: - Structure publiée, hors partie

    /// Même topologie que `convergingTree`, mais sans aucun état de monde.
    private let convergingStructure = ScenarioStructure(
        initialNodeId: "a",
        nodes: [
            ScenarioStructureNode(id: "a", text: "Scène a", isEnding: false),
            ScenarioStructureNode(id: "b", text: "Scène b", isEnding: false),
            ScenarioStructureNode(id: "c", text: "Scène c", isEnding: false),
            ScenarioStructureNode(id: "d", text: "Scène d", isEnding: true)
        ],
        edges: [
            ScenarioStructureEdge(sourceNodeId: "a", targetNodeId: "b", inputId: "left", text: "a vers b"),
            ScenarioStructureEdge(sourceNodeId: "a", targetNodeId: "c", inputId: "right", text: "a vers c"),
            ScenarioStructureEdge(sourceNodeId: "b", targetNodeId: "d", inputId: "down", text: "b vers d"),
            ScenarioStructureEdge(sourceNodeId: "c", targetNodeId: "d", inputId: "up", text: "c vers d")
        ])

    @Test func statelessStructureSplitsNodesBetweenMemoryAndUnknown() {
        let graph = QuestGraphPresentation.build(structure: convergingStructure, masteryNodeIds: ["a", "c"], masteryChoiceIds: ["right"])
        let states = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.state) })

        #expect(states["a"] == .discoveredBefore, "la mémoire cumulée est la seule source de couleur hors partie")
        #expect(states["c"] == .discoveredBefore)
        #expect(states["b"] == .unseen)
        #expect(states["d"] == .unseen)
        #expect(graph.count(of: .current) == 0, "hors partie, aucune scène n’est courante")
        #expect(graph.count(of: .takenThisRun) == 0, "hors partie, aucun passage n’appartient à la partie en cours")
        #expect(graph.count(of: .locked) == 0, "sans état de monde, aucune condition n’est évaluable")
        #expect(graph.knownRatio == 0.5)
    }

    @Test func statelessEdgesFollowMemoryAndCarryNoEvaluation() {
        let graph = QuestGraphPresentation.build(structure: convergingStructure, masteryNodeIds: ["a", "c"], masteryChoiceIds: ["right"])
        let states = Dictionary(uniqueKeysWithValues: graph.edges.map { ($0.id, $0.state) })

        #expect(states["a→c#right"] == .discoveredBefore, "les deux extrémités sont mémorisées")
        #expect(states["a→b#left"] == .unavailable, "une extrémité inconnue ne peut pas être déclarée connue")
        let explanations = Set(graph.edges.map(\.explanation))
        let availabilities = Set(graph.edges.map(\.isAvailable))
        #expect(explanations == [""], "la structure ne publie aucune évaluation de condition")
        #expect(availabilities == [true], "aucun chemin n’est déclaré verrouillé hors partie")
        #expect(graph.edges.first { $0.inputId == "right" }?.isRemembered == true)
        #expect(graph.edges.first { $0.inputId == "up" }?.isRemembered == false)
    }

    /// La carte hors partie et la carte en partie doivent se superposer scène pour scène.
    @Test func statelessLayoutIsIdenticalToTheInRunLayout() {
        let inRun = QuestGraphPresentation.build(tree: convergingTree)
        let outOfRun = QuestGraphPresentation.build(structure: convergingStructure)

        #expect(outOfRun.nodes.map(\.id) == inRun.nodes.map(\.id))
        #expect(outOfRun.nodes.map(\.rank) == inRun.nodes.map(\.rank))
        #expect(outOfRun.nodes.map(\.x) == inRun.nodes.map(\.x))
        #expect(outOfRun.nodes.map(\.y) == inRun.nodes.map(\.y))
        #expect(outOfRun.nodes.map(\.isEnding) == inRun.nodes.map(\.isEnding))
        #expect(outOfRun.edges.map(\.id) == inRun.edges.map(\.id))
        #expect(outOfRun.edges.map(\.sourceX) == inRun.edges.map(\.sourceX))
        #expect(outOfRun.edges.map(\.sourceY) == inRun.edges.map(\.sourceY))
        #expect(outOfRun.edges.map(\.targetX) == inRun.edges.map(\.targetX))
        #expect(outOfRun.edges.map(\.targetY) == inRun.edges.map(\.targetY))
        #expect(outOfRun.minX == inRun.minX)
        #expect(outOfRun.maxX == inRun.maxX)
        #expect(outOfRun.minY == inRun.minY)
        #expect(outOfRun.maxY == inRun.maxY)
    }

    @Test func statelessProjectionKeepsDegenerateCasesAndIsDeterministic() {
        let empty = QuestGraphPresentation.build(structure: ScenarioStructure(initialNodeId: "a", nodes: [], edges: []))
        #expect(empty.isEmpty)

        let dangling = QuestGraphPresentation.build(structure: ScenarioStructure(
            initialNodeId: "a",
            nodes: [ScenarioStructureNode(id: "a", text: "Scène a", isEnding: false)],
            edges: [ScenarioStructureEdge(sourceNodeId: "a", targetNodeId: "nowhere", inputId: "go", text: "vers nulle part")]))
        #expect(dangling.edges.isEmpty, "une arête vers une scène absente est ignorée")

        #expect(QuestGraphPresentation.build(structure: convergingStructure) == QuestGraphPresentation.build(structure: convergingStructure))
    }

    @Test func demoProjectionIsDeterministic() {
        #expect(DemoStory.narrativeTree(path: ["shore"]) == DemoStory.narrativeTree(path: ["shore"]))
        #expect(DemoStory.orderedNodes.first?.id == DemoStory.openingNodeID)
        #expect(DemoStory.narrativeTree(path: []).currentNodeId.isEmpty, "hors partie, aucune scène n’est courante")
    }
}
