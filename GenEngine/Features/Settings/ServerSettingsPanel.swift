import SwiftUI

/// Réglage de l'adressage des six services, accessible **avant** toute connexion.
///
/// Sur un appareil neuf, l'application ne pouvait viser que l'adresse compilée par défaut :
/// aucun recours n'existait avant l'authentification, et le seul éditeur d'endpoints vivait
/// derrière une destination d'administration réservée aux comptes connectés. Cet écran ferme
/// ce point. Il ne relève pas de l'outillage de développement : il n'expose ni journal brut,
/// ni import Authoring, qui restent confinés aux builds Debug.
struct ServerSettingsPanel: View {
    @Environment(AppState.self) private var state
    @State private var draft: EndpointDraft
    @State private var results: [ServiceKind: ServiceReachability] = [:]
    @State private var confirmation: ConfirmationAction?
    @State private var savedMessage: String?

    init(endpoints: ServiceEndpoints) {
        _draft = State(initialValue: EndpointDraft(endpoints))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro
            modePicker
            if draft.mode == .grouped { groupedFields } else { individualFields }
            servicesReport
            validation
            actions
        }
        .foregroundStyle(GenEngineTheme.ivory)
        .confirmation($confirmation)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Où sont installés vos services ?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text("GenEngine appelle six services. Ils peuvent tenir sur une seule machine, ou être déployés séparément. Ce réglage reste local à cet appareil et ne contient aucun secret.")
                .font(.callout)
                .foregroundStyle(GenEngineTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode de configuration", selection: $draft.mode) {
                ForEach(EndpointDraft.Mode.allCases) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)
            Text(draft.mode.explanation)
                .font(.caption)
                .foregroundStyle(GenEngineTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var groupedFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Schéma", selection: $draft.scheme) {
                ForEach(EndpointDraft.schemes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("HTTP en clair ne convient qu’à un réseau local de test : un appareil physique exige une adresse HTTPS joignable.")
                .font(.caption2)
                .foregroundStyle(GenEngineTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Hôte · nom de machine ou adresse IP", text: $draft.host)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .accessibilityLabel("Hôte commun des six services")
            Text("Un port par service").font(.headline)
            ForEach(ServiceKind.allCases) { service in
                HStack(spacing: 12) {
                    Label(service.title, systemImage: service.symbol)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField(String(service.defaultPort), text: portBinding(service))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 96)
                        .accessibilityLabel("Port de \(service.title)")
                }
                .frame(minHeight: HUDMetrics.minimumTarget)
            }
        }
    }

    private var individualFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ServiceKind.allCases) { service in
                VStack(alignment: .leading, spacing: 5) {
                    Label(service.title, systemImage: service.symbol).font(.subheadline.weight(.semibold))
                    Text(service.purpose).font(.caption2).foregroundStyle(GenEngineTheme.secondaryText)
                    TextField("https://exemple:\(service.defaultPort)", text: urlBinding(service))
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityLabel("Adresse complète de \(service.title)")
                }
            }
        }
    }

    private var servicesReport: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Contrôle de connectivité").font(.headline)
                Spacer()
                Button("Tout tester") { testAll() }
                    .buttonStyle(.bordered)
                    .tint(GenEngineTheme.amber)
                    .frame(minHeight: HUDMetrics.minimumTarget)
            }
            Text("Une réponse HTTP prouve seulement que l’adresse répond. Elle ne valide ni la version, ni les permissions, qui restent décidées par le service.")
                .font(.caption2)
                .foregroundStyle(GenEngineTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(ServiceKind.allCases) { service in
                let status = results[service] ?? .unknown
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(service.title).font(.subheadline.weight(.semibold))
                        Text(draft.resolvedURL(for: service).isEmpty ? "Adresse incomplète" : draft.resolvedURL(for: service))
                            .font(.caption2.monospaced())
                            .foregroundStyle(GenEngineTheme.secondaryText)
                            .lineLimit(2)
                        Label(status.label, systemImage: status.symbol)
                            .font(.caption)
                            .foregroundStyle(tint(for: status))
                    }
                    Spacer(minLength: 0)
                    Button("Tester") { test(service) }
                        .buttonStyle(.bordered)
                        .tint(GenEngineTheme.ivory)
                        .frame(minHeight: HUDMetrics.minimumTarget)
                        .accessibilityLabel("Tester \(service.title)")
                }
                .padding(12)
                .background(GenEngineTheme.midnight.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var validation: some View {
        if let message = draft.validationMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(GenEngineTheme.ember)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let savedMessage {
            Label(savedMessage, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(GenEngineTheme.verdigris)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button { save() } label: {
                Label("Enregistrer les adresses", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!draft.isValid)
            Button(role: .destructive) {
                confirmation = ConfirmationAction(
                    title: "Réinitialiser les adresses ?",
                    message: "Les six services reviendront à la configuration livrée avec l’application. Votre saisie sera perdue.",
                    confirmLabel: "Réinitialiser") {
                        draft = EndpointDraft(.local)
                        results = [:]
                        savedMessage = nil
                    }
            } label: {
                Label("Réinitialiser sur la configuration livrée", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func portBinding(_ service: ServiceKind) -> Binding<String> {
        Binding(get: { draft.ports[service] ?? "" }, set: { draft.ports[service] = $0 })
    }

    private func urlBinding(_ service: ServiceKind) -> Binding<String> {
        Binding(get: { draft.urls[service] ?? "" }, set: { draft.urls[service] = $0 })
    }

    private func tint(for status: ServiceReachability) -> Color {
        switch status {
        case .reachable: GenEngineTheme.verdigris
        case .unreachable: GenEngineTheme.ember
        default: GenEngineTheme.secondaryText
        }
    }

    private func test(_ service: ServiceKind) {
        let target = draft.resolvedURL(for: service)
        results[service] = .checking
        Task { @MainActor in
            let outcome = await EndpointProbe().check(target)
            results[service] = outcome
            AccessibilityNotification.Announcement("\(service.title) : \(outcome.label)").post()
        }
    }

    private func testAll() {
        for service in ServiceKind.allCases { test(service) }
    }

    private func save() {
        guard let endpoints = draft.endpoints() else { return }
        state.endpoints = endpoints
        draft = EndpointDraft(endpoints)
        savedMessage = "Adresses enregistrées sur cet appareil."
        state.reportSuccess("Adresses des services enregistrées")
        Task { await state.loadPublicExperience() }
    }
}
