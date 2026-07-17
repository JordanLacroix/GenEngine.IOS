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
            availability: .published(story.versionId))
    }
}

enum StoryAccent: Hashable, Sendable { case ember, verdigris, violet }

struct DemoNode: Equatable, Sendable {
    let id: String
    let text: String
    let choices: [DemoChoice]
    var isEnding: Bool { choices.isEmpty }
}

struct DemoChoice: Identifiable, Equatable, Sendable { let id: String; let text: String; let target: String }

enum DemoStory {
    static let summary = StorySummary(id: "embers-below", title: "Les braises sous la brume", eyebrow: "Une aventure GenEngine", synopsis: "Au bord d’une cité noyée, une lueur impossible répond à votre nom.", duration: "8 min", symbol: "sparkles", accent: .ember, availability: .demo)
    static let library: [StorySummary] = [
        summary,
        StorySummary(id: "verdant-signal", title: "Le signal verdoyant", eyebrow: "Bientôt", synopsis: "Une station botanique s’éveille après cent ans de silence.", duration: "12 min", symbol: "leaf.fill", accent: .verdigris, availability: .comingSoon),
        StorySummary(id: "last-orbit", title: "La dernière orbite", eyebrow: "Bientôt", synopsis: "Il reste un message à transmettre avant que le ciel ne s’éteigne.", duration: "15 min", symbol: "moon.stars.fill", accent: .violet, availability: .comingSoon)
    ]
    static let openingNodeID = "shore"
    static func node(id: String) -> DemoNode? { nodes[id] }

    private static let nodes: [String: DemoNode] = [
        "shore": DemoNode(id: "shore", text: "La brume glisse sur les marches de basalte. Sous l’eau noire, une braise pulse au rythme de votre souffle — puis une voix prononce votre nom.", choices: [DemoChoice(id: "descend", text: "Descendre vers la lumière", target: "vault"), DemoChoice(id: "listen", text: "Rester immobile et écouter", target: "echo")]),
        "vault": DemoNode(id: "vault", text: "Chaque marche rallume un souvenir qui n’est pas le vôtre. Au fond du sanctuaire, une lanterne attend dans une main de pierre.", choices: [DemoChoice(id: "take", text: "Prendre la lanterne", target: "dawn"), DemoChoice(id: "refuse", text: "Éteindre la braise", target: "silence")]),
        "echo": DemoNode(id: "echo", text: "La cité ne vous appelle pas. Elle vous reconnaît. Dans le silence, vous comprenez que la lumière garde la dernière histoire de votre lignée.", choices: [DemoChoice(id: "answer", text: "Répondre à la cité", target: "dawn"), DemoChoice(id: "leave", text: "Repartir avant l’aube", target: "silence")]),
        "dawn": DemoNode(id: "dawn", text: "La lanterne s’ouvre comme une fleur. Pour la première fois depuis un siècle, l’aube trouve un chemin jusqu’à la cité engloutie.", choices: []),
        "silence": DemoNode(id: "silence", text: "La braise disparaît, mais sa chaleur demeure dans votre paume. Certaines histoires savent attendre leur prochain lecteur.", choices: [])
    ]
}
