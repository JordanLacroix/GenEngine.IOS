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
    /// nom livré dans le paquet — jamais un littéral de configuration.
    ///
    /// Le paquet porte délibérément le nom du **moteur** : le binaire est GenEngine, et
    /// « Le Diapason » est une configuration servie à l'exécution. Une instance cliente
    /// redéfinit `CFBundleDisplayName` en recompilant avec sa propre marque ; c'est le
    /// seul moment où ce nom peut changer, puisqu'il est figé à la compilation.
    ///
    /// Ce que le test verrouille est donc la **provenance**, pas la valeur : le repli lit
    /// le paquet, il n'invente pas et ne code en dur aucun nom de configuration.
    @Test func theCompiledFallbackReadsTheBundleAndNotAConfigurationLiteral() {
        #expect(AppState.bundleDisplayName.isEmpty == false)
        let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        #expect(AppState.bundleDisplayName == bundleName)
        #expect(AppState.bundleDisplayName != "Le Diapason")
    }

    /// Sans amorce cliente — moteur injoignable au tout premier lancement — le nom affiché
    /// retombe sur celui du paquet, et sur rien d'autre.
    @Test func theDisplayedNameFallsBackToTheBundleName() {
        let state = AppState(vault: StubVault(token: nil))
        #expect(state.gameName == AppState.bundleDisplayName)
    }

    // Que le nom **servi** prime sur ce repli est déjà verrouillé par
    // `ClientBootstrapTests.decodesTheServedBootstrap` et par l'ordre de résolution de
    // `AppState.gameName`. C'est cette priorité qui empêche réellement la fuite : dès que
    // le moteur répond, l'utilisateur lit le nom de sa configuration partout dans
    // l'interface, et le nom du paquet ne subsiste que sous l'icône de l'appareil.
}
