import Foundation

/// Les six services appelés directement par le client.
///
/// Le port par défaut est celui du déploiement de référence documenté dans le dépôt
/// backend ; il ne sert qu'à préremplir le mode groupé, jamais à deviner une adresse.
enum ServiceKind: String, CaseIterable, Identifiable, Sendable {
    case authoring
    case play
    case identity
    case configuration
    case playerExperience
    case organization

    var id: String { rawValue }

    var title: String {
        switch self {
        case .authoring: "Authoring"
        case .play: "Play"
        case .identity: "Identity"
        case .configuration: "Configuration"
        case .playerExperience: "Player Experience"
        case .organization: "Organization"
        }
    }

    /// Ce que le service porte, en français, pour que le réglage reste compréhensible
    /// par quelqu'un qui installe l'application sans connaître l'architecture.
    var purpose: String {
        switch self {
        case .authoring: "Le catalogue publié et l'import des scénarios."
        case .play: "Les sessions de jeu et la topologie des versions publiées."
        case .identity: "La connexion, les comptes, les rôles et les permissions."
        case .configuration: "Le paramétrage du jeu et le dictionnaire de libellés."
        case .playerExperience: "Le bootstrap joueur, le journal et le familier."
        case .organization: "Les unités, les périodes et les affectations de contenu."
        }
    }

    var defaultPort: Int {
        switch self {
        case .authoring: 5201
        case .play: 5202
        case .identity: 5203
        case .configuration: 5204
        case .playerExperience: 5205
        case .organization: 5206
        }
    }

    var symbol: String {
        switch self {
        case .authoring: "square.and.pencil"
        case .play: "play.circle"
        case .identity: "person.badge.key"
        case .configuration: "slider.horizontal.3"
        case .playerExperience: "person.crop.circle.badge.checkmark"
        case .organization: "building.2"
        }
    }

    var keyPath: WritableKeyPath<ServiceEndpoints, String> {
        switch self {
        case .authoring: \.authoring
        case .play: \.play
        case .identity: \.identity
        case .configuration: \.configuration
        case .playerExperience: \.playerExperience
        case .organization: \.organization
        }
    }
}

/// Brouillon d'adressage manipulé par l'écran de paramètres.
///
/// Deux modes coexistent parce que les deux déploiements existent : une machine unique
/// qui expose les six services sur des ports différents, et six déploiements distincts.
/// Le brouillon ne touche jamais `EndpointStore` tant qu'il n'est pas validé.
struct EndpointDraft: Equatable, Sendable {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case grouped
        case individual

        var id: String { rawValue }

        var title: String {
            switch self {
            case .grouped: "Groupé"
            case .individual: "Unitaire"
            }
        }

