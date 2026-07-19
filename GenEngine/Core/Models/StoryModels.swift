import Foundation

struct StorySummary: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let eyebrow: String
    let synopsis: String
    let duration: String
    let symbol: String
    let accent: StoryAccent
    let availability: Availability
    var scenarioID: UUID? = nil

    enum Availability: Hashable, Sendable { case demo, published(UUID), comingSoon }
}

extension StorySummary {
    init(published story: PublishedScenarioView) {
        self.init(
            id: story.versionId.uuidString.lowercased(),
            title: story.title,
            eyebrow: "Version \(story.versionNumber)",
            synopsis: story.description,
            duration: "\(story.estimatedMinutes) min",
            symbol: story.versionNumber.isMultiple(of: 2) ? "moon.stars.fill" : "book.pages.fill",
            accent: story.versionNumber.isMultiple(of: 2) ? .violet : .verdigris,
            availability: .published(story.versionId),
            scenarioID: story.scenarioId)
    }
}

enum StoryCatalog {
    static func unique(_ stories: [StorySummary]) -> [StorySummary] {
        var scenarioIDs = Set<UUID>()
        var normalizedTitles = Set<String>()

        return stories.filter { story in
            let title = story.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let scenarioID = story.scenarioID, !scenarioIDs.insert(scenarioID).inserted { return false }
            guard normalizedTitles.insert(title).inserted else { return false }
            return true
        }
    }
}

enum StoryAccent: Hashable, Sendable { case ember, verdigris, violet }

struct DemoNode: Equatable, Sendable {
    let id: String
    let text: String
    let choices: [DemoChoice]
    var interaction: DemoInteraction? = nil
    var isEnding: Bool { choices.isEmpty }
}

struct DemoInteraction: Equatable, Sendable { let label: String; let hint: String; let symbol: String }

struct DemoChoice: Identifiable, Equatable, Sendable { let id: String; let text: String; let target: String }

enum DemoStory {
    static let summary = StorySummary(id: "embers-below", title: "Les braises sous la brume", eyebrow: "Une aventure GenEngine", synopsis: "Au bord d’une cité noyée, une lueur impossible répond à votre nom.", duration: "15 min", symbol: "sparkles", accent: .ember, availability: .demo)
    static let library: [StorySummary] = [
        summary,
        StorySummary(id: "verdant-signal", title: "Le signal verdoyant", eyebrow: "Bientôt", synopsis: "Une station botanique s’éveille après cent ans de silence.", duration: "12 min", symbol: "leaf.fill", accent: .verdigris, availability: .comingSoon),
        StorySummary(id: "last-orbit", title: "La dernière orbite", eyebrow: "Bientôt", synopsis: "Il reste un message à transmettre avant que le ciel ne s’éteigne.", duration: "15 min", symbol: "moon.stars.fill", accent: .violet, availability: .comingSoon)
    ]
    static let openingNodeID = "shore"
    static func node(id: String) -> DemoNode? { nodes[id] }

    /// Parcours déterministe de la fixture, dans l'ordre de découverte depuis la scène d'ouverture.
    static var orderedNodes: [DemoNode] {
        var visited = Set<String>()
        var queue = [openingNodeID]
        var head = 0
        var result: [DemoNode] = []
        while head < queue.count {
            let id = queue[head]
            head += 1
            guard visited.insert(id).inserted, let node = nodes[id] else { continue }
            result.append(node)
            queue.append(contentsOf: node.choices.map(\.target))
        }
        return result
    }

    /// Projette la fixture hors ligne dans la forme de contrat `NarrativeTree` afin que la
    /// démonstration et une session serveur partagent la même vue de graphe.
    /// Cette projection reste dans la frontière de démonstration et ne sert jamais de repli silencieux.
    static func narrativeTree(path: [String]) -> NarrativeTree {
        let visited = Set(path)
        let current = path.last ?? ""
        let nodes = orderedNodes.map { node in
            NarrativeTreeNode(
                id: node.id,
                text: node.text,
                isEnding: node.isEnding,
                state: node.id == current ? "Current" : (visited.contains(node.id) ? "Visited" : "Unexplored"))
        }
        let edges = orderedNodes.flatMap { node in
            node.choices.map { choice in
                NarrativeTreeEdge(
                    sourceNodeId: node.id,
                    targetNodeId: choice.target,
                    inputId: choice.id,
                    text: choice.text,
                    isAvailable: true,
                    evaluation: ConditionEvaluation(operator: "None", result: true, explanation: "Aucune condition dans la démonstration.", children: []))
            }
        }
        return NarrativeTree(initialNodeId: openingNodeID, currentNodeId: current, nodes: nodes, edges: edges)
    }

