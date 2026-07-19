import SwiftUI

/// Demande de confirmation avant une action conséquente.
///
/// Une action qui perd du travail, ferme une session ou supprime une donnée doit
/// toujours passer par ici : le HUD n'offre aucune annulation après coup.
struct ConfirmationAction: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmLabel: String
    var isDestructive = true
    let perform: @MainActor () -> Void

    init(
        title: String,
        message: String,
        confirmLabel: String,
        isDestructive: Bool = true,
        perform: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.isDestructive = isDestructive
        self.perform = perform
    }
}

private struct ConfirmationModifier: ViewModifier {
    @Binding var request: ConfirmationAction?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                request?.title ?? "",
                isPresented: Binding(
                    get: { request != nil },
                    set: { if !$0 { request = nil } }),
                titleVisibility: .visible,
                presenting: request
            ) { action in
                Button(action.confirmLabel, role: action.isDestructive ? .destructive : nil) {
                    action.perform()
                    request = nil
                }
                Button("Annuler", role: .cancel) { request = nil }
            } message: { action in
                Text(action.message)
            }
            // VoiceOver annonce la feuille, mais pas toujours son message : l'annonce
            // explicite garantit que la conséquence est entendue avant le choix.
            .onChange(of: request?.id) { _, id in
                guard id != nil, let request else { return }
                AccessibilityNotification.Announcement("\(request.title). \(request.message)").post()
            }
    }
}

extension View {
    /// Branche une feuille de confirmation sur cette vue.
    func confirmation(_ request: Binding<ConfirmationAction?>) -> some View {
        modifier(ConfirmationModifier(request: request))
    }
}

/// Retour de succès visible. Les opérations réussies n'allaient jusqu'ici que dans
/// `developerLog`, c'est-à-dire nulle part pour un utilisateur.
struct SuccessToast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GenEngineTheme.ivory)
            .padding(.horizontal, 18)
            .frame(minHeight: HUDMetrics.minimumTarget)
            .background(GenEngineTheme.verdigris.opacity(0.22), in: Capsule())
            .overlay { Capsule().stroke(GenEngineTheme.verdigris.opacity(0.6)) }
            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
            .accessibilityLabel("Succès. \(message)")
    }
}

private struct SuccessToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissal: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    SuccessToast(message: message)
                        .padding(.top, HUDMetrics.topBarHeight + 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: message)
            .onChange(of: message) { _, value in
                dismissal?.cancel()
                guard let value else { return }
                AccessibilityNotification.Announcement(value).post()
                dismissal = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    if message == value { message = nil }
                }
            }
    }
}

extension View {
    /// Affiche un retour de succès éphémère, annoncé à VoiceOver.
    func successToast(_ message: Binding<String?>) -> some View {
        modifier(SuccessToastModifier(message: message))
    }
}
