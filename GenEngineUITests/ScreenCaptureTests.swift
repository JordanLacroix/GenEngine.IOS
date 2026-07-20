import XCTest

/// Harnais de **capture**, pas d'assertion.
///
/// Le dépôt a déjà vu deux correctifs présentés comme vérifiés sans que l'appareil ait été
/// rendu. La cause n'était pas la mauvaise foi : le simulateur ne reçoit pas la frappe
/// clavier — elle est captée comme raccourcis — et `simctl` n'injecte aucune touche. Sans
/// pilotage du bureau, les écrans situés derrière une connexion sont **inatteignables**.
///
/// Un test d'interface, lui, pilote l'application depuis l'intérieur du simulateur. Ce
/// fichier ne vérifie donc presque rien : il navigue et joint une capture par écran, que
/// l'on extrait ensuite du bundle de résultat avec
/// `xcrun xcresulttool export attachments`. C'est un outil de regard, pas un filet de
/// sécurité — un test d'interface vert ne dit rien de la lisibilité d'un écran.
final class ScreenCaptureTests: XCTestCase {
    private let userName = "diapason-admin"
    private let password = "LocalDiapasonPassword!2026"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testCapturesTheScreensTouchedByThisChange() {
        let app = XCUIApplication()
        app.launch()
        // Le simulateur conserve l'orientation de la session précédente : la fixer ici
        // évite de capturer un paysage en croyant regarder un portrait.
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)

        dismissIntroduction(app)
        capture("01-accueil-anonyme")

        captureAnonymousMenuAndServerSettings(app)
        signIn(app)
        captureAdministration(app)
    }

    // MARK: - Étapes

    private func dismissIntroduction(_ app: XCUIApplication) {
        let skip = app.buttons["Passer"]
        if skip.waitForExistence(timeout: 12) {
            skip.tap()
            return
        }
        let enter = app.buttons["Entrer dans le monde"]
        if enter.exists { enter.tap() }
    }

    /// L'accueil anonyme porte la fuite de marque signalée : « les six services qui
    /// servent … », et l'écran de paramètres, jamais observé jusqu'ici.
    private func captureAnonymousMenuAndServerSettings(_ app: XCUIApplication) {
        let menu = app.buttons["Ouvrir le menu"]
        guard menu.waitForExistence(timeout: 10) else {
            capture("02-menu-introuvable")
            return
        }
        menu.tap()
        Thread.sleep(forTimeInterval: 1)
        capture("02-menu-anonyme")

        let settings = app.buttons["Paramètres du serveur"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            Thread.sleep(forTimeInterval: 1.5)
            capture("03-parametres-serveur")
            // Le champ d'hôte est sous le sélecteur de mode : il faut faire défiler le
            // panneau pour l'atteindre.
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.5)
            capture("03b-parametres-serveur-defile")
            tapInfoButton(app, besideFieldContaining: "Hôte", name: "04-parametres-aide-hote")
            let close = app.buttons["Fermer Paramètres du serveur"]
            if close.waitForExistence(timeout: 3) { close.tap() }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    private func signIn(_ app: XCUIApplication) {
        // Referme tout panneau resté ouvert : il recouvrirait le formulaire.
        for _ in 0..<3 {
            let close = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Fermer'")).firstMatch
            guard close.exists, close.isHittable else { break }
            close.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }
        capture("04b-avant-connexion")

        // Une session peut survivre d'une exécution à l'autre : sans ce garde, la frappe
        // partirait dans le premier champ venu — la recherche de la bibliothèque.
        let submitProbe = app.buttons["Se connecter"]
        guard submitProbe.waitForExistence(timeout: 6) else {
            capture("04c-deja-connecte")
            return
        }

        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 10) else { return }
        tapAnyway(field)
        field.typeText(userName)

        let secure = app.secureTextFields.firstMatch
        if secure.waitForExistence(timeout: 5) {
            tapAnyway(secure)
            // Le focus n'est pas acquis dans la même passe d'exécution que la tape :
            // taper trop tôt lève « neither element nor any descendant has keyboard focus ».
            Thread.sleep(forTimeInterval: 1.5)
            if secure.value as? String == "Mot de passe" || (secure.value as? String)?.isEmpty != false {
                tapAnyway(secure)
                Thread.sleep(forTimeInterval: 1.5)
            }
            // `app.typeText` vise l'élément qui détient réellement le focus.
            app.typeText(password)
        }

        let submit = app.buttons["Se connecter"]
        if submit.waitForExistence(timeout: 5) { submit.tap() }
        Thread.sleep(forTimeInterval: 6)
        capture("05-apres-connexion")
    }

    private func captureAdministration(_ app: XCUIApplication) {
        let administration = app.buttons["Administration"]
        guard administration.waitForExistence(timeout: 15) else {
            capture("06-administration-inatteignable")
            return
        }
        administration.tap()
        Thread.sleep(forTimeInterval: 6)
        capture("06-administration-jeu")

        // Le bouton ⓘ est volontairement retiré de l'arbre d'accessibilité : la description
        // est portée par le champ lui-même. Il est donc invisible pour la requête
        // d'élément et ne peut être atteint qu'en coordonnées — ce qui est exactement la
        // preuve que le contrat d'accessibilité voulu est en place.
        tapInfoButton(app, besideFieldContaining: "Nom du jeu", name: "07-aide-nom-du-jeu")

        // Le sélecteur de section est un défilement horizontal : une entrée peut exister
        // hors du viewport. On la saute plutôt que d'échouer — c'est un harnais de capture.
        for section in ["Accueil & aide", "Familiers", "Économie"] {
            let button = app.buttons[section]
            guard button.waitForExistence(timeout: 4), button.isHittable else { continue }
            button.tap()
            Thread.sleep(forTimeInterval: 3)
            capture("08-administration-\(section)")
        }

        // Le paysage est l'orientation où la densité coûte le plus cher : la hauteur utile
        // tombe de moitié. C'est là qu'une aide dépliée aurait rendu le formulaire
        // impraticable, donc là qu'il faut regarder.
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 4)
        capture("09-administration-paysage")
        tapInfoButton(app, besideFieldContaining: "Nom du jeu", name: "10-aide-paysage")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 3)
    }

    // MARK: - Outils

    /// Tape à droite d'un champ, là où se pose le bouton d'aide, puis capture le popover.
    private func tapInfoButton(_ app: XCUIApplication, besideFieldContaining label: String, name: String) {
        let field = app.textFields.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        let target: XCUIElement = field.exists ? field : app.textFields.firstMatch
        guard target.exists else { return }
        // Le champ s'arrête avant le bouton : viser au-delà de son bord droit, à mi-hauteur.
        let info = target.coordinate(withNormalizedOffset: CGVector(dx: 1.12, dy: 0.5))
        info.tap()
        Thread.sleep(forTimeInterval: 2)
        capture(name)
        // Referme le popover en tapant à l'écart.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        Thread.sleep(forTimeInterval: 1)
    }

    /// `tap()` échoue quand l'élément existe sans être « hittable ». Le clic en coordonnées
    /// passe outre, ce qui suffit pour un harnais de capture.
    private func tapAnyway(_ element: XCUIElement) {
        if element.isHittable { element.tap() }
        else { element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        Thread.sleep(forTimeInterval: 0.8)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
