import Foundation

/// Enveloppe de liste unifiée du backend, introduite par GenEngine#55 :
/// `{ "items": [...], "page": 1, "pageSize": 25, "total": 213 }`.
///
/// La convention est identique sur toutes les listes : `page` en base 1,
/// `pageSize` clampé côté serveur à `[1, 100]`, `total` portant sur l'ensemble
/// filtré et non sur la page.
///
/// Le décodage est **tolérant**, conformément à la norme du dépôt :
///
/// - un **tableau nu** (contrat antérieur à GenEngine#55) est accepté et présenté
///   comme une page unique complète, de sorte qu'un client à jour reste
///   fonctionnel — quoique non paginé — face à un serveur qui ne l'est pas ;
/// - une métadonnée manquante ou absurde retombe sur une valeur cohérente avec
///   `items`, plutôt que de faire échouer la réponse entière.
struct PagedList<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let page: Int
    let pageSize: Int
    let total: Int

    private enum CodingKeys: String, CodingKey { case items, page, pageSize, total }

    init(items: [Item], page: Int, pageSize: Int, total: Int) {
        self.items = items
        self.page = max(page, 1)
        self.pageSize = max(pageSize, 1)
        self.total = max(total, 0)
    }

    init(from decoder: any Decoder) throws {
        // Contrat antérieur : tableau nu. Une seule page, complète par définition.
        if let bare = try? decoder.singleValueContainer().decode([Item].self) {
            self.init(items: bare, page: 1, pageSize: max(bare.count, 1), total: bare.count)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        let page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        let pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? max(items.count, 1)
        // Un `total` absent ou incohérent ne doit pas faire croire que la liste est vide
        // alors que des éléments sont déjà là.
        // Une page vide au-delà du dernier élément est légitime : on garde alors le `total`
        // du serveur tel quel, sans lui appliquer le plancher déduit du décalage de page.
        let declared = try container.decodeIfPresent(Int.self, forKey: .total) ?? items.count
        let floor = items.isEmpty ? 0 : (max(page, 1) - 1) * max(pageSize, 1) + items.count
        self.init(items: items, page: page, pageSize: pageSize, total: max(declared, floor))
    }

    /// Le serveur détient-il des éléments au-delà de cette page ?
    var hasMore: Bool { page * pageSize < total }

    /// Numéro de la page suivante, `nil` sur la dernière.
    var nextPage: Int? { hasMore ? page + 1 : nil }
}

typealias PagedPublishedScenariosView = PagedList<PublishedScenarioView>
typealias PagedUnitsView = PagedList<OrganizationUnitView>
typealias PagedPeriodsView = PagedList<OperatingPeriodView>
typealias PagedScenarioVersionsView = PagedList<ScenarioVersionView>