    private static let nodes: [String: DemoNode] = [
        "shore": DemoNode(id: "shore", text: "La brume glisse sur les marches de basalte. Sous l’eau noire, une braise pulse au rythme de votre souffle. Lueur, votre familier, murmure que la cité vient de prononcer votre nom.", choices: [DemoChoice(id: "descend", text: "Descendre vers la lumière", target: "stairs"), DemoChoice(id: "listen", text: "Écouter le chant de la brume", target: "echo")], interaction: .init(label: "Accorder la lanterne", hint: "Touchez la lueur jusqu’à ce que le phare vous réponde.", symbol: "hand.tap.fill")),
        "stairs": DemoNode(id: "stairs", text: "Chaque marche rallume un souvenir qui n’est pas le vôtre : une fête, une trahison, une enfant cachant une clé d’ambre. Plus bas, deux portes portent les emblèmes du Phare et des Archives.", choices: [DemoChoice(id: "archives", text: "Suivre l’emblème des Archives", target: "archives"), DemoChoice(id: "beacon", text: "Chercher le Phare englouti", target: "beacon")]),
        "echo": DemoNode(id: "echo", text: "La voix sous l’eau récite les noms des disparus. Le dernier est celui de votre mère. Entre deux vagues, elle vous avertit : la braise conserve les souvenirs, mais exige toujours un échange.", choices: [DemoChoice(id: "promise", text: "Promettre de restaurer la mémoire", target: "ferryman"), DemoChoice(id: "question", text: "Demander quel souvenir sera pris", target: "archives")]),
        "archives": DemoNode(id: "archives", text: "Les rayonnages respirent comme un animal endormi. Trois livres s’ouvrent seuls : la fondation de la cité, la nuit de sa chute, et une page encore blanche portant la date d’aujourd’hui.", choices: [DemoChoice(id: "fall", text: "Lire la nuit de la chute", target: "truth"), DemoChoice(id: "blank", text: "Écrire votre nom sur la page blanche", target: "mark")], interaction: .init(label: "Révéler l’encre", hint: "Déplacez le sceau sur la page pour débloquer les dialogues cachés.", symbol: "seal.fill")),
        "beacon": DemoNode(id: "beacon", text: "Le mécanisme du phare tourne encore sous les eaux. Il manque un prisme. Lueur peut prendre sa forme, mais cette transformation effacerait une partie de sa personnalité actuelle.", choices: [DemoChoice(id: "ask", text: "Laisser Lueur choisir", target: "companion"), DemoChoice(id: "search", text: "Refuser le sacrifice et fouiller l’atelier", target: "workshop")]),
        "ferryman": DemoNode(id: "ferryman", text: "Un passeur sans visage vous attend dans une barque de verre. Il réclame un souvenir heureux pour traverser. Vous pouvez aussi lui offrir la peur qui vous accompagne depuis l’enfance.", choices: [DemoChoice(id: "joy", text: "Offrir un souvenir heureux", target: "truth"), DemoChoice(id: "fear", text: "Abandonner votre ancienne peur", target: "workshop")]),
        "truth": DemoNode(id: "truth", text: "La cité n’a pas été noyée par un ennemi. Ses habitants ont choisi de l’effacer pour emprisonner une histoire capable de réécrire toutes les autres. Votre famille gardait la serrure.", choices: [DemoChoice(id: "seal", text: "Préparer un nouveau sceau", target: "convergence"), DemoChoice(id: "free", text: "Décider que toute histoire mérite d’être libre", target: "convergence")]),
        "mark": DemoNode(id: "mark", text: "L’encre traverse votre peau et dessine une carte lumineuse. La page révèle deux futurs : dans l’un la cité renaît, dans l’autre elle reste cachée mais protège le monde.", choices: [DemoChoice(id: "rebirth", text: "Suivre le futur de la renaissance", target: "convergence"), DemoChoice(id: "guard", text: "Choisir de protéger le secret", target: "convergence")]),
        "companion": DemoNode(id: "companion", text: "Lueur refuse de disparaître pour obéir, mais propose de partager le coût. Une nouvelle forme naît : ni étincelle, ni oiseau, mais une constellation minuscule qui conserve toutes ses voix.", choices: [DemoChoice(id: "together", text: "Allumer le phare ensemble", target: "convergence")]),
        "workshop": DemoNode(id: "workshop", text: "Dans l’atelier, vous reconstituez le prisme avec les fragments laissés par les anciens gardiens. Chacun réagit à une intention différente : vérité, compassion ou courage.", choices: [DemoChoice(id: "truth-prism", text: "Accorder le prisme à la vérité", target: "convergence"), DemoChoice(id: "care-prism", text: "L’accorder à la compassion", target: "convergence")]),
        "convergence": DemoNode(id: "convergence", text: "Au sommet du phare, les décisions prises depuis la rive reviennent comme des constellations. La braise vous demande enfin non pas ce que vous voulez sauver, mais ce que vous acceptez de transmettre.", choices: [DemoChoice(id: "share", text: "Rendre les souvenirs à tous", target: "dawn"), DemoChoice(id: "protect", text: "Devenir gardien du récit interdit", target: "watch")]),
        "dawn": DemoNode(id: "dawn", text: "La lanterne s’ouvre comme une fleur. Les toits émergent, les cloches répondent au soleil et chaque habitant retrouve un souvenir sans perdre le droit d’en créer de nouveaux. Lueur inscrit votre choix dans le premier chapitre de la cité restaurée.", choices: []),
        "watch": DemoNode(id: "watch", text: "La cité demeure sous la brume, invisible mais vivante. Vous rallumez le phare une nuit par an pour ceux qui cherchent une histoire perdue. À vos côtés, Lueur apprend à reconnaître les voyageurs prêts à entendre la vérité.", choices: [])
    ]
}
