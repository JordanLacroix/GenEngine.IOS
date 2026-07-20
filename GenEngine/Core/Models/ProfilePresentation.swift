import Foundation

/// Logique de présentation, **pure et testable**, des statistiques joueur et des récompenses
/// conditionnelles servies sur `GET /me/experience`.
///
/// Rien ici ne dépend de SwiftUI : la vue lit ces valeurs déjà calculées et ne fait que les
/// disposer. Deux natures ouvertes du contrat — le `mode` d'une récompense et le `type` d'un
/// octroi — sont interprétées ici par une énumération **à repli** : une valeur ajoutée par un
/// moteur plus récent dégrade en libellé neutre, elle ne fait jamais échouer un rendu.
enum ProfilePresentation {
    // MARK: - Statistiques

    /// Une jauge de statistique prête à dessiner. La valeur est **bornée à la lecture** par le
    /// plafond : un opérateur peut abaisser un maximum après que des joueurs l'ont dépassé, et
    /// un client ne doit jamais dessiner au-delà. Une statistique à zéro se présente quand même.
    struct StatGauge: Equatable, Sendable, Identifiable {
        let id: UUID
        let label: String
        let description: String
        let value: Int
        let maximum: Int

        /// Valeur effectivement dessinée, jamais négative ni au-delà du plafond publié.
        var clampedValue: Int {
            guard maximum > 0 else { return max(0, value) }
            return min(max(0, value), maximum)
        }

        var fraction: Double {
            guard maximum > 0 else { return 0 }
            return min(1, max(0, Double(clampedValue) / Double(maximum)))
        }

        var percent: Int { Int((fraction * 100).rounded()) }

        /// Texte qui double la jauge : une couleur ne porte jamais seule l'information.
        var valueLabel: String { "\(clampedValue) / \(maximum)" }

        /// Énoncé VoiceOver complet : libellé, valeur sur plafond, puis description.
        var accessibilityLabel: String {
            let head = "\(label) : \(clampedValue) sur \(maximum)"
            return description.isEmpty ? head : "\(head). \(description)"
        }
    }

    static func statGauge(_ stat: PlayerStatView) -> StatGauge {
        StatGauge(id: stat.id, label: stat.label, description: stat.description, value: stat.value, maximum: stat.maximum)
    }

    static func statGauges(_ stats: [PlayerStatView]) -> [StatGauge] { stats.map(statGauge) }

    // MARK: - Natures ouvertes

    /// Mode d'agrégation des conditions d'une récompense. Ouvert : replie sur `unknown` plutôt
    /// que de jeter.
    enum RewardMode: Equatable, Sendable {
        case all
        case any
        case unknown(String)

        static func from(_ raw: String) -> RewardMode {
            switch raw.lowercased() {
            case "all": return .all
            case "any": return .any
            default: return .unknown(raw)
            }
        }
    }

    /// Nature d'un octroi. Les trois natures connues **ne se comportent pas pareil** — les deux
    /// premières sont déclaratives, la monnaie déplace un solde — et un client doit les
    /// distinguer sans interpréter une convention de nommage. Une nature inconnue reste rendable.
    enum GrantNature: Equatable, Sendable {
        case achievement
        case title
        case currency
        case unknown(String)

        static func from(_ raw: String) -> GrantNature {
            switch raw.lowercased() {
            case "achievement": return .achievement
            case "title": return .title
            case "currency": return .currency
            default: return .unknown(raw)
            }
        }
    }

    // MARK: - Octrois

    /// Un octroi prêt à afficher : sa nature, un symbole, un libellé et un détail lisible.
    struct GrantBadge: Equatable, Sendable, Identifiable {
        let id: UUID
        let nature: GrantNature
        let label: String
        /// Nom de symbole SF Symbols.
        let symbol: String
        /// Détail doublant l'icône par du texte (montant crédité, ou catégorie d'octroi).
        let detail: String
    }

    static func grantBadge(_ grant: RewardGrantPlan, currencyName: String, index: Int, rewardId: UUID) -> GrantBadge {
        let nature = GrantNature.from(grant.type)
        let id = deterministicId(rewardId, index)
        let cleanLabel = grant.label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch nature {
        case .achievement:
            return GrantBadge(id: id, nature: nature, label: cleanLabel.isEmpty ? "Haut fait" : cleanLabel, symbol: "rosette", detail: "Haut fait")
        case .title:
            return GrantBadge(id: id, nature: nature, label: cleanLabel.isEmpty ? "Titre" : cleanLabel, symbol: "crown.fill", detail: "Titre à porter")
        case .currency:
            let amount = grant.amount ?? 0
            return GrantBadge(id: id, nature: nature, label: cleanLabel.isEmpty ? currencyName : cleanLabel, symbol: "creditcard.fill", detail: "+\(amount) \(currencyName)")
        case .unknown:
            return GrantBadge(id: id, nature: nature, label: cleanLabel.isEmpty ? "Récompense" : cleanLabel, symbol: "gift.fill", detail: "Récompense")
        }
    }

