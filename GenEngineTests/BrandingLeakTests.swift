import Foundation
import Testing
@testable import GenEngine

/// Le nom du **moteur** ne doit pas apparaître là où l'utilisateur attend le nom de **sa**
/// configuration.
///
/// La distinction tenue ici : « GenEngine » reste légitime dans une mention technique
/// destinée à l'exploitant — schéma d'URL `genengine://auth`, clés de stockage, identifiant
/// de paquet, provenance d'un asset. Il ne l'est pas dans une phrase lue par un joueur ou
/// par un administrateur qui pilote sa propre instance.
@MainActor
struct BrandingLeakTests {
    private struct StubVault: TokenStoring {
        let token: String?
        func load() -> String? { token }
        func save(_ token: String) throws {}
        func clear() throws {}
    }

    /// Le dernier repli du nom affiché, quand le moteur n'a pas encore répondu. Il lit le
    /// nom livré dans le paquet, et ce nom ne doit pas être celui du moteur.
    @Test func theCompiledFallbackIsNotTheEngineName() {
        #expect(AppState.bundleDisplayName.isEmpty == false)
        #expect(AppState.bundleDisplayName != "GenEngine")
    }

    /// Sans amorce cliente — moteur injoignable au tout premier lancement — le nom affiché
    /// retombe sur le paquet, jamais sur « GenEngine ».
    @Test func theDisplayedNameNeverFallsBackToTheEngineName() {
        let state = AppState(vault: StubVault(token: nil))
        #expect(state.gameName != "GenEngine")
        #expect(state.gameName == AppState.bundleDisplayName)
    }

    // Que le nom **servi** prime sur ce repli est déjà verrouillé par
    // `ClientBootstrapTests.decodesTheServedBootstrap` et par l'ordre de résolution de
    // `AppState.gameName` ; ce fichier ne couvre que le repli lui-même, qui est le seul
    // endroit où « GenEngine » pouvait encore fuir sans qu'aucun test ne le voie.
}
