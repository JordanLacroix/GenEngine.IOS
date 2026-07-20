import Foundation
import Testing
@testable import GenEngine

/// Décodage tolérant des blocs `stats` et `rewards` de `GET /me/experience`, et logique de
/// présentation associée.
///
/// Ces blocs sont **matérialisés par la normalisation** : tout document publié les porte,
/// leur défaut est une liste vide. Une instance sans catalogue publié — comme la pile locale
/// de test — renvoie une liste vide ou omet la clé. Le décodage ne doit jamais jeter, et deux
/// natures ouvertes du contrat (le `mode` d'une récompense, le `type` d'un octroi) ne doivent
/// jamais être décodées en énumération fermée.
struct ProfileStatsRewardsTests {
    /// Décodeur configuré comme celui du client : dates ISO-8601 à secondes fractionnaires.
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let regular = ISO8601DateFormatter()
            regular.formatOptions = [.withInternetDateTime]
            if let date = regular.date(from: value) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date"))
        }
        return decoder
    }

    private func experience(statsRewards: String) -> String {
        """
        {"id":"11111111-1111-1111-1111-111111111111","frontId":"diapason","revision":3,
         "balance":0,"currencyCode":"ACC","currencyName":"Accords","currencyIcon":"a",
         "familiar":null,"familiarDefinition":null,
         "onboarding":{"tutorialId":"22222222-2222-2222-2222-222222222222","version":1,"status":"Pending","completedStepIds":[],"completedAt":null,"skippedAt":null,"revision":0},
         "masteries":[],"ownedOfferIds":[],"recentEntries":[],"recentJournal":[]\(statsRewards)}
        """
    }

    private func decodeExperience(_ json: String) throws -> PlayerExperienceView {
        try decoder().decode(PlayerExperienceView.self, from: Data(json.utf8))
    }

    // MARK: - Absence : le cœur de la tolérance

    @Test func absentBlocksDecodeToEmptyLists() throws {
        let view = try decodeExperience(experience(statsRewards: ""))
        #expect(view.statList.isEmpty)
        #expect(view.rewardList.isEmpty)
    }

    @Test func explicitlyEmptyBlocksDecodeToEmptyLists() throws {
        let view = try decodeExperience(experience(statsRewards: #","stats":[],"rewards":[]"#))
        #expect(view.statList.isEmpty)
        #expect(view.rewardList.isEmpty)
    }

    // MARK: - Statistiques

    @Test func statsDecodeWithLabelDescriptionValueAndMaximum() throws {
        let stats = #","stats":[{"id":"33333333-3333-3333-3333-333333333333","key":"lucidite","label":"Lucidité","description":"Suspendre une conclusion trop fluide.","value":40,"maximum":100}]"#
        let view = try decodeExperience(experience(statsRewards: stats))
        let stat = try #require(view.statList.first)
        #expect(stat.key == "lucidite")
        #expect(stat.label == "Lucidité")
        #expect(stat.value == 40)
        #expect(stat.maximum == 100)
    }

    @Test func aStatAtZeroIsKept() throws {
        let stats = #","stats":[{"id":"33333333-3333-3333-3333-333333333333","key":"k","label":"L","description":"","value":0,"maximum":50}]"#
        let view = try decodeExperience(experience(statsRewards: stats))
        #expect(view.statList.count == 1)
        #expect(view.statList[0].value == 0)
    }

    // MARK: - Récompenses et natures ouvertes

    @Test func rewardDecodesWithConditionsAndGrants() throws {
        let rewards = #","rewards":[{"id":"44444444-4444-4444-4444-444444444444","label":"Diapason accordé","description":"Cinq scénarios terminés.","earned":true,"earnedAt":"2026-07-20T10:00:00.000Z","mode":"All","conditions":[{"id":"55555555-5555-5555-5555-555555555555","kind":"ScenariosCompleted","description":"Cinq scénarios distincts terminés","satisfied":true,"current":5,"target":5}],"grants":[{"type":"Achievement","label":"Premier accord","reference":"first-accord","amount":null},{"type":"Currency","label":"Bourse","reference":null,"amount":100}],"visualUrl":null,"labelKey":null}]"#
        let view = try decodeExperience(experience(statsRewards: rewards))
        let reward = try #require(view.rewardList.first)
        #expect(reward.earned)
        #expect(reward.earnedAt != nil)
        #expect(reward.conditions.count == 1)
        #expect(reward.grants.count == 2)
        #expect(reward.grants[1].amount == 100)
    }

    /// La garantie qui vaut pour les valeurs qui n'existent pas encore : un `mode` inconnu ne
    /// jette pas au décodage — il est décodé en `String` — et se replie à la présentation.
    @Test func anUnknownRewardModeDoesNotThrow() throws {
        let rewards = #","rewards":[{"id":"44444444-4444-4444-4444-444444444444","label":"R","description":"","earned":false,"earnedAt":null,"mode":"Majority","conditions":[],"grants":[],"visualUrl":null,"labelKey":null}]"#
        let view = try decodeExperience(experience(statsRewards: rewards))
        let reward = try #require(view.rewardList.first)
        #expect(reward.mode == "Majority")
        #expect(ProfilePresentation.RewardMode.from(reward.mode) == .unknown("Majority"))
    }

    /// Un octroi d'une nature inconnue — publié par un moteur plus récent — se décode et se
    /// rend en badge neutre plutôt que de faire échouer toute l'expérience.
    @Test func anUnknownGrantNatureDoesNotThrow() throws {
        let rewards = #","rewards":[{"id":"44444444-4444-4444-4444-444444444444","label":"R","description":"","earned":true,"earnedAt":null,"mode":"Any","conditions":[],"grants":[{"type":"Hologram","label":"Reflet","reference":"reflet","amount":null}],"visualUrl":null,"labelKey":null}]"#
        let view = try decodeExperience(experience(statsRewards: rewards))
        let grant = try #require(view.rewardList.first?.grants.first)
        #expect(grant.type == "Hologram")
        let badge = ProfilePresentation.grantBadge(grant, currencyName: "Accords", index: 0, rewardId: view.rewardList[0].id)
        #expect(badge.nature == .unknown("Hologram"))
        #expect(badge.label == "Reflet")
    }

    /// Une entrée malformée est écartée sans emporter les entrées valides qui l'entourent
    /// (`LossyArray`). Sans cette tolérance par élément, tout le bloc — donc toute
    /// l'expérience — échouerait sur une seule statistique mal formée.
    @Test func aMalformedStatIsDroppedNotFatal() throws {
        let stats = #","stats":[{"id":"33333333-3333-3333-3333-333333333333","key":"k","label":"Valide","description":"","value":1,"maximum":10},{"id":"pas-un-uuid","key":"x","label":"Cassée","value":2,"maximum":10}]"#
        let view = try decodeExperience(experience(statsRewards: stats))
        #expect(view.statList.count == 1)
        #expect(view.statList[0].label == "Valide")
    }

    // MARK: - Modèle de présentation

    @Test func statGaugeClampsValueToMaximum() {
        // Un opérateur a abaissé le plafond sous une valeur déjà acquise.
        let gauge = ProfilePresentation.statGauge(PlayerStatView(id: UUID(), key: "k", label: "L", description: "d", value: 140, maximum: 100))
        #expect(gauge.clampedValue == 100)
        #expect(gauge.fraction == 1)
        #expect(gauge.valueLabel == "100 / 100")
    }

    @Test func statGaugeAtZeroReadsZeroPercent() {
        let gauge = ProfilePresentation.statGauge(PlayerStatView(id: UUID(), key: "k", label: "L", description: "", value: 0, maximum: 60))
        #expect(gauge.fraction == 0)
        #expect(gauge.percent == 0)
        #expect(gauge.valueLabel == "0 / 60")
    }

    @Test func currencyGrantShowsAmountAndCurrencyName() {
        let grant = RewardGrantPlan(type: "Currency", label: "Bourse", reference: nil, amount: 100)
        let badge = ProfilePresentation.grantBadge(grant, currencyName: "Accords", index: 0, rewardId: UUID())
        #expect(badge.nature == .currency)
        #expect(badge.detail == "+100 Accords")
    }

    @Test func partitionSplitsEarnedFromUpcomingKeepingConditions() {
        let earned = ConditionalRewardView(id: UUID(), label: "Obtenue", description: "", earned: true, earnedAt: Date(timeIntervalSince1970: 0), mode: "All", conditions: [ProgressConditionProgress(id: UUID(), kind: "ScenariosCompleted", description: "c", satisfied: true, current: 5, target: 5)], grants: [])
        let upcoming = ConditionalRewardView(id: UUID(), label: "À venir", description: "", earned: false, earnedAt: nil, mode: "Any", conditions: [ProgressConditionProgress(id: UUID(), kind: "PlayerStatReached", description: "c", satisfied: false, current: 2, target: 8)], grants: [])
        let parts = ProfilePresentation.partitionedRewards([earned, upcoming], currencyName: "Accords")
        #expect(parts.earned.map(\.label) == ["Obtenue"])
        #expect(parts.upcoming.map(\.label) == ["À venir"])
        // La récompense obtenue garde sa condition, pour dire au joueur *pourquoi* il l'a.
        #expect(parts.earned[0].conditions.count == 1)
    }

    @Test func upcomingRewardStatusCountsSatisfiedConditions() {
        let reward = ConditionalRewardView(id: UUID(), label: "R", description: "", earned: false, earnedAt: nil, mode: "All", conditions: [
            ProgressConditionProgress(id: UUID(), kind: "k", description: "a", satisfied: true, current: 1, target: 1),
            ProgressConditionProgress(id: UUID(), kind: "k", description: "b", satisfied: false, current: 0, target: 3)
        ], grants: [])
        let card = ProfilePresentation.rewardCard(reward, currencyName: "Accords")
        #expect(ProfilePresentation.rewardStatus(card) == "À venir · 1 condition remplie sur 2")
    }

    @Test func conditionRowFractionIsBounded() {
        let over = ProfilePresentation.conditionRow(ProgressConditionProgress(id: UUID(), kind: "k", description: "d", satisfied: true, current: 9, target: 5))
        #expect(over.fraction == 1)
        #expect(over.valueLabel == "5 / 5")
        let targetless = ProfilePresentation.conditionRow(ProgressConditionProgress(id: UUID(), kind: "k", description: "d", satisfied: true, current: 0, target: 0))
        #expect(targetless.fraction == 1)
        #expect(targetless.valueLabel == "Rempli")
    }
}
