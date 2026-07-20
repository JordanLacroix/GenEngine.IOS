import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmation: ConfirmationAction?
    @State private var showsServerSettings = false

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.verdigris)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        EyebrowText(text: state.isAuthenticated ? "Session active" : "Compte joueur", color: GenEngineTheme.verdigris)
                        Text(state.isAuthenticated ? state.access?.userName ?? "Compte connecté" : "Se connecter")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(GenEngineTheme.ivory)
                        Text(state.isAuthenticated
                             ? "Votre session est protégée dans le trousseau de l’iPad."
                             : "Connectez-vous sans quitter la démonstration pour retrouver vos histoires, vos rôles et votre progression.")
                            .foregroundStyle(GenEngineTheme.secondaryText)
                    }

                    if state.isAuthenticated { connectedCard }
                    else { loginCard }
                    if state.isAuthenticated, let experience = state.playerExperience {
                        if !experience.statList.isEmpty { statsCard(experience) }
                        if !experience.rewardList.isEmpty { rewardsCard(experience) }
                    }
                    serverSettingsEntry
                }
                .padding(22)
                .padding(.bottom, 24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            if showsServerSettings {
                HUDOverlayPanel(title: "Paramètres du serveur", symbol: "server.rack", dismissesOnBackgroundTap: false, onClose: { showsServerSettings = false }) {
                    ServerSettingsPanel(endpoints: state.endpoints)
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showsServerSettings)
        .confirmation($confirmation)
    }

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connecté en tant que \(state.access?.userName ?? "utilisateur")", systemImage: "checkmark.shield.fill")
                .font(.headline).foregroundStyle(GenEngineTheme.verdigris)
            if let roles = state.access?.roles, !roles.isEmpty {
                Text(roles.map(\.name).joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText)
            }
            Button {
                confirmation = ConfirmationAction(
                    title: "Rejouer le prologue ?",
                    message: "Votre progression de tutoriel repart à zéro. Les histoires déjà jouées ne sont pas touchées.",
                    confirmLabel: "Rejouer",
                    isDestructive: false) { Task { await state.resetOnboarding() } }
            } label: {
                Label("Rejouer le prologue", systemImage: "arrow.counterclockwise.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).tint(GenEngineTheme.amber)
            Button(role: .destructive) {
                confirmation = ConfirmationAction(
                    title: "Se déconnecter ?",
                    message: "Votre jeton est effacé du trousseau et une partie en cours est abandonnée. Le serveur conserve votre progression.",
                    confirmLabel: "Se déconnecter") { state.signOut() }
            } label: {
                Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22).glassPanel()
    }

    private var loginCard: some View {
        SignInPanel(loginSymbol: "person.badge.key.fill") {
            if state.isDemoAccess {
                Button(role: .destructive) {
                    confirmation = ConfirmationAction(
                        title: "Quitter la démonstration ?",
                        message: "La partie de démonstration en cours est abandonnée et vous revenez à l’accueil.",
                        confirmLabel: "Quitter") { state.leaveDemo() }
                } label: {
                    Label("Quitter la démonstration", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(state.isBusy)
            }
        }
    }

    // MARK: - Statistiques joueur

    /// Les statistiques que les scénarios font monter, chacune avec sa jauge doublée d'un
    /// texte. Une statistique à zéro s'affiche quand même : démarrer à zéro est le
    /// comportement documenté, pas une absence.
    private func statsCard(_ experience: PlayerExperienceView) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            EyebrowText(text: "Vos statistiques", color: GenEngineTheme.verdigris)
            ForEach(ProfilePresentation.statGauges(experience.statList)) { gauge in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(gauge.label).font(.headline).foregroundStyle(GenEngineTheme.ivory)
                        Spacer(minLength: 12)
                        Text(gauge.valueLabel).font(.subheadline.monospacedDigit()).foregroundStyle(GenEngineTheme.amber)
                    }
                    ProgressView(value: gauge.fraction).tint(GenEngineTheme.verdigris)
                    if !gauge.description.isEmpty {
                        Text(gauge.description).font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(gauge.accessibilityLabel)
                .accessibilityValue("\(gauge.percent) %")
            }
        }
        .padding(22).glassPanel()
    }

    // MARK: - Récompenses conditionnelles

    /// Les récompenses obtenues (avec leur date) et celles à venir (avec leur progression par
    /// condition). Une récompense non obtenue n'est jamais une porte fermée : ce qui reste est
    /// montré, comme la fin de jeu le fait déjà pour le finale.
    private func rewardsCard(_ experience: PlayerExperienceView) -> some View {
        let parts = ProfilePresentation.partitionedRewards(experience.rewardList, currencyName: experience.currencyName)
        return VStack(alignment: .leading, spacing: 18) {
            EyebrowText(text: "Vos récompenses", color: GenEngineTheme.amber)
            if !parts.earned.isEmpty {
                Text("Obtenues").font(.subheadline.weight(.semibold)).foregroundStyle(GenEngineTheme.secondaryText)
                ForEach(parts.earned) { rewardRow($0, isEarned: true) }
            }
            if !parts.upcoming.isEmpty {
                Text("À venir").font(.subheadline.weight(.semibold)).foregroundStyle(GenEngineTheme.secondaryText)
                ForEach(parts.upcoming) { rewardRow($0, isEarned: false) }
            }
        }
        .padding(22).glassPanel()
    }

    private func rewardRow(_ card: ProfilePresentation.RewardCard, isEarned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isEarned ? "checkmark.seal.fill" : "hourglass")
                    .font(.title3)
                    .foregroundStyle(isEarned ? GenEngineTheme.verdigris : GenEngineTheme.amber)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.label).font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
                    Text(ProfilePresentation.rewardStatus(card)).font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                }
            }
            if !card.description.isEmpty {
                Text(card.description).font(.subheadline).foregroundStyle(GenEngineTheme.secondaryText)
            }
            if !card.grants.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(card.grants) { grant in
                        HStack(spacing: 8) {
                            Image(systemName: grant.symbol).foregroundStyle(GenEngineTheme.amber).accessibilityHidden(true)
                            Text(grant.label).font(.caption.weight(.semibold)).foregroundStyle(GenEngineTheme.ivory)
                            Spacer(minLength: 8)
                            Text(grant.detail).font(.caption.monospacedDigit()).foregroundStyle(GenEngineTheme.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(grant.label), \(grant.detail)")
                    }
                }
            }
            if !isEarned, !card.conditions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(card.conditions) { condition in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: condition.satisfied ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(condition.satisfied ? GenEngineTheme.verdigris : GenEngineTheme.secondaryText)
                                    .accessibilityHidden(true)
                                Text(condition.description).font(.caption).foregroundStyle(GenEngineTheme.ivory)
                                Spacer(minLength: 8)
                                Text(condition.valueLabel).font(.caption.monospacedDigit()).foregroundStyle(GenEngineTheme.amber)
                            }
                            ProgressView(value: condition.fraction).tint(condition.satisfied ? GenEngineTheme.verdigris : GenEngineTheme.amber)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(condition.accessibilityLabel)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenEngineTheme.ink.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Les réglages d'adressage restent atteignables une fois connecté, y compris pour un
    /// profil sans permission d'administration : c'est un réglage d'appareil, pas un droit.
    private var serverSettingsEntry: some View {
        Button { showsServerSettings = true } label: {
            HStack {
                Label("Paramètres du serveur", systemImage: "server.rack")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(GenEngineTheme.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: HUDMetrics.minimumTarget)
            .glassPanel()
        }
        .buttonStyle(.plain)
        .foregroundStyle(GenEngineTheme.ivory)
        .accessibilityHint("Configurer l’adresse des six services qui servent \(state.gameName)")
    }
}
