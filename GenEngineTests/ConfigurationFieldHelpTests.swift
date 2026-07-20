import Foundation
import Testing
@testable import GenEngine

/// Aide intégrée par champ : décodage du contrat servi, indexation et repli.
///
/// Ces tests portent sur la **consommation** du catalogue, pas sur son contenu : les
/// phrases sont maintenues côté moteur, avec un test de complétude bidirectionnel qui
/// interdit qu'un champ du document reste sans descripteur. Les recopier ici les ferait
/// diverger à la première évolution du schéma. Ils ne disent rien non plus du rendu :
/// la CI ne fait aucun test de rendu.
struct ConfigurationFieldHelpTests {
    /// Charge utile réelle de `GET /admin/configuration/field-descriptors`, réduite à
    /// quatre entrées représentatives : une avec contrainte, une sans, un chemin de
    /// collection et un chemin racine.
    private static let payload = """
    [
      {
        "path": "aiProviders[].authentication",
        "label": "Mode d'authentification du provider",
        "description": "Comment l'instance s'authentifie auprès du provider.",
        "example": "EntraId",
        "constraint": "None ou EntraId."
      },
      {
        "path": "aiProviders[].deployment",
        "label": "Déploiement",
        "description": "Le nom du modèle ou du déploiement appelé.",
        "example": "gpt-4.1-mini",
        "constraint": null
      },
      {
        "path": "game.name",
        "label": "Nom du jeu",
        "description": "Le nom affiché de la configuration.",
        "example": "Le Diapason",
        "constraint": "Obligatoire."
      },
      {
        "path": "frontId",
        "label": "Identifiant de front",
        "description": "L'identifiant stable de cette instance.",
        "example": "default",
        "constraint": null
      }
    ]
    """

    private static func decoded() throws -> [ConfigurationFieldDescriptor] {
        try JSONDecoder().decode([ConfigurationFieldDescriptor].self, from: Data(payload.utf8))
    }

    @Test func theServedContractDecodesWithItsFiveMembers() throws {
        let descriptors = try Self.decoded()
        #expect(descriptors.count == 4)
        let provider = try #require(descriptors.first { $0.path == "aiProviders[].authentication" })
        #expect(provider.label == "Mode d'authentification du provider")
        #expect(provider.description == "Comment l'instance s'authentifie auprès du provider.")
        #expect(provider.example == "EntraId")
        #expect(provider.constraint == "None ou EntraId.")
    }

    /// `constraint` est nullable dans le contrat : un `null` ne doit pas faire échouer
    /// le décodage de toute la liste.
    @Test func anAbsentConstraintDecodesAsNil() throws {
        let descriptors = try Self.decoded()
        let deployment = try #require(descriptors.first { $0.path == "aiProviders[].deployment" })
        #expect(deployment.constraint == nil)
    }

    @Test func theCatalogueFindsADescriptorByItsPath() throws {
        let catalog = ConfigurationFieldCatalog(descriptors: try Self.decoded())
        #expect(catalog.count == 4)
        #expect(catalog["game.name"]?.label == "Nom du jeu")
        #expect(catalog["aiProviders[].deployment"]?.label == "Déploiement")
        #expect(catalog["frontId"]?.label == "Identifiant de front")
    }

    /// Le repli attendu : un chemin inconnu ne renvoie rien, et le champ concerné sera
    /// rendu tel quel, sans encart vide ni texte inventé côté client.
    @Test func anUnknownPathYieldsNoHelpAtAll() throws {
        let catalog = ConfigurationFieldCatalog(descriptors: try Self.decoded())
        #expect(catalog["game.nameThatDoesNotExist"] == nil)
        #expect(catalog["categories[].name"] == nil)
        #expect(catalog[""] == nil)
    }

    @Test func anEmptyCatalogueIsEmptyAndSilent() {
        #expect(ConfigurationFieldCatalog.empty.isEmpty)
        #expect(ConfigurationFieldCatalog.empty["game.name"] == nil)
    }

    /// VoiceOver reçoit la description **et** la contrainte : un lecteur d'écran ne
    /// survole pas un encart, la règle doit voyager avec la description.
    @Test func theSpokenHintCarriesTheConstraintWhenThereIsOne() throws {
        let catalog = ConfigurationFieldCatalog(descriptors: try Self.decoded())
        let name = try #require(catalog["game.name"])
        #expect(name.spokenHint == "Le nom affiché de la configuration. Obligatoire.")
    }

    @Test func theSpokenHintIsJustTheDescriptionWithoutAConstraint() throws {
        let catalog = ConfigurationFieldCatalog(descriptors: try Self.decoded())
        let deployment = try #require(catalog["aiProviders[].deployment"])
        #expect(deployment.spokenHint == "Le nom du modèle ou du déploiement appelé.")
    }

    /// Le catalogue est mis en cache sur disque : il doit survivre à un aller-retour
    /// d'encodage sans perdre de membre.
    @Test func theCatalogueSurvivesTheDiskCacheRoundTrip() throws {
        let descriptors = try Self.decoded()
        let data = try JSONEncoder().encode(descriptors)
        let restored = try JSONDecoder().decode([ConfigurationFieldDescriptor].self, from: data)
        #expect(restored == descriptors)
    }
}
