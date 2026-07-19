import SwiftUI
import UniformTypeIdentifiers

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
    @State private var newLabelKey = ""
    @State private var newLabelValue = ""
    @State private var userSearch = ""
    @State private var operationsUnitName = ""
    @State private var operationsUnitCode = ""
    @State private var operationsUnitType = "Group"
    @State private var operationsParentID: UUID?
    @State private var periodName = ""
    @State private var periodCode = ""
    @State private var periodStartsAt = Date()
    @State private var periodEndsAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var memberUserID: UUID?
    @State private var memberUnitID: UUID?
    @State private var memberKind = MembershipKind.participant
    @State private var memberPeriodID: UUID?
    @State private var showsMembershipImporter = false
    @State private var pendingMembershipRows: [MembershipImportRow] = []
    @State private var membershipImportReport: MembershipImportView?
    @State private var assignmentUnitID: UUID?
    @State private var assignedContentType = AssignedContentType.journey
    @State private var assignedContentID: UUID?
    @State private var assignmentName = ""
    @State private var assignmentRequired = true

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
                .padding(.horizontal, 18).padding(.bottom, 24)
                .containerRelativeFrame(.horizontal) { availableWidth, _ in min(availableWidth, 1_000) }
            }
        }
        .task { await state.loadAdministration(); document = state.adminConfiguration?.document }
        .fileImporter(isPresented: $showsMembershipImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case let .success(url) = result else { return }
            do { pendingMembershipRows = try Self.parseMembershipCSV(url); membershipImportReport = nil }
            catch { state.errorMessage = error.localizedDescription }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            EyebrowText(text: state.copy("administration.eyebrow", fallback: "Centre de contrôle"))
            Text(state.copy("administration.title", fallback: "Piloter l’expérience")).font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(GenEngineTheme.ivory)
            Text(state.copy("administration.subtitle", fallback: "Le paramétrage du jeu et des accès reste séparé du Studio éditorial.")).foregroundStyle(GenEngineTheme.secondaryText)
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
        case .player: playerPanel
        case .language: languagePanel
        case .structure: structurePanel
        case .operations: operationsPanel
        case .users: usersPanel
        case .identity: identityPanel
        case .intelligence: intelligencePanel
        case .familiar: familiarPanel
        case .economy: economyPanel
        case .access: accessPanel
        case .technical: technicalPanel
        }
    }

    private var operationsPanel: some View {
        adminPanel("Structures, membres & affectations", symbol: "building.2.crop.circle.fill") {
            if let front = state.organizationFront {
                HStack { Label(front.name, systemImage: "building.2"); Spacer(); Text(front.isActive ? "Actif" : "Suspendu").foregroundStyle(front.isActive ? GenEngineTheme.verdigris : .red) }
                Text("\(state.organizationUnits.count) unités · \(state.operatingPeriods.count) périodes · \(state.memberships.count) memberships · \(state.contentAssignments.count) affectations").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            }

            Text("Périodes métier").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.operatingPeriods) { period in
                HStack { Image(systemName: "calendar").foregroundStyle(GenEngineTheme.amber); VStack(alignment: .leading) { Text(period.name).foregroundStyle(GenEngineTheme.ivory); Text("\(period.code) · \(period.startsAt.formatted(date: .abbreviated, time: .omitted)) → \(period.endsAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); if period.isActive { Text("Active").font(.caption).foregroundStyle(GenEngineTheme.verdigris) } }
                    .padding(12).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            }
            TextField("Nom de la période", text: $periodName).textFieldStyle(.roundedBorder)
            TextField("Code", text: $periodCode).textFieldStyle(.roundedBorder).textInputAutocapitalization(.characters)
            DatePicker("Début", selection: $periodStartsAt, displayedComponents: .date)
            DatePicker("Fin", selection: $periodEndsAt, displayedComponents: .date)
            Button { Task { await state.createOperatingPeriod(name: periodName, code: periodCode, startsAt: periodStartsAt, endsAt: periodEndsAt); periodName = ""; periodCode = "" } } label: { Label("Ajouter la période", systemImage: "calendar.badge.plus") }.buttonStyle(PrimaryActionStyle()).disabled(periodName.isEmpty || periodCode.isEmpty || periodEndsAt <= periodStartsAt || state.isBusy)

            Divider().overlay(.white.opacity(0.15))

            Text("Unités opérationnelles").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.organizationUnits) { unit in
                HStack { Image(systemName: "point.3.connected.trianglepath.dotted").foregroundStyle(GenEngineTheme.verdigris); VStack(alignment: .leading) { Text(unit.name).foregroundStyle(GenEngineTheme.ivory); Text("\(unit.type) · \(unit.code)").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); if !unit.isActive { Text("Inactive").font(.caption).foregroundStyle(.red) } }
                    .padding(12).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            }
            TextField("Nom de l’unité", text: $operationsUnitName).textFieldStyle(.roundedBorder)
            HStack { TextField("Type", text: $operationsUnitType); TextField("Code", text: $operationsUnitCode).textInputAutocapitalization(.characters) }.textFieldStyle(.roundedBorder)
            Picker("Parent", selection: $operationsParentID) { Text("Aucun").tag(nil as UUID?); ForEach(state.organizationUnits) { Text($0.name).tag(Optional($0.id)) } }
            Button { Task { await state.createOrganizationUnit(name: operationsUnitName, type: operationsUnitType, code: operationsUnitCode, parentId: operationsParentID); operationsUnitName = ""; operationsUnitCode = "" } } label: { Label("Ajouter l’unité", systemImage: "plus") }.buttonStyle(PrimaryActionStyle()).disabled(operationsUnitName.isEmpty || operationsUnitCode.isEmpty || state.isBusy)

            Divider().overlay(.white.opacity(0.15))
            Text("Participants & encadrants").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.memberships) { membership in
                HStack { Image(systemName: membership.kind == .supervisor ? "person.badge.key.fill" : "person.fill").foregroundStyle(membership.kind == .supervisor ? GenEngineTheme.amber : GenEngineTheme.verdigris); VStack(alignment: .leading) { Text(state.adminUsers.first { $0.id == membership.userId }?.userName ?? membership.userId.uuidString).lineLimit(1); Text("\(membership.kind == .supervisor ? "Encadrant" : "Participant") · \(state.organizationUnits.first { $0.id == membership.unitId }?.name ?? "Unité")\(membership.periodId.flatMap { id in state.operatingPeriods.first { $0.id == id }?.name }.map { " · \($0)" } ?? "")").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); Button(role: .destructive) { Task { await state.removeMembership(membership) } } label: { Image(systemName: "trash") } }
                    .padding(12).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            }
            Picker("Utilisateur", selection: $memberUserID) { Text("Sélectionner…").tag(nil as UUID?); ForEach(state.adminUsers.filter(\.isActive)) { Text($0.userName).tag(Optional($0.id)) } }
            Picker("Unité", selection: $memberUnitID) { Text("Sélectionner…").tag(nil as UUID?); ForEach(state.organizationUnits.filter(\.isActive)) { Text($0.name).tag(Optional($0.id)) } }
            Picker("Lien", selection: $memberKind) { Text("Participant").tag(MembershipKind.participant); Text("Encadrant").tag(MembershipKind.supervisor) }.pickerStyle(.segmented)
            Picker("Période", selection: $memberPeriodID) { Text("Sans période").tag(nil as UUID?); ForEach(state.operatingPeriods.filter(\.isActive)) { Text($0.name).tag(Optional($0.id)) } }
            Button { guard let memberUserID, let memberUnitID else { return }; Task { await state.createMembership(userId: memberUserID, unitId: memberUnitID, periodId: memberPeriodID, kind: memberKind); self.memberUserID = nil } } label: { Label("Ajouter le membership", systemImage: "person.badge.plus") }.buttonStyle(PrimaryActionStyle()).disabled(memberUserID == nil || memberUnitID == nil || state.isBusy)
            Button { showsMembershipImporter = true } label: { Label("Charger un CSV", systemImage: "doc.badge.plus") }.buttonStyle(.bordered)
            if !pendingMembershipRows.isEmpty {
                Text("\(pendingMembershipRows.count) ligne(s) prête(s). Colonnes : userId, unitId, periodId, kind, startsAt, endsAt.").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
                HStack {
                    Button("Prévisualiser") { Task { membershipImportReport = await state.importMemberships(pendingMembershipRows, dryRun: true) } }.buttonStyle(.bordered)
                    Button("Importer") { Task { membershipImportReport = await state.importMemberships(pendingMembershipRows, dryRun: false) } }.buttonStyle(PrimaryActionStyle()).disabled(membershipImportReport?.errors.isEmpty != true)
                }
            }
            if let report = membershipImportReport { Text(report.errors.isEmpty ? "\(report.created) création(s), \(report.unchanged) inchangée(s)." : report.errors.map { "Ligne \($0.row) : \($0.message)" }.joined(separator: "\n")).font(.caption).foregroundStyle(report.errors.isEmpty ? GenEngineTheme.verdigris : .red) }

            Divider().overlay(.white.opacity(0.15))
            Text("Contenus affectés").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(state.contentAssignments) { assignment in
                HStack { VStack(alignment: .leading) { Text(assignment.name).foregroundStyle(GenEngineTheme.ivory); Text("\(assignment.contentType.rawValue) · \(state.organizationUnits.first { $0.id == assignment.unitId }?.name ?? "Unité")").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); if assignment.required { Text("Obligatoire").font(.caption).foregroundStyle(GenEngineTheme.verdigris) }; Button(role: .destructive) { Task { await state.removeContentAssignment(assignment) } } label: { Image(systemName: "trash") } }
                    .padding(12).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            }
            Picker("Unité cible", selection: $assignmentUnitID) { Text("Sélectionner…").tag(nil as UUID?); ForEach(state.organizationUnits.filter(\.isActive)) { Text($0.name).tag(Optional($0.id)) } }
            Picker("Type de contenu", selection: $assignedContentType) { Text("Parcours").tag(AssignedContentType.journey); Text("Catégorie").tag(AssignedContentType.category); Text("Scénario").tag(AssignedContentType.scenario) }.pickerStyle(.segmented)
            Picker("Contenu", selection: $assignedContentID) { Text("Sélectionner…").tag(nil as UUID?); ForEach(availableContent, id: \.0) { item in Text(item.1).tag(Optional(item.0)) } }
            TextField("Nom opérationnel", text: $assignmentName).textFieldStyle(.roundedBorder)
            Toggle("Affectation obligatoire", isOn: $assignmentRequired)
            Button { guard let assignmentUnitID, let assignedContentID else { return }; Task { await state.createContentAssignment(unitId: assignmentUnitID, contentType: assignedContentType, contentId: assignedContentID, name: assignmentName, required: assignmentRequired, availableFrom: nil, dueAt: nil); self.assignedContentID = nil; assignmentName = "" } } label: { Label("Affecter le contenu", systemImage: "calendar.badge.plus") }.buttonStyle(PrimaryActionStyle()).disabled(assignmentUnitID == nil || assignedContentID == nil || assignmentName.isEmpty || state.isBusy)
        }
    }

    private var availableContent: [(UUID, String)] {
        switch assignedContentType {
        case .journey: document?.journeys?.map { ($0.id, $0.name) } ?? []
        case .category: document?.categories.map { ($0.id, $0.name) } ?? []
        case .scenario: (document?.categories ?? []).flatMap { category in (category.scenarioIds ?? []).map { ($0, "\(category.name) · \($0.uuidString.prefix(8))") } }
        }
    }

    private static func parseMembershipCSV(_ url: URL) throws -> [MembershipImportRow] {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let lines = try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else { return [] }
        let headers = header.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard ["userId", "unitId", "kind", "startsAt"].allSatisfy(headers.contains) else { throw CSVImportError.invalidHeader }
        let formatter = ISO8601DateFormatter()
        return try lines.dropFirst().enumerated().map { index, line in
            let values = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            let row = Dictionary(uniqueKeysWithValues: zip(headers, values))
            guard let userId = UUID(uuidString: row["userId"] ?? ""), let unitId = UUID(uuidString: row["unitId"] ?? ""), let startsAt = formatter.date(from: row["startsAt"] ?? "") else { throw CSVImportError.invalidRow(index + 2) }
            let rawKind = row["kind"] ?? ""
            guard rawKind == "Participant" || rawKind == "Supervisor" else { throw CSVImportError.invalidRow(index + 2) }
            let rawEndsAt = row["endsAt"] ?? ""
            let endsAt = rawEndsAt.isEmpty ? nil : formatter.date(from: rawEndsAt)
            if !rawEndsAt.isEmpty, endsAt == nil { throw CSVImportError.invalidRow(index + 2) }
            return MembershipImportRow(id: UUID(uuidString: row["id"] ?? "") ?? UUID(), unitId: unitId, userId: userId, periodId: UUID(uuidString: row["periodId"] ?? ""), kind: rawKind == "Supervisor" ? .supervisor : .participant, startsAt: startsAt, endsAt: endsAt)
        }
    }

    private var languagePanel: some View {
        adminPanel("Libellés & vocabulaire", symbol: "character.book.closed.fill") {
            Text("Tous les textes publiés avec le jeu sont modifiables. Les clés restent stables entre Web et iOS.").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            ForEach(document?.language.labels.keys.sorted() ?? [], id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(key).font(.caption.monospaced()).foregroundStyle(GenEngineTheme.amber); Spacer(); Button(role: .destructive) { document?.language.labels.removeValue(forKey: key) } label: { Image(systemName: "trash") } }
                    TextField("Texte affiché", text: bindingLanguageLabel(key), axis: .vertical).textFieldStyle(.roundedBorder)
                }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            Divider().overlay(.white.opacity(0.15))
            TextField("Nouvelle clé · ex. home.featured.title", text: $newLabelKey).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            TextField("Texte affiché", text: $newLabelValue, axis: .vertical).textFieldStyle(.roundedBorder)
            Button { let key = newLabelKey.trimmingCharacters(in: .whitespacesAndNewlines); let value = newLabelValue.trimmingCharacters(in: .whitespacesAndNewlines); document?.language.labels[key] = value; newLabelKey = ""; newLabelValue = "" } label: { Label("Ajouter le libellé", systemImage: "plus") }
                .disabled(newLabelKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newLabelValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || document?.language.labels[newLabelKey] != nil)
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
        adminPanel("Organisation & catégories", symbol: "square.grid.2x2.fill") {
            if let organization = binding(\.organization) {
                Text("Structure de l’organisation").font(.headline).foregroundStyle(GenEngineTheme.ivory)
                TextField("Nom de l’école, entreprise ou structure", text: organization.name).textFieldStyle(.roundedBorder)
                TextField("Description", text: organization.description, axis: .vertical).textFieldStyle(.roundedBorder)
            }
            Text("Établissements, classes, départements et équipes peuvent être imbriqués librement.").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            if let unitCount = document?.organization.units.count {
                ForEach(0..<unitCount, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack { TextField("Type", text: bindingOrganizationUnit(index, \.type, fallback: "Group")); TextField("Code", text: bindingOrganizationUnit(index, \.code, fallback: "")) }.textFieldStyle(.roundedBorder)
                        TextField("Nom de l’unité", text: bindingOrganizationUnit(index, \.name, fallback: "")).font(.headline)
                        TextField("Description", text: bindingOrganizationUnit(index, \.description, fallback: ""), axis: .vertical)
                        Picker("Parent", selection: bindingOrganizationUnit(index, \.parentId, fallback: nil)) {
                            Text("Racine").tag(nil as UUID?)
                            ForEach(document?.organization.units.filter { $0.id != document?.organization.units[index].id } ?? []) { unit in Text(unit.name).tag(Optional(unit.id)) }
                        }
                        Toggle("Active", isOn: bindingOrganizationUnit(index, \.enabled, fallback: true))
                        Button("Supprimer l’unité", role: .destructive) { let id = document?.organization.units[index].id; document?.organization.units.remove(at: index); document?.assignments?.removeAll { $0.organizationUnitId == id } }
                    }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Button { document?.organization.units.append(.init(id: UUID(), parentId: nil, type: defaultUnitType, name: "Nouvelle unité", code: "", description: "", order: (document?.organization.units.count ?? 0) + 1, enabled: true)) } label: { Label("Ajouter une unité", systemImage: "plus") }
            Divider().overlay(.white.opacity(0.15))
            Text("Catégories de scénarios").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            if let count = document?.categories.count {
                ForEach(0..<count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 9) {
                        TextField("Nom", text: bindingArray(\.categories, index, \.name, fallback: "" )).font(.headline)
                        TextField("Description", text: bindingArray(\.categories, index, \.description, fallback: ""), axis: .vertical)
                        Toggle("Visible dans les clients", isOn: bindingArray(\.categories, index, \.isVisible, fallback: true))
                        TextField("Image HTTPS", text: optionalArray(\.categories, index, \.imageUrl)).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                        Button("Supprimer la catégorie", role: .destructive) { let id = document?.categories[index].id; document?.categories.remove(at: index); document?.journeys?.indices.forEach { document?.journeys?[$0].categoryIds.removeAll { $0 == id } } }
                    }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Button { document?.categories.append(.init(id: UUID(), name: "Nouvelle catégorie", description: "", accent: "amber", order: (document?.categories.count ?? 0) + 1, isVisible: true)) } label: { Label("Ajouter une catégorie", systemImage: "plus") }
            Divider().overlay(.white.opacity(0.15))
            Text("Parcours").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(document?.journeys?.indices ?? [].indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 9) {
                    TextField("Nom du parcours", text: bindingJourney(index, \.name, fallback: "" )).font(.headline)
                    TextField("Description", text: bindingJourney(index, \.description, fallback: ""), axis: .vertical)
                    TextField("Image HTTPS", text: optionalJourney(index, \.imageUrl)).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                    ForEach(document?.categories ?? []) { category in Toggle(category.name, isOn: Binding(get: { document?.journeys?[index].categoryIds.contains(category.id) == true }, set: { enabled in if enabled { document?.journeys?[index].categoryIds.append(category.id) } else { document?.journeys?[index].categoryIds.removeAll { $0 == category.id } } })) }
                    Button("Supprimer le parcours", role: .destructive) { document?.journeys?.remove(at: index) }
                }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            Button { if document?.journeys == nil { document?.journeys = [] }; document?.journeys?.append(.init(id: UUID(), name: "Nouveau parcours", description: "", accent: "ember", imageUrl: nil, order: (document?.journeys?.count ?? 0) + 1, isVisible: true, categoryIds: [], prerequisiteJourneyIds: [], tags: [])) } label: { Label("Ajouter un parcours", systemImage: "point.3.connected.trianglepath.dotted") }
        }
    }

    private var playerPanel: some View {
        adminPanel("Accueil, tutoriel & aide", symbol: "sparkles.rectangle.stack.fill") {
            if let intro = binding(\.intro) {
                Toggle("Introduction avant connexion", isOn: intro.enabled)
                Picker("Affichage", selection: intro.displayPolicy) { Text("À chaque lancement").tag("EveryLaunch"); Text("Une fois par version").tag("OncePerVersion"); Text("Première installation").tag("FirstInstall") }
                Toggle("Introduction skippable", isOn: intro.allowSkip)
            }
            Text("Scènes d’introduction").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(0..<(document?.intro.scenes.count ?? 0), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Sur-titre", text: bindingIntroScene(index, \.eyebrow, fallback: "")).textFieldStyle(.roundedBorder)
                    TextField("Titre", text: bindingIntroScene(index, \.title, fallback: "")).textFieldStyle(.roundedBorder)
                    TextField("Texte", text: bindingIntroScene(index, \.body, fallback: ""), axis: .vertical).textFieldStyle(.roundedBorder)
                    TextField("Image HTTPS", text: optionalIntroScene(index, \.imageUrl)).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            Button { document?.intro.scenes.append(.init(id: UUID(), eyebrow: document?.game.name ?? "GenEngine", title: "Nouvelle scène", body: "", imageUrl: nil, order: (document?.intro.scenes.count ?? 0) + 1)) } label: { Label("Ajouter une scène", systemImage: "plus") }
            Divider().overlay(.white.opacity(0.15))
            if let demo = binding(\.demo) {
                Toggle("Mode démo actif", isOn: demo.enabled)
                TextField("Slug du scénario de démo", text: demo.scenarioSlug).textFieldStyle(.roundedBorder)
                Stepper("Durée cible : \(demo.targetMinutes.wrappedValue) min", value: demo.targetMinutes, in: 1...120)
            }
            if let onboarding = binding(\.onboarding), let assistant = binding(\.assistantPolicy) {
                Toggle("Tutoriel actif", isOn: onboarding.enabled)
                Toggle("Tutoriel skippable", isOn: onboarding.allowSkip)
                Stepper("Version : \(onboarding.version.wrappedValue)", value: onboarding.version, in: 1...999)
                Stepper("Fréquence du compagnon : \(assistant.defaultFrequency.wrappedValue)/5", value: assistant.defaultFrequency, in: 0...5)
                Toggle("Compagnon proactif", isOn: assistant.proactive)
            }
            ForEach(0..<(document?.onboarding.steps.count ?? 0), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Étape", text: bindingOnboardingStep(index, \.title, fallback: "")).textFieldStyle(.roundedBorder)
                    TextField("Explication", text: bindingOnboardingStep(index, \.body, fallback: ""), axis: .vertical).textFieldStyle(.roundedBorder)
                    TextField("Cible UI", text: bindingOnboardingStep(index, \.target, fallback: "")).textFieldStyle(.roundedBorder)
                }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            Divider().overlay(.white.opacity(0.15))
            Toggle("Centre d’aide actif", isOn: Binding(get: { document?.help.enabled ?? false }, set: { document?.help.enabled = $0 }))
            ForEach(0..<(document?.help.articles.count ?? 0), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Article", text: bindingHelpArticle(index, \.title, fallback: "")).textFieldStyle(.roundedBorder)
                    TextField("Résumé", text: bindingHelpArticle(index, \.summary, fallback: "")).textFieldStyle(.roundedBorder)
                    TextField("Contenu", text: bindingHelpArticle(index, \.body, fallback: ""), axis: .vertical).textFieldStyle(.roundedBorder)
                }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var usersPanel: some View {
        adminPanel("Utilisateurs", symbol: "person.3.sequence.fill") {
            HStack { TextField("Rechercher un identifiant", text: $userSearch).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never); Button { Task { await state.searchUsers(userSearch) } } label: { Image(systemName: "magnifyingglass") } }
            Text("\(state.adminUsersTotal) comptes").font(.caption).foregroundStyle(GenEngineTheme.secondaryText)
            ForEach(state.adminUsers) { user in
                VStack(alignment: .leading, spacing: 9) {
                    HStack { VStack(alignment: .leading) { Text(user.userName).font(.headline); Text(user.externalProvider == nil ? "Compte GenEngine" : "Microsoft Entra ID").font(.caption).foregroundStyle(GenEngineTheme.secondaryText) }; Spacer(); Text(user.isActive ? "ACTIF" : "DÉSACTIVÉ").font(.caption2.bold()).foregroundStyle(user.isActive ? GenEngineTheme.verdigris : .red) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(user.roleAssignments) { assignment in
                                Text("\(assignment.roleName) · \(assignment.scope)")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.06), in: Capsule())
                            }
                        }
                    }
                    HStack { Button(user.isActive ? "Désactiver" : "Réactiver") { Task { await state.setUserActive(user, isActive: !user.isActive) } }; Button("Supprimer", role: .destructive) { Task { await state.deleteUser(user) } } }
                }.padding(14).background(GenEngineTheme.midnight.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
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
                        TextField("Portrait HTTPS", text: optionalArray(\.familiars, index, \.portraitUrl)).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                        TextField("Avatar HTTPS", text: optionalArray(\.familiars, index, \.avatarUrl)).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                        TextField("Arrière-plan HTTPS", text: optionalArray(\.familiars, index, \.backgroundUrl)).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                        TextField("Licence", text: optionalArray(\.familiars, index, \.license)).textFieldStyle(.roundedBorder)
                        if let urlString = document?.familiars[index].portraitUrl, let url = URL(string: urlString) { AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 16)) }
                        Button("Supprimer le familier", role: .destructive) { document?.familiars.remove(at: index) }
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
                if !role.isSystem { Button("Supprimer \(role.name)", role: .destructive) { Task { await state.deleteRole(role) } } }
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

    private var technicalPanel: some View {
        adminPanel("Environnement & diagnostic", symbol: "wrench.and.screwdriver.fill") {
            #if DEBUG
            @Bindable var state = state
            TextField("Identity URL", text: $state.endpoints.identity).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            TextField("Authoring URL", text: $state.endpoints.authoring).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            TextField("Play URL", text: $state.endpoints.play).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            TextField("Configuration URL", text: $state.endpoints.configuration).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            TextField("Player Experience URL", text: $state.endpoints.playerExperience).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            TextField("Organization URL", text: $state.endpoints.organization).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
            Button("Réinitialiser sur localhost") { state.endpoints = .local }
            Divider().overlay(.white.opacity(0.15))
            Text("Journal technique").font(.headline).foregroundStyle(GenEngineTheme.ivory)
            ForEach(Array(state.developerLog.prefix(12).enumerated()), id: \.offset) { _, line in Text(line).font(.caption.monospaced()).foregroundStyle(GenEngineTheme.secondaryText) }
            #else
            Text("Les outils d’environnement sont disponibles uniquement dans les builds Debug.").foregroundStyle(GenEngineTheme.secondaryText)
            #endif
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
    private func bindingJourney<Value>(_ index: Int, _ value: WritableKeyPath<JourneyDefinition, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?.journeys?[index][keyPath: value] ?? fallback }, set: { document?.journeys?[index][keyPath: value] = $0 }) }
    private func optionalJourney(_ index: Int, _ value: WritableKeyPath<JourneyDefinition, String?>) -> Binding<String> { Binding(get: { document?.journeys?[index][keyPath: value] ?? "" }, set: { document?.journeys?[index][keyPath: value] = $0.isEmpty ? nil : $0 }) }
    private func bindingOrganizationUnit<Value>(_ index: Int, _ value: WritableKeyPath<OrganizationUnitDefinition, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?.organization.units[index][keyPath: value] ?? fallback }, set: { document?.organization.units[index][keyPath: value] = $0 }) }
    private func bindingLanguageLabel(_ key: String) -> Binding<String> { Binding(get: { document?.language.labels[key] ?? "" }, set: { document?.language.labels[key] = $0 }) }
    private func bindingIntroScene<Value>(_ index: Int, _ value: WritableKeyPath<IntroSceneDefinition, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?.intro.scenes[index][keyPath: value] ?? fallback }, set: { document?.intro.scenes[index][keyPath: value] = $0 }) }
    private func optionalIntroScene(_ index: Int, _ value: WritableKeyPath<IntroSceneDefinition, String?>) -> Binding<String> { Binding(get: { document?.intro.scenes[index][keyPath: value] ?? "" }, set: { document?.intro.scenes[index][keyPath: value] = $0.isEmpty ? nil : $0 }) }
    private func bindingOnboardingStep<Value>(_ index: Int, _ value: WritableKeyPath<OnboardingStepDefinition, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?.onboarding.steps[index][keyPath: value] ?? fallback }, set: { document?.onboarding.steps[index][keyPath: value] = $0 }) }
    private func bindingHelpArticle<Value>(_ index: Int, _ value: WritableKeyPath<HelpArticleDefinition, Value>, fallback: Value) -> Binding<Value> { Binding(get: { document?.help.articles[index][keyPath: value] ?? fallback }, set: { document?.help.articles[index][keyPath: value] = $0 }) }
    private var defaultUnitType: String { switch document?.organizationType { case "School": "Class"; case "Company": "Team"; case "TrainingProvider": "Cohort"; default: "Group" } }
}

