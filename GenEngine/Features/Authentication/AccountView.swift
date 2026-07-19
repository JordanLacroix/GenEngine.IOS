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
                    serverSettingsEntry
                }
                .padding(22)
                .padding(.bottom, 24)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in min(availableWidth, 620) }
            }
            if showsServerSettings {
                HUDOverlayPanel(title: "Paramètres du serveur", symbol: "server.rack", onClose: { showsServerSettings = false }) {
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
        .accessibilityHint("Configurer l’adresse des six services GenEngine")
    }
}
