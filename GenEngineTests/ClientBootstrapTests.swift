import Foundation
import SwiftUI
import Testing
@testable import GenEngine

/// Amorce cliente anonyme et charte servie.
///
/// Ces tests portent sur le **décodage** et la **résolution de couleur**, pas sur le rendu :
/// la CI ne fait aucun test de rendu, et un test vert ne dit rien de l'apparence à l'écran.
struct ClientBootstrapTests {
    /// Charge utile réelle de `GET /client-bootstrap/default` pour la configuration Diapason,
    /// réduite aux champs que le client consomme.
    private static let payload = """
    {
      "frontId": "default",
      "version": 2,
      "publishedAt": "2026-07-19T22:24:37.241743+00:00",
      "applicationName": "Le Diapason",
      "shortName": "Diapason",
      "tagline": "Une réponse fluide n'est pas une réponse vérifiée.",
      "branding": {
        "applicationName": "Le Diapason",
        "shortName": "Diapason",
        "tagline": "Une réponse fluide n'est pas une réponse vérifiée.",
        "brandIconUrl": null,
        "logoUrl": null,
        "theme": {
          "colors": {
            "ink": "#17344a", "muted": "#c8b98d", "accent": "#d7a746",
            "danger": "#a33b2a", "success": "#7a9a55", "surface": "#fffaf0",
            "warning": "#c98a2e", "accentAlt": "#2f7fa0"
          },
          "colorScheme": "Light",
          "cornerRadius": 12,
          "fontFamily": "Georgia, serif"
        },
        "accentPalette": {
          "or": "#d7a746", "aube": "#e8b98c", "azur": "#2f7fa0",
          "amber": "#c98a2e", "encre": "#17344a", "sauge": "#7a9a55",
          "cuivre": "#b0733a"
        }
      },
      "locale": "fr-FR",
      "timeZone": "Europe/Paris",
      "labels": { "demo.explore": "Explorer la démo", "nav.home": "Accueil" },
      "authenticationMode": "LocalOnly",
      "demoEnabled": true,
      "intro": {
        "enabled": true, "displayPolicy": "OncePerVersion", "allowSkip": true,
        "minimumDisplaySeconds": 0,
        "scenes": [{
          "id": "59ee8932-281f-4fbc-a02b-90221d0a0ad4",
          "eyebrow": "Le Diapason",
          "title": "Une réponse fluide n'est pas une réponse vérifiée.",
          "body": "2026.",
          "imageUrl": null,
          "order": 1
        }]
      }
    }
    """

    private func decode(_ json: String) throws -> ClientBootstrapView {
        try JSONDecoder().decode(ClientBootstrapView.self, from: Data(json.utf8))
    }

    @Test func decodesTheServedBootstrap() throws {
        let bootstrap = try decode(Self.payload)
        #expect(bootstrap.frontId == "default")
        #expect(bootstrap.applicationName == "Le Diapason")
        #expect(bootstrap.tagline == "Une réponse fluide n'est pas une réponse vérifiée.")
        #expect(bootstrap.demoEnabled == true)
        #expect(bootstrap.authenticationMode == "LocalOnly")
        #expect(bootstrap.labels?["demo.explore"] == "Explorer la démo")
        #expect(bootstrap.branding?.accentPalette?["azur"] == "#2f7fa0")
        #expect(bootstrap.intro?.scenes.count == 1)
        // Une scène sans image reste décodable : c'est le cas nominal depuis le retrait
        // des liens externes côté moteur.
        #expect(bootstrap.intro?.scenes.first?.imageUrl == nil)
    }

    /// Une instance qui ne publie qu'une partie du contrat ne doit pas empêcher le démarrage.
    @Test func decodesAMinimalBootstrap() throws {
        let bootstrap = try decode(#"{"frontId":"autre"}"#)
        #expect(bootstrap.frontId == "autre")
        #expect(bootstrap.applicationName == nil)
        #expect(bootstrap.branding == nil)
        #expect(bootstrap.labels == nil)
    }

    @Test func parsesHexColours() {
        #expect(Color(hexString: "#d7a746") != nil)
        #expect(Color(hexString: "d7a746") != nil)
        #expect(Color(hexString: "#abc") != nil)
        #expect(Color(hexString: "#d7a746ff") != nil)
        // Une valeur illisible rend `nil` plutôt qu'une couleur inventée : le repli doit
        // rester visible, jamais remplacé silencieusement par du noir.
        #expect(Color(hexString: "chartreuse") == nil)
        #expect(Color(hexString: "#12345") == nil)
        #expect(Color(hexString: "") == nil)
    }

    @Test func accentTokensResolveAgainstTheServedPalette() throws {
        let branding = try decode(Self.payload).branding
        var palette = BrandPalette.fallback
        var tokens: [String: Color] = [:]
        for (name, value) in branding?.accentPalette ?? [:] {
            tokens[name.lowercased()] = Color(hexString: value)
        }
        palette.accentTokens = tokens

        // Les jetons portés par les catégories, parcours et familiers sont rendables.
        for token in ["or", "azur", "encre", "sauge", "cuivre", "aube", "amber"] {
            #expect(palette.accent(token: token) == tokens[token], "jeton \(token) non résolu")
        }
        // La casse et les espaces du contenu servi ne font pas échouer la résolution.
        #expect(palette.accent(token: " AZUR ") == tokens["azur"])
        // Un jeton inconnu retombe sur une couleur lisible plutôt que de disparaître.
        #expect(palette.accent(token: "inconnu") == palette.verdigris)
    }

    @Test func storyAccentCarriesTheServedToken() {
        #expect(StoryAccent("Encre").token == "encre")
        #expect(StoryAccent(" sauge ").token == "sauge")
        // Les accents de repli restent des jetons de la charte Diapason.
        #expect(StoryAccent.ember.token == "cuivre")
        #expect(StoryAccent.verdigris.token == "azur")
        #expect(StoryAccent.violet.token == "aube")
    }

    @Test func emptyServedCopyFallsBackRatherThanBlanking() {
        #expect("   ".nonEmpty == nil)
        #expect("".nonEmpty == nil)
        #expect(" Accueil ".nonEmpty == "Accueil")
    }
}