private enum CSVImportError: LocalizedError {
    case invalidHeader, invalidRow(Int)
    var errorDescription: String? { switch self { case .invalidHeader: "Le CSV doit contenir userId, unitId, kind et startsAt."; case let .invalidRow(row): "La ligne \(row) contient un identifiant, un type ou une date invalide." } }
}

private enum AdminSection: String, CaseIterable, Identifiable {
    case game, player, structure, operations, language, users, access, identity, intelligence, familiar, economy, technical
    var id: String { rawValue }
    var title: String { switch self { case .game: "Jeu"; case .player: "Accueil & aide"; case .language: "Libellés"; case .structure: "Catalogue"; case .operations: "Structures"; case .users: "Utilisateurs"; case .identity: "Auth"; case .intelligence: "IA"; case .familiar: "Familiers"; case .economy: "Économie"; case .access: "Rôles"; case .technical: "Technique" } }
    var symbol: String { switch self { case .game: "globe"; case .player: "sparkles.rectangle.stack"; case .language: "character.book.closed"; case .structure: "point.3.connected.trianglepath.dotted"; case .operations: "building.2.crop.circle"; case .users: "person.3.sequence"; case .identity: "key"; case .intelligence: "brain"; case .familiar: "wand.and.stars"; case .economy: "bag"; case .access: "person.badge.shield.checkmark"; case .technical: "wrench.and.screwdriver" } }
}
