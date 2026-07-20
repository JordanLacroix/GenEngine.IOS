import Foundation

/// Aide intégrée d'un seul champ de configuration, **servie par le moteur**.
///
/// Le texte n'est pas recopié dans ce dépôt. `GET /admin/configuration/field-descriptors`
/// sert le catalogue complet, maintenu côté moteur avec un test de complétude
/// bidirectionnel : un champ ajouté à `ExperienceDocument` sans descripteur casse la
/// construction du moteur plutôt que de livrer un champ muet. Le client se contente de
/// consommer, ce qui garantit que le client Web et le client iOS affichent la même phrase.
struct ConfigurationFieldDescriptor: Codable, Sendable, Hashable, Identifiable {
    /// Chemin pointé et stable du champ dans le document publié — `game.name`,
    /// `economy.offers[].price`. C'est la seule clé de liaison : un champ retrouve son aide
    /// sans table de correspondance supplémentaire, et survit à un déplacement dans son bloc.
    let path: String
    /// Nom court du champ, tel qu'il est affiché en libellé de formulaire.
    let label: String
    /// Ce que le champ fait réellement, en une ou deux phrases.
    let description: String
    /// Une valeur admissible concrète, montrée en exemple.
    let example: String
    /// La règle lisible que le serveur applique, quand il y en a une.
    let constraint: String?

    var id: String { path }

    /// Ce que VoiceOver annonce **avec le champ**, et non comme un élément voisin.
    /// La contrainte est jointe à la description : un lecteur d'écran ne peut pas
    /// « survoler » un encart, il faut donc que la règle voyage avec la description.
    var spokenHint: String {
        guard let constraint = constraint?.nonEmpty else { return description }
        return "\(description) \(constraint)"
    }
}

/// Le catalogue d'aide indexé par chemin.
///
/// Volontairement un type valeur immuable : il est chargé une fois, ne change pas pendant
/// une session, et se pose donc en valeur d'environnement SwiftUI sans invalider de vue.
struct ConfigurationFieldCatalog: Sendable, Equatable {
    static let empty = ConfigurationFieldCatalog(descriptors: [])

    private let byPath: [String: ConfigurationFieldDescriptor]

    init(descriptors: [ConfigurationFieldDescriptor]) {
        byPath = Dictionary(descriptors.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Repli propre : un chemin absent du catalogue ne renvoie rien du tout. L'appelant
    /// garde alors son libellé compilé et n'affiche simplement aucune aide — jamais un
    /// encart vide, jamais un texte de remplissage inventé côté client.
    subscript(path: String) -> ConfigurationFieldDescriptor? { byPath[path] }

    var isEmpty: Bool { byPath.isEmpty }
    var count: Int { byPath.count }
}

/// Cache disque du catalogue.
///
/// Le catalogue décrit le **schéma**, pas une instance : il est identique pour tous les
/// fronts et ne bouge qu'avec la version du moteur. Il est donc mis en cache dans le
/// répertoire Caches — effaçable par le système sans perte — plutôt que dans `UserDefaults`,
/// qui reste réservé aux préférences. Le cache sert l'affichage immédiatement au deuxième
/// lancement ; la réponse réseau, quand elle arrive, l'écrase toujours.
enum ConfigurationFieldCache {
    private static let fileName = "genengine.field-descriptors.v1.json"

    private static var url: URL? {
        try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(fileName)
    }

    static func load() -> [ConfigurationFieldDescriptor]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ConfigurationFieldDescriptor].self, from: data)
    }

    static func save(_ descriptors: [ConfigurationFieldDescriptor]) {
        guard let url, let data = try? JSONEncoder().encode(descriptors) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
