import CoreGraphics
import Foundation

enum PlayerExperiencePresentation {
    /// Les six postures de la configuration de référence « Le Diapason ».
    static let diapasonPostures = ["Lucidité", "Discernement", "Arbitrage", "Courage", "Transmission", "Autonomie"]

    /// Titre du bilan de démonstration, selon la nature de la fin atteinte.
    static func demoOutcomeTitle(_ outcome: DemoOutcome?) -> String {
        switch outcome {
        case .accord: "Vous avez tenu la posture, et vous savez pourquoi."
        case .partielle: "Le résultat est là ; le raisonnement ne l’est pas."
        case .rupture: "La situation ne peut plus être rattrapée."
        case nil: "Chemin accompli"
        }
    }

    static func demoOutcomeNote(_ outcome: DemoOutcome?) -> String {
        switch outcome {
        case .accord: "Le résultat est bon et le raisonnement est consolidé : ce que vous avez avancé était vérifiable par quelqu’un d’autre que vous."
        case .partielle: "Vous avez eu raison sans rendre votre raison opposable. Une reprise sur le même chemin change l’issue à moindre coût."
        case .rupture: "Le moteur ne connaît pas d’échec : c’est la conséquence, dans le monde, qui ferme la porte. Il n’y a pas de reprise en cours de route — la scène se rejoue depuis le début."
        case nil: "La démo s’arrête ici : votre histoire ne repart pas en boucle."
        }
    }

    static func demoFrequencyLabel(_ outcome: DemoOutcome?) -> String {
        switch outcome {
        case .rupture: "Aucune fréquence : la démarche n’a pas été rendue explicite."
        case .partielle: "Fréquence du doute, non consolidée : le fait manquait à l’intuition."
        default: "Fréquence du doute : vous avez suspendu une conclusion trop fluide."
        }
    }

    /// Postures traversées, déduites des choix réellement disponibles sur le chemin parcouru.
    static func demoPostures(_ path: [String]) -> [String] {
        var seen: [String] = []
        for id in path {
            guard let node = DemoStory.node(id: id) else { continue }
            for posture in node.choices.map(\.posture) where !seen.contains(posture) && diapasonPostures.contains(posture) {
                seen.append(posture)
            }
        }
        // Le nœud d'accueil propose les trois situations : ne rien retenir de lui
        // si le joueur n'est pas encore entré dans l'une d'elles.
        return path.count > 1 ? seen.filter { posture in
            path.dropFirst().contains { DemoStory.node(id: $0)?.choices.contains { $0.posture == posture } ?? false }
        } : []
    }

    static let worldMapSize = CGSize(width: 1536, height: 1024)
    static let doorAnchors = [
        CGPoint(x: 850, y: 280), CGPoint(x: 1230, y: 400), CGPoint(x: 390, y: 330),
        CGPoint(x: 380, y: 680), CGPoint(x: 1070, y: 760)
    ]
    static let compactDoorAnchors = [
        CGPoint(x: 850, y: 280), CGPoint(x: 770, y: 570), CGPoint(x: 1070, y: 760),
        CGPoint(x: 620, y: 410), CGPoint(x: 930, y: 440)
    ]

    static func doorAnchors(for viewport: CGSize) -> [CGPoint] {
        viewport.width < viewport.height ? compactDoorAnchors : doorAnchors
    }

    static func projectMapPoint(_ point: CGPoint, into viewport: CGSize) -> CGPoint {
        let scale = max(viewport.width / worldMapSize.width, viewport.height / worldMapSize.height)
        return CGPoint(
            x: (viewport.width - worldMapSize.width * scale) / 2 + point.x * scale,
            y: (viewport.height - worldMapSize.height * scale) / 2 + point.y * scale)
    }

    static func journalTypeLabel(_ value: String) -> String {
        [
            "ChoiceSelected": "Choix effectué",
            "NarrationContinued": "Récit poursuivi",
            "QuizAnswered": "Question résolue",
            "TextSubmitted": "Réponse écrite",
            "ScenarioCompleted": "Histoire terminée"
        ][value] ?? value.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
    }

    static func familiarOptionLabel(_ value: String) -> String {
        [
            "spark": "Étincelle", "owl": "Chouette", "fox": "Renard",
            "Warm": "Chaleureux", "Playful": "Joueur", "Direct": "Direct", "Mysterious": "Mystérieux"
        ][value] ?? value
    }

    static func uniqueJournalEntries(_ entries: [PlayerJournalEntryView]) -> [PlayerJournalEntryView] {
        var seen = Set<String>()
        return entries.filter { entry in
            let key = [entry.type, entry.sessionId?.uuidString, entry.referenceId, entry.scenarioVersionId?.uuidString, entry.title, entry.summary, entry.occurredAt.ISO8601Format()]
                .map { ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    static func uniqueMasteries(_ masteries: [ScenarioMasteryView]) -> [ScenarioMasteryView] {
        var byVersion: [UUID: ScenarioMasteryView] = [:]
        for mastery in masteries where byVersion[mastery.scenarioVersionId].map({ mastery.updatedAt > $0.updatedAt }) ?? true {
            byVersion[mastery.scenarioVersionId] = mastery
        }
        return Array(byVersion.values).sorted { $0.updatedAt > $1.updatedAt }
    }
}
