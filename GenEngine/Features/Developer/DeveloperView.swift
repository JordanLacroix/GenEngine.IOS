#if DEBUG
import SwiftUI

struct DeveloperView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Form {
                Section("Services") {
                    TextField("Identity URL", text: $state.endpoints.identity).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Authoring URL", text: $state.endpoints.authoring).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Play URL", text: $state.endpoints.play).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Configuration URL", text: $state.endpoints.configuration).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Player Experience URL", text: $state.endpoints.playerExperience).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Réinitialiser sur localhost") { state.endpoints = .local }
                }
                Section("Scénario de développement") {
                    Button("Importer et publier la fixture forêt") {
                        guard let url = Bundle.main.url(forResource: "forest-choice", withExtension: "json"), let data = try? Data(contentsOf: url) else { return }
                        Task { await state.importAndPublish(data, label: "forest-choice") }
                    }
                    .disabled(!state.isAuthenticated || state.isBusy)
                    if !state.isAuthenticated { Text("Connectez-vous au backend pour utiliser Authoring.").foregroundStyle(.secondary) }
                }
                Section("Session") {
                    TextField("Seed", text: $state.seedText).keyboardType(.numberPad)
                    Button("Se déconnecter", role: .destructive) { state.signOut() }
                }
                Section("Journal technique") {
                    if state.developerLog.isEmpty { Text("Aucun événement").foregroundStyle(.secondary) }
                    ForEach(Array(state.developerLog.prefix(20).enumerated()), id: \.offset) { _, line in Text(line).font(.caption.monospaced()) }
                }
            }
            .navigationTitle("Developer")
        }
    }
}
#endif