        var explanation: String {
            switch self {
            case .grouped: "Une seule machine expose les six services : un hôte commun, un port par service."
            case .individual: "Les services sont déployés séparément : une adresse complète par service."
            }
        }
    }

    var mode: Mode
    var scheme: String
    var host: String
    var ports: [ServiceKind: String]
    var urls: [ServiceKind: String]

    static let schemes = ["https", "http"]

    /// Reconstruit un brouillon depuis l'adressage effectif. Le mode groupé n'est proposé
    /// que si les six adresses partagent réellement schéma et hôte : autrement, présenter
    /// un hôte commun mentirait sur la configuration en place.
    init(_ endpoints: ServiceEndpoints) {
        var urls: [ServiceKind: String] = [:]
        var ports: [ServiceKind: String] = [:]
        for service in ServiceKind.allCases {
            urls[service] = endpoints[keyPath: service.keyPath]
        }
        let components = ServiceKind.allCases.map { URLComponents(string: urls[$0] ?? "") }
        let schemes = Set(components.map { $0?.scheme?.lowercased() ?? "" })
        let hosts = Set(components.map { $0?.host ?? "" })
        for (service, component) in zip(ServiceKind.allCases, components) {
            ports[service] = (component?.port).map(String.init) ?? String(service.defaultPort)
        }
        let isGrouped = schemes.count == 1 && hosts.count == 1 && !(hosts.first ?? "").isEmpty
        self.mode = isGrouped ? .grouped : .individual
        self.scheme = schemes.count == 1 ? (schemes.first ?? "https") : "https"
        self.host = hosts.count == 1 ? (hosts.first ?? "") : ""
        self.ports = ports
        self.urls = urls
    }

    /// Change de mode **sans perdre la saisie**.
    ///
    /// Les deux modes tenaient deux jeux d'état disjoints que rien ne synchronisait :
    /// six URLs saisies en unitaire disparaissaient au premier contact avec le segment
    /// « Groupé », et l'enregistrement repartait sur les valeurs d'origine sans rien dire.
    /// Le passage reporte donc explicitement ce qui est à l'écran vers le mode d'arrivée.
    mutating func switchMode(to newMode: Mode) {
        guard newMode != mode else { return }
        switch newMode {
        case .individual:
            // Ce que le mode groupé affichait devient le point de départ du mode unitaire —
            // mais un mode groupé vide (hôte non renseigné) n'écrase rien : sinon un aller
            // et retour par le segment suffisait à effacer six adresses valides.
            for service in ServiceKind.allCases {
                let derived = resolvedURL(for: service)
                if !derived.isEmpty { urls[service] = derived }
            }
        case .grouped:
            // Si les six URLs partagent schéma et hôte, le mode groupé les adopte plutôt
            // que de ressusciter un hôte périmé. Sinon la saisie unitaire reste intacte
            // dans `urls` : revenir en arrière la retrouve telle quelle.
            let components = ServiceKind.allCases.map { URLComponents(string: (urls[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) }
            let schemes = Set(components.map { $0?.scheme?.lowercased() ?? "" })
            let hosts = Set(components.map { $0?.host ?? "" })
            if schemes.count == 1, hosts.count == 1, let host = hosts.first, !host.isEmpty {
                self.host = host
                self.scheme = schemes.first.flatMap { EndpointDraft.schemes.contains($0) ? $0 : nil } ?? scheme
                for (service, component) in zip(ServiceKind.allCases, components) {
                    ports[service] = (component?.port).map(String.init) ?? ports[service] ?? String(service.defaultPort)
                }
            }
        }
        mode = newMode
    }

    /// Adresse résultante d'un service, dans le mode courant. C'est la valeur testée
    /// par le contrôle de connectivité et celle qui sera enregistrée.
    func resolvedURL(for service: ServiceKind) -> String {
        switch mode {
        case .grouped:
            let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else { return "" }
            let port = ports[service]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return port.isEmpty ? "\(scheme)://\(host)" : "\(scheme)://\(host):\(port)"
        case .individual:
            return (urls[service] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Première raison de refus, ou `nil` si le brouillon est enregistrable.
    /// Une adresse invalide échoue explicitement plutôt que d'être corrigée en silence.
    var validationMessage: String? {
        switch mode {
        case .grouped:
            let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
            if host.isEmpty { return "Renseignez l’hôte commun des services." }
            if !EndpointDraft.schemes.contains(scheme) { return "Le schéma doit être https ou http." }
            // Coller « 192.168.1.10:5201 » dans le champ Hôte est un geste naturel ; il
            // produisait « https://192.168.1.10:5201:5201 », non parsable, et six services
            // injoignables sans un mot d'explication.
            if host.contains("/") || host.contains(" ") || host.contains(":") {
                return "L’hôte ne doit contenir ni espace, ni chemin, ni port : seulement un nom de machine ou une adresse IP. Le port se saisit dans la colonne de droite."
            }
            var seenPorts: [Int: ServiceKind] = [:]
            for service in ServiceKind.allCases {
                let raw = ports[service]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // Un port vide donnait six adresses identiques : les six services ne peuvent
                // pas répondre sur la même origine, l'application aurait tapé à côté partout.
                guard !raw.isEmpty else { return "Renseignez le port de \(service.title)." }
                guard let port = Int(raw), (1...65_535).contains(port) else {
                    return "Le port de \(service.title) doit être un nombre entre 1 et 65535."
                }
                if let other = seenPorts[port] {
                    return "\(other.title) et \(service.title) ne peuvent pas partager le port \(port)."
                }
                seenPorts[port] = service
            }
            // Dernier filet : l'adresse produite doit réellement se parser, comme en unitaire.
            for service in ServiceKind.allCases {
                guard let components = URLComponents(string: resolvedURL(for: service)),
                      let scheme = components.scheme?.lowercased(),
                      EndpointDraft.schemes.contains(scheme),
                      !(components.host ?? "").isEmpty
                else { return "L’adresse produite pour \(service.title) n’est pas une URL valide." }
            }
        case .individual:
            for service in ServiceKind.allCases {
                let value = resolvedURL(for: service)
                if value.isEmpty { return "Renseignez l’adresse complète de \(service.title)." }
                guard let components = URLComponents(string: value),
                      let scheme = components.scheme?.lowercased(),
                      EndpointDraft.schemes.contains(scheme),
                      !(components.host ?? "").isEmpty
                else { return "L’adresse de \(service.title) doit être une URL https ou http complète." }
            }
        }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

    /// Adressage à enregistrer. `nil` tant que le brouillon n'est pas valide.
    func endpoints() -> ServiceEndpoints? {
        guard isValid else { return nil }
        var result = ServiceEndpoints.local
        for service in ServiceKind.allCases {
            result[keyPath: service.keyPath] = resolvedURL(for: service)
        }
        return result
    }
}

/// Résultat d'un contrôle de connectivité.
///
/// Le client ne connaît aucun contrat de santé publié par les services : une réponse HTTP,
/// quelle qu'elle soit, prouve seulement que l'adresse est joignable. C'est exactement ce
/// que l'écran annonce, sans prétendre valider le service lui-même.
enum ServiceReachability: Equatable, Sendable {
    case unknown
    case checking
    case reachable(String)
    case unreachable(String)

    var label: String {
        switch self {
        case .unknown: "Non testé"
        case .checking: "Test en cours…"
        case let .reachable(detail): "Joignable · \(detail)"
        case let .unreachable(detail): "Injoignable · \(detail)"
        }
    }

    var symbol: String {
        switch self {
        case .unknown: "circle.dashed"
        case .checking: "clock"
        case .reachable: "checkmark.circle.fill"
        case .unreachable: "exclamationmark.triangle.fill"
        }
    }
}

/// Sonde de connectivité indépendante de `GenEngineAPI` : elle doit fonctionner avant
/// toute authentification et sans jeton.
struct EndpointProbe: Sendable {
    var timeout: TimeInterval = 6

    func check(_ urlString: String) async -> ServiceReachability {
        guard let url = URL(string: urlString), url.host != nil else {
            return .unreachable("adresse invalide")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = timeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .reachable("réponse reçue") }
            return .reachable("HTTP \(http.statusCode)")
        } catch is CancellationError {
            return .unknown
        } catch {
            return .unreachable((error as NSError).localizedDescription)
        }
    }
}
