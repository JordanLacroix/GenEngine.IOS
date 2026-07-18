import SwiftUI

struct AdministrationView: View {
    @Environment(AppState.self) private var state
    @State private var section = AdminSection.game
    @State private var document: ExperienceDocument?
    @State private var roleName = ""
    @State private var roleDescription = ""
    @State private var rolePermissions = Set<String>()
    @State private var assignmentUserID = ""
    @State private var assignmentRoleID: UUID?
    @State private var assignmentScope = ""

    var body: some View {
        ZStack {
            StoryCanvas(accent: GenEngineTheme.ember)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    sectionPicker
                    if document == nil { ProgressView("Chargement de la configuration…").tint(GenEngineTheme.amber).foregroundStyle(GenEngineTheme.ivory) }
                    else { sectionContent }
                    actionBar
                }
                .padding(.horizontal, 18).padding(.bottom, 120)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in min(availableWidth, 1_000) }
            }
        }
        .navigationTitle("Administration")
        .task { await state.loadAdministration(); document = state.adminConfiguration?.document }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            EyebrowText(text: "Control plane")
            Text("Piloter l’expérience").font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
            Text("Le paramétrage du jeu et des accès reste séparé du Studio éditorial.").foregroundStyle(GenEngineTheme.secondaryText)
            HStack {
                Label("Brouillon r\(state.adminConfiguration?.revision ?? 0)", systemImage: "pencil.circle")
                Label("Publié v\(state.adminConfiguration?.publishedVersion ?? 0)", systemImage: "checkmark.seal")
            }.font(.caption).foregroundStyle(GenEngineTheme.verdigris)
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(AdminSection.allCases) { item in
                    Button { section = item } label: { Label(item.title, systemImage: item.symbol).padding(.horizontal, 12).frame(minHeight: 40) }
                        .buttonStyle(.borderedProminent).tint(section == item ? GenEngineTheme.ember : GenEngineTheme.midnight)
                }
            }
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch section {
        case .game: gamePanel
        case .structure: structurePanel
        case .identity: identityPanel
        case .intelligence: intelligencePanel
        case .familiar: familiarPanel
        case .economy: economyPanel
        case .access: accessPanel
        }
    }

    private var gamePanel: some View {
        adminPanel("Jeu & histoire", symbol: "globe.europe.africa.fill") {
            if let binding = binding(\.game) {
                TextField("Nom du jeu", text: binding.name).textFieldStyle(.roundedBorder)
                TextField("Description", text: binding.description, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                TextField("Histoire globale", text: binding.globalStory, axis: .vertical).lineLimit(5...12).textFieldStyle(.roundedBorder)
                HStack { TextField("Locale", text: binding.locale); TextField("Fuseau", text: binding.timeZone) }.textFieldStyle(.roundedBorder)
                Picker("Organisation", selection: bindingRoot(\.organizationType, fallback: "Custom")) {
                    Text("École").tag("School"); Text("Entreprise").tag("Company"); Text("Formation").tag("TrainingProvider"); Text("Communauté").tag("Community"); Text("Personnalisée").tag("Custom")
                }
            }
        }
    }

    private var structurePanel: some View {
        adminPanel("Catégories de scénarios", symbol: "square.grid.2x2.fill") {
            if let count = document?.categories.count {
                ForEach(0..<count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 9) {
                        TextField("Nom", text: bindingArray(\.categories, index, \.name, fallback: "" )).font(.headline)
                        TextField("Description", text: bindingArray(\.categories, index, \.description, fallback: ""), axis: .vertical)
                        Toggle("Visible dans les clients", isOn: bindingArray(\.categories, index, \.isVisible, fallback: true))
                    }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Button { document?.categories.append(.init(id: UUID(), name: "Nouvelle catégorie", description: "", accent: "amber", order: (document?.categories.count ?? 0) + 1, isVisible: true)) } label: { Label("Ajouter une catégorie", systemImage: "plus") }
        }
    }

    private var identityPanel: some View {
        adminPanel("Authentification", symbol: "person.badge.key.fill") {
            if let binding = binding(\.authentication) {
                Picker("Mode", selection: binding.mode) { Text("BDD uniquement").tag("LocalOnly"); Text("Microsoft uniquement").tag("EntraOnly"); Text("Cumulatif").tag("Cumulative") }
                Toggle("Comptes locaux", isOn: binding.localEnabled)
                Toggle("Microsoft Entra ID", isOn: binding.entraEnabled)
                if binding.wrappedValue.entraEnabled {
                    TextField("Tenant ID", text: optional(binding.entraTenantId)).textFieldStyle(.roundedBorder)
                    TextField("Client ID", text: optional(binding.entraClientId)).textFieldStyle(.roundedBorder)
                    Text("Le client natif utilise Authorization Code + PKCE ; enregistrez le redirect URI genengine://auth dans Entra.").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                }
            }
        }
    }

    private var intelligencePanel: some View {
        adminPanel("Providers IA", symbol: "brain.head.profile") {
            if let count = document?.aiProviders.count {
                ForEach(0..<count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 9) {
                        Toggle(isOn: bindingArray(\.aiProviders, index, \.enabled, fallback: false)) { Text(document?.aiProviders[index].name ?? "Provider").font(.headline) }
                        TextField("Endpoint OpenAI v1", text: bindingArray(\.aiProviders, index, \.endpoint, fallback: "")).textFieldStyle(.roundedBorder)
                        TextField("Déploiement", text: bindingArray(\.aiProviders, index, \.deployment, fallback: "")).textFieldStyle(.roundedBorder)
                        TextField("Référence du secret", text: optionalArray(\.aiProviders, index, \.secretReference)).textFieldStyle(.roundedBorder)
                    }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Text("Azure AI Foundry passe par l’endpoint stable OpenAI /v1 et une identité managée/DefaultAzureCredential.").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
        }
    }

    private var familiarPanel: some View {
        adminPanel("Familiers", symbol: "wand.and.stars") {
            if let count = document?.familiars.count {
                ForEach(0..<count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 9) {
                        TextField("Nom", text: bindingArray(\.familiars, index, \.name, fallback: "")).font(.headline)
                        TextField("Personnalité", text: bindingArray(\.familiars, index, \.description, fallback: ""), axis: .vertical)
                        HStack { TextField("Forme", text: bindingArray(\.familiars, index, \.form, fallback: "spark")); TextField("Ton", text: bindingArray(\.familiars, index, \.tone, fallback: "Warm")) }.textFieldStyle(.roundedBorder)
                        TextField("Style d’écriture", text: bindingArray(\.familiars, index, \.writingStyle, fallback: "Socratic")).textFieldStyle(.roundedBorder)
                        Stepper("Aide par défaut : \(document?.familiars[index].helpLevel ?? 0)", value: bindingArray(\.familiars, index, \.helpLevel, fallback: 2), in: 0...5)
                    }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Button { document?.familiars.append(.init(id: UUID(), name: "Nouveau familier", description: "", form: "spark", writingStyle: "Socratic", tone: "Warm", accent: "amber", helpLevel: 2, capabilities: ["hint", "recap"], availableForms: ["spark"], availableTones: ["Warm", "Playful", "Direct"])) } label: { Label("Ajouter un familier", systemImage: "plus") }
        }
    }

    private var economyPanel: some View {
        adminPanel("Économie & magasin", symbol: "bag.fill") {
            if let binding = binding(\.economy) {
                HStack { TextField("Code", text: binding.currencyCode); TextField("Nom", text: binding.currencyName); TextField("Icône", text: binding.currencyIcon) }.textFieldStyle(.roundedBorder)
                Stepper("Solde initial : \(binding.wrappedValue.initialBalance)", value: binding.initialBalance, in: 0...10_000)
            }
            Text("Règles de gains").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(document?.economy.rewardRules ?? []) { rule in Label("\(rule.description) · +\(rule.amount)", systemImage: "sparkles").foregroundStyle(GenEngineTheme.secondaryText) }
            Button { document?.economy.rewardRules.append(.init(trigger: "ScenarioCompleted", referenceId: "*", amount: 10, description: "Nouvelle récompense")) } label: { Label("Ajouter une règle", systemImage: "plus") }
            Divider().overlay(.white.opacity(0.15))
            Text("Offres").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(document?.economy.offers ?? []) { offer in HStack { VStack(alignment: .leading) { Text(offer.name); Text(offer.description).font(.caption) }; Spacer(); Text("\(offer.price) \(document?.economy.currencyIcon ?? "✦")") }.foregroundStyle(GenEngineTheme.ivory) }
            Button { document?.economy.offers.append(.init(id: UUID(), name: "Nouvelle offre", description: "", price: 50, rewardType: "FamiliarCosmetic", rewardReference: UUID().uuidString, enabled: true)) } label: { Label("Ajouter une offre", systemImage: "plus") }
        }
    }

    private var accessPanel: some View {
        adminPanel("Rôles & permissions", symbol: "person.3.fill") {
            if !state.hasPermission("rbac.manage") { Text("Votre profil peut consulter la configuration, mais pas gérer les accès.").foregroundStyle(GenEngineTheme.secondaryText) }
            ForEach(state.roles) { role in
                VStack(alignment: .leading, spacing: 4) { HStack { Text(role.name).font(.headline); if role.isSystem { Text("SYSTÈME").font(.caption2).foregroundStyle(GenEngineTheme.amber) } }; Text(role.description).font(.subheadline); Text(role.permissions.joined(separator: " · ")).font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }
                    .padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            if state.hasPermission("rbac.manage") {
                TextField("Nom du rôle", text: $roleName).textFieldStyle(.roundedBorder)
                TextField("Description", text: $roleDescription).textFieldStyle(.roundedBorder)
                ForEach(state.permissionsCatalog) { permission in
                    Toggle(isOn: Binding(get: { rolePermissions.contains(permission.code) }, set: { enabled in
                        if enabled { rolePermissions.insert(permission.code) } else { rolePermissions.remove(permission.code) }
                    })) { VStack(alignment: .leading) { Text(permission.code); Text(permission.description).font(.caption).foregroundStyle(GenEngineTheme.secondaryText) } }
                }
                Button("Créer le rôle") { Task { await state.createRole(name: roleName, description: roleDescription, permissions: Array(rolePermissions)); roleName = ""; roleDescription = ""; rolePermissions = [] } }.buttonStyle(PrimaryActionStyle()).disabled(roleName.isEmpty || rolePermissions.isEmpty)
                Divider().overlay(.white.opacity(0.15))
                Text("Affecter un rôle").font(.headline).foregroundStyle(GenEngineTheme.ivory)
                Text("Le scope optionnel prépare les périmètres école, classe, entreprise ou équipe.").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                TextField("ID utilisateur", text: $assignmentUserID).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                Picker("Rôle", selection: $assignmentRoleID) { Text("Sélectionner…").tag(nil as UUID?); ForEach(state.roles) { Text($0.name).tag(Optional($0.id)) } }
                TextField("Scope optionnel · ex. class:6e-a", text: $assignmentScope).textFieldStyle(.roundedBorder)
                Button("Affecter") {
                    guard let userID = UUID(uuidString: assignmentUserID), let assignmentRoleID else { return }
                    Task { await state.assignRole(userId: userID, roleId: assignmentRoleID, scope: assignmentScope.isEmpty ? nil : assignmentScope); assignmentUserID = ""; assignmentScope = "" }
                }.buttonStyle(PrimaryActionStyle()).disabled(UUID(uuidString: assignmentUserID) == nil || assignmentRoleID == nil)
            }
        }
    }

    @ViewBuilder private var actionBar: some View {
        if let document {
            HStack {
                Button { Task { await state.saveConfiguration(document); self.document = state.adminConfiguration?.document } } label: { Label("Enregistrer", systemImage: "square.and.arrow.down") }.buttonStyle(PrimaryActionStyle()).disabled(!state.hasPermission("config.write") || state.isBusy)
                Button { Task { await state.publishConfiguration(); self.document = state.adminConfiguration?.document } } label: { Label("Publier", systemImage: "paperplane.fill") }.buttonStyle(.borderedProminent).tint(GenEngineTheme.verdigris).disabled(!state.hasPermission("config.publish") || state.isBusy)
            }
        }
    }

    private func adminPanel<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) { Label(title, systemImage: symbol).font(.title2.bold()).foregroundStyle(GenEngineTheme.ivory); content() }.padding(20).glassPanel()
    }

    private func binding<Value>(_ path: WritableKeyPath<ExperienceDocument, Value>) -> Binding<Value>? {
        guard document != nil else { return nil }
        return Binding(get: { document![keyPath: path] }, set: { document![keyPath: path] = $0 })
    }
    private func bindingRoot<Value>(_ path: WritableKeyPath<ExperienceDocument, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?[keyPath: path] ?? fallback }, set: { document?[keyPath: path] = $0 }) }
    private func bindingArray<Element, Value>(_ path: WritableKeyPath<ExperienceDocument, [Element]>, _ index: Int, _ value: WritableKeyPath<Element, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?[keyPath: path][index][keyPath: value] ?? fallback }, set: { document?[keyPath: path][index][keyPath: value] = $0 }) }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
    private func optionalArray<Element>(_ path: WritableKeyPath<ExperienceDocument, [Element]>, _ index: Int, _ value: WritableKeyPath<Element, String?>) -> Binding<String> { Binding(get: { document?[keyPath: path][index][keyPath: value] ?? "" }, set: { document?[keyPath: path][index][keyPath: value] = $0.isEmpty ? nil : $0 }) }
}

private enum AdminSection: String, CaseIterable, Identifiable {
    case game, structure, identity, intelligence, familiar, economy, access
    var id: String { rawValue }
    var title: String { switch self { case .game: "Jeu"; case .structure: "Structure"; case .identity: "Auth"; case .intelligence: "IA"; case .familiar: "Familier"; case .economy: "Économie"; case .access: "Accès" } }
    var symbol: String { switch self { case .game: "globe"; case .structure: "square.grid.2x2"; case .identity: "key"; case .intelligence: "brain"; case .familiar: "wand.and.stars"; case .economy: "bag"; case .access: "person.3" } }
}