    // MARK: - Conditions

    /// Progression d'une condition, prête à dessiner : fraction bornée et libellé doublant la
    /// barre. Une condition sans cible chiffrée (`target <= 0`) tombe sur son booléen satisfait.
    struct ConditionRow: Equatable, Sendable, Identifiable {
        let id: UUID
        let description: String
        let satisfied: Bool
        let current: Int
        let target: Int

        var fraction: Double {
            guard target > 0 else { return satisfied ? 1 : 0 }
            return min(1, max(0, Double(current) / Double(target)))
        }

        var valueLabel: String {
            guard target > 0 else { return satisfied ? "Rempli" : "En attente" }
            return "\(min(max(0, current), target)) / \(target)"
        }

        var accessibilityLabel: String {
            let state = satisfied ? "remplie" : "en cours"
            let head = description.isEmpty ? "Condition \(state)" : "\(description) — \(state)"
            return target > 0 ? "\(head), \(min(max(0, current), target)) sur \(target)" : head
        }
    }

    static func conditionRow(_ progress: ProgressConditionProgress) -> ConditionRow {
        ConditionRow(id: progress.id, description: progress.description, satisfied: progress.satisfied, current: progress.current, target: progress.target)
    }

    // MARK: - Cartes de récompense

    /// Une récompense prête à afficher : obtenue avec sa date, ou à venir avec sa progression
    /// par condition. Jamais présentée comme une porte fermée : ce qui reste est toujours visible.
    struct RewardCard: Equatable, Sendable, Identifiable {
        let id: UUID
        let label: String
        let description: String
        let earned: Bool
        let earnedAt: Date?
        let mode: RewardMode
        let grants: [GrantBadge]
        let conditions: [ConditionRow]
        let visualUrl: URL?

        var satisfiedCount: Int { conditions.filter(\.satisfied).count }
        var totalConditions: Int { conditions.count }
    }

    static func rewardCard(_ reward: ConditionalRewardView, currencyName: String) -> RewardCard {
        RewardCard(
            id: reward.id,
            label: reward.label,
            description: reward.description,
            earned: reward.earned,
            earnedAt: reward.earnedAt,
            mode: RewardMode.from(reward.mode),
            grants: reward.grants.enumerated().map { grantBadge($0.element, currencyName: currencyName, index: $0.offset, rewardId: reward.id) },
            conditions: reward.conditions.map(conditionRow),
            visualUrl: reward.visualUrl.flatMap(URL.init(string:)))
    }

    /// Sépare les récompenses obtenues des récompenses à venir, en conservant l'ordre servi.
    /// Les obtenues sont listées d'abord côté vue, mais chacune garde ses conditions pour dire
    /// au joueur *pourquoi* il l'a.
    static func partitionedRewards(_ rewards: [ConditionalRewardView], currencyName: String) -> (earned: [RewardCard], upcoming: [RewardCard]) {
        let cards = rewards.map { rewardCard($0, currencyName: currencyName) }
        return (cards.filter(\.earned), cards.filter { !$0.earned })
    }

    /// Statut lisible d'une récompense. Une récompense à venir dit combien de conditions sont
    /// remplies, et si une seule suffit.
    static func rewardStatus(_ card: RewardCard) -> String {
        if card.earned {
            if let at = card.earnedAt {
                return "Obtenue le \(at.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Obtenue"
        }
        let done = card.satisfiedCount
        let total = card.totalConditions
        guard total > 0 else { return "À venir" }
        let filled = "\(done) condition\(done > 1 ? "s" : "") remplie\(done > 1 ? "s" : "") sur \(total)"
        switch card.mode {
        case .any:
            return "À venir · une condition suffit — \(filled)"
        case .all, .unknown:
            return "À venir · \(filled)"
        }
    }

    // MARK: - Identités dérivées

    /// Identité stable pour un octroi, qui n'en porte pas côté contrat. Dérivée de l'identité de
    /// la récompense et du rang de l'octroi, tous deux stables entre deux lectures.
    private static func deterministicId(_ rewardId: UUID, _ index: Int) -> UUID {
        var bytes = rewardId.uuid
        let mixed = UInt8((Int(bytes.15) &+ index) & 0xFF)
        bytes.15 = mixed
        return UUID(uuid: bytes)
    }
}
