import Foundation
import Testing
@testable import GenEngine

struct DemoStoryTests {
    @Test func everyChoiceTargetsAnExistingNode() {
        var visited = Set<String>()
        var pending = [DemoStory.openingNodeID]
        while let id = pending.popLast() {
            guard visited.insert(id).inserted else { continue }
            let node = DemoStory.node(id: id)
            #expect(node != nil)
            pending.append(contentsOf: node?.choices.map(\.target) ?? [])
        }
        #expect(visited.count == 5)
    }

    @Test(arguments: [("\"AwaitingInput\"", SessionStatus.awaitingInput), ("2", SessionStatus.completed)])
    func sessionStatusAcceptsStringAndNumericContracts(json: String, expected: SessionStatus) throws {
        let decoded = try JSONDecoder().decode(SessionStatus.self, from: Data(json.utf8))
        #expect(decoded == expected)
    }

    @Test func publishedContractMapsToPlayableStory() {
        let versionID = UUID()
        let published = PublishedScenarioView(
            scenarioId: UUID(),
            versionId: versionID,
            versionNumber: 3,
            title: "Le récit publié",
            description: "Une ouverture venue du moteur.",
            estimatedMinutes: 9,
            publishedAt: .now,
            snapshotHash: "hash")

        let story = StorySummary(published: published)

        #expect(story.id == versionID.uuidString.lowercased())
        #expect(story.title == "Le récit publié")
        #expect(story.duration == "9 min")
        #expect(story.availability == .published(versionID))
    }
}
