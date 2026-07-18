import CoreGraphics
import Foundation

enum PlayerExperiencePresentation {
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
