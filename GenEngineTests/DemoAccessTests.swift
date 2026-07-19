import Foundation
import Testing
@testable import GenEngine

/// La démonstration appartient à l'état anonyme. Ces tests verrouillent la disparition
/// de tous ses points d'entrée dès qu'un jeton est présent.
@MainActor
struct DemoAccessTests {
    private struct StubVault: TokenStoring {
        let token: String?
        func load() -> String? { token }
        func save(_ token: String) throws {}
        func clear() throws {}
    }

    private func anonymousState() -> AppState { AppState(vault: StubVault(token: nil)) }
    private func authenticatedState() -> AppState { AppState(vault: StubVault(token: "token")) }

    @Test func anonymousVisitorKeepsTheOfflineDemo() {
        let state = anonymousState()
        #expect(state.isDemoAvailable)
        #expect(state.stories.contains { $0.availability == .demo })
        #expect(state.featuredStory?.availability == .demo)
    }

    @Test func authenticatedPlayerLosesTheDemoFromTheCatalog() {
        let state = authenticatedState()
        #expect(state.isDemoAvailable == false)
        #expect(state.stories.contains { $0.availability == .demo } == false)
        #expect(state.featuredStory?.availability != .demo)
    }

    @Test func demoCannotBeUnlockedNorStartedOnceAuthenticated() async {
        let state = authenticatedState()
        state.unlockDemo()
        #expect(state.isDemoAccess == false)
        state.startDemo()
        #expect(state.session == nil)
        await state.open(DemoStory.summary)
        #expect(state.session == nil)
        #expect(state.errorMessage != nil)
    }

    @Test func anonymousVisitorCanStartTheDemoWithoutNetwork() {
        let state = anonymousState()
        state.unlockDemo()
        #expect(state.isDemoAccess)
        #expect(state.hasProductAccess)
        state.startDemo()
        #expect(state.isDemoSession)
        #expect(state.step?.nodeId == DemoStory.openingNodeID)
    }

    @Test func demoMemoryStaysHiddenFromAnAuthenticatedJournal() {
        #expect(authenticatedState().demoQuestGraph == nil)
    }

    /// Le HUD n'expose jamais une destination invalide pour l'état courant.
    @Test func anonymousDestinationsAreLimitedToTheDemoAndSignIn() {
        let state = anonymousState()
        #expect(state.destinations == [.home, .account])
        state.selectedTab = .administration
        #expect(state.activeTab == .home)
    }

    /// Sans permission connue, un joueur authentifié garde au moins bibliothèque et compte.
    @Test func authenticatedDestinationsExcludeTheDemoHome() {
        let state = authenticatedState()
        #expect(state.destinations.contains(.home) == false)
        #expect(state.destinations.contains(.account))
        #expect(state.activeTab == .library)
    }
}
