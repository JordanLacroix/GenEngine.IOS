import Foundation

struct StorySummary: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let eyebrow: String
    let synopsis: String
    let duration: String
    let symbol: String
    let accent: StoryAccent
    let availability: Availability
    var scenarioID: UUID? = nil

    enum Availability: Hashable, Sendable { case demo, published(UUID), comingSoon }
}

extension StorySummary {
    init(published story: PublishedScenarioView) {
        self.init(
            id: story.versionId.uuidString.lowercased(),
            title: story.title,
            eyebrow: "Version \(story.versionNumber)",
            synopsis: story.description,
            duration: "\(story.estimatedMinutes) min",
            symbol: story.versionNumber.isMultiple(of: 2) ? "moon.stars.fill" : "book.pages.fill",
            accent: story.versionNumber.isMultiple(of: 2) ? .violet : .verdigris,
            availability: .published(story.versionId),
            scenarioID: story.scenarioId)
    }
}

enum StoryCatalog {
    static func unique(_ stories: [StorySummary]) -> [StorySummary] {
        var scenarioIDs = Set<UUID>()
        var normalizedTitles = Set<String>()

        return stories.filter { story in
            let title = story.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let scenarioID = story.scenarioID, !scenarioIDs.insert(scenarioID).inserted { return false }
            guard normalizedTitles.insert(title).inserted else { return false }
            return true
        }
    }
}

enum StoryAccent: Hashable, Sendable { case ember, verdigris, violet }

/// Nature d'une fin, dans la convention du contenu canonique « Le Diapason ».
/// Le moteur ne connaît qu'`isEnding` : cette distinction reste locale à la
/// démonstration et n'est jamais présentée comme un contrat serveur.
enum DemoOutcome: String, Equatable, Sendable { case accord, partielle, rupture }

struct DemoNode: Equatable, Sendable {
    let id: String
    /// Titre court de la scène, utilisé par le bilan et la carte de quête.
    let title: String
    let text: String
    let choices: [DemoChoice]
    var interaction: DemoInteraction? = nil
    /// Renseigné uniquement sur une scène terminale.
    var outcome: DemoOutcome? = nil
    var isEnding: Bool { choices.isEmpty }
}

struct DemoInteraction: Equatable, Sendable { let label: String; let hint: String; let symbol: String }

struct DemoChoice: Identifiable, Equatable, Sendable { let id: String; let text: String; let target: String; let posture: String }

enum DemoStory {
    static let summary = StorySummary(id: "diapason-demonstration", title: "Le Diapason — trois situations", eyebrow: "Lucidité · Courage · Transmission", synopsis: "2026. Vous êtes en alternance, sans autorité, et vous savez trois choses que personne au-dessus de vous ne sait.", duration: "12 min", symbol: "tuningfork", accent: .ember, availability: .demo)
    static let library: [StorySummary] = [
        summary,
        StorySummary(id: "identite-non-reconnue", title: "Identité non reconnue", eyebrow: "Bientôt · Discernement", synopsis: "Un score de 0,71 sous un seuil de 0,85 que personne n’a choisi. Ce n’est pas une décision, c’est un refus.", duration: "16 min", symbol: "person.crop.circle.badge.questionmark", accent: .verdigris, availability: .comingSoon),
        StorySummary(id: "la-competence-qui-s-efface", title: "La compétence qui s’efface", eyebrow: "Bientôt · Autonomie", synopsis: "Panne réseau, pas d’assistant, et un module que vous avez écrit en janvier.", duration: "13 min", symbol: "chart.line.downtrend.xyaxis", accent: .violet, availability: .comingSoon)
    ]
    static let openingNodeID = "accueil"
    static func node(id: String) -> DemoNode? { nodes[id] }

    /// Parcours déterministe de la fixture, dans l'ordre de découverte depuis la scène d'ouverture.
    static var orderedNodes: [DemoNode] {
        var visited = Set<String>()
        var queue = [openingNodeID]
        var head = 0
        var result: [DemoNode] = []
        while head < queue.count {
            let id = queue[head]
            head += 1
            guard visited.insert(id).inserted, let node = nodes[id] else { continue }
            result.append(node)
            queue.append(contentsOf: node.choices.map(\.target))
        }
        return result
    }

    /// Projette la fixture hors ligne dans la forme de contrat `NarrativeTree` afin que la
    /// démonstration et une session serveur partagent la même vue de graphe.
    /// Cette projection reste dans la frontière de démonstration et ne sert jamais de repli silencieux.
    static func narrativeTree(path: [String]) -> NarrativeTree {
        let visited = Set(path)
        let current = path.last ?? ""
        let nodes = orderedNodes.map { node in
            NarrativeTreeNode(
                id: node.id,
                text: node.title,
                isEnding: node.isEnding,
                state: node.id == current ? "Current" : (visited.contains(node.id) ? "Visited" : "Unexplored"))
        }
        let edges = orderedNodes.flatMap { node in
            node.choices.map { choice in
                NarrativeTreeEdge(
                    sourceNodeId: node.id,
                    targetNodeId: choice.target,
                    inputId: choice.id,
                    text: choice.text,
                    isAvailable: true,
                    evaluation: ConditionEvaluation(operator: "None", result: true, explanation: "Choix « \(choice.text) » — posture \(choice.posture).", children: []))
            }
        }
        return NarrativeTree(initialNodeId: openingNodeID, currentNodeId: current, nodes: nodes, edges: edges)
    }

    private static let nodes: [String: DemoNode] = [
        "accueil": DemoNode(
            id: "accueil",
            title: "Ce que vous avez, et que personne d\u{2019}autre n\u{2019}a",
            text: "Juillet 2026. Vous \u{00EA}tes en alternance dans une entreprise de quatre cents personnes depuis onze semaines. Vous n\u{2019}avez aucune autorit\u{00E9}, aucun budget, et personne ne vous demande votre avis. Vous avez en revanche une information de terrain que personne au-dessus de vous ne poss\u{00E8}de \u{2014} et c\u{2019}est vrai trois fois cette semaine, dans trois pi\u{00E8}ces diff\u{00E9}rentes.\n\nLe Diapason ne vous apprend pas \u{00E0} avoir raison. Il vous met dans la pi\u{00E8}ce, avec l\u{2019}heure qui tourne, et vous laisse d\u{00E9}couvrir ce que co\u{00FB}te le fait de le dire. Choisissez la situation par laquelle commencer : chacune se termine en quelques minutes, et aucune ne propose de bonne r\u{00E9}ponse \u{00E0} cocher.",
            choices: [
                DemoChoice(id: "situation-note", text: "Mardi, 8 h 12 \u{2014} une note de service que personne ne revendique", target: "note-arrivee", posture: "Lucidit\u{00E9}"),
                DemoChoice(id: "situation-reunion", text: "Jeudi, 14 h 00 \u{2014} neuf cadres, une recommandation, et un chiffre faux", target: "reunion-table", posture: "Courage"),
                DemoChoice(id: "situation-specification", text: "Lundi, 9 h 30 \u{2014} dix jours pour livrer, et une constante que personne n\u{2019}a d\u{00E9}cid\u{00E9}e", target: "spec-demande", posture: "Transmission")
            ]),

        "note-arrivee": DemoNode(
            id: "note-arrivee",
            title: "La note de service",
            text: "Mardi 8 h 12. Une note de deux pages attend dans la bo\u{00EE}te commune. Objet : \u{00AB} R\u{00E9}organisation du p\u{00E9}rim\u{00E8}tre Donn\u{00E9}es \u{2014} application imm\u{00E9}diate \u{00BB}. Les astreintes passent de trois \u{00E0} cinq personnes, deux prestataires ne seront pas reconduits, et la d\u{00E9}cision a \u{00E9}t\u{00E9} \u{00AB} valid\u{00E9}e coll\u{00E9}gialement \u{00BB}. Personne dans l\u{2019}open space n\u{2019}a l\u{2019}air de d\u{00E9}couvrir quoi que ce soit. Personne n\u{2019}a l\u{2019}air d\u{2019}y croire non plus.\n\nLe texte est parfait. Trop lisse, trop \u{00E9}quilibr\u{00E9}, avec cette mani\u{00E8}re de conclure chaque paragraphe sur une formule apaisante. En bas, pas de signature : une mention de service et un horodatage.",
            choices: [
                DemoChoice(id: "note-relayer", text: "Relayer la note dans le canal de l\u{2019}\u{00E9}quipe pour que tout le monde soit au courant", target: "fin-rupture-relais", posture: "Lucidit\u{00E9}"),
                DemoChoice(id: "note-verifier", text: "Chercher qui a r\u{00E9}ellement produit ce texte avant d\u{2019}en parler", target: "note-provenance", posture: "Lucidit\u{00E9}")
            ],
            interaction: .init(label: "Ouvrir les propri\u{00E9}t\u{00E9}s du fichier", hint: "Un document porte son origine dans ses m\u{00E9}tadonn\u{00E9}es ; la lire prend quatre secondes.", symbol: "doc.text.magnifyingglass")),
        "note-provenance": DemoNode(
            id: "note-provenance",
            title: "6 h 47, compte applicatif",
            text: "Cr\u{00E9}\u{00E9} ce matin \u{00E0} 6 h 47. Auteur : un compte applicatif. Vous remontez la cha\u{00EE}ne jusqu\u{2019}au fichier d\u{2019}entr\u{00E9}e \u{2014} un brouillon de cadrage qui pr\u{00E9}sente quatre hypoth\u{00E8}ses de r\u{00E9}organisation sans en retenir aucune. L\u{2019}hypoth\u{00E8}se 2 est celle de la note.\n\nLe mot \u{00AB} valid\u{00E9}e \u{00BB} n\u{2019}appara\u{00EE}t nulle part dans la source. Il est apparu quelque part entre le brouillon et les deux pages que quarante personnes viennent de lire. La note n\u{2019}est pas fausse : elle a rendu vraie une hypoth\u{00E8}se en la mettant en forme.",
            choices: [
                DemoChoice(id: "note-impression", text: "Le dire \u{00E0} la r\u{00E9}union : cette note ne vous inspire pas confiance", target: "fin-partielle-intuition", posture: "Lucidit\u{00E9}"),
                DemoChoice(id: "note-chaine", text: "\u{00C9}crire la cha\u{00EE}ne : fichier source, horodatage, compte producteur, hypoth\u{00E8}se retenue", target: "note-reunion", posture: "Lucidit\u{00E9}")
            ]),
        "note-reunion": DemoNode(
            id: "note-reunion",
            title: "Trois lignes et une capture d\u{2019}\u{00E9}cran",
            text: "Mardi 9 h 02, salle Sextant. La note est au premier point de l\u{2019}ordre du jour, trait\u{00E9}e comme un fait acquis. Votre tutrice ouvre le tour de table par la logistique : qui prend quelle semaine d\u{2019}astreinte.\n\nVous avez trois lignes et une capture d\u{2019}\u{00E9}cran. Vous pouvez les poser maintenant, avant que les semaines soient distribu\u{00E9}es \u{2014} ou attendre que quelqu\u{2019}un de mieux plac\u{00E9} remarque la m\u{00EA}me chose que vous.",
            choices: [
                DemoChoice(id: "note-poser", text: "Poser la cha\u{00EE}ne de provenance avant que les astreintes soient distribu\u{00E9}es", target: "fin-accord-provenance", posture: "Lucidit\u{00E9}"),
                DemoChoice(id: "note-attendre", text: "Attendre : quelqu\u{2019}un finira bien par v\u{00E9}rifier", target: "fin-rupture-inertie", posture: "Lucidit\u{00E9}")
            ]),
        "fin-accord-provenance": DemoNode(
            id: "fin-accord-provenance",
            title: "Une hypoth\u{00E8}se redevenue une hypoth\u{00E8}se",
            text: "Vous n\u{2019}avez pas dit que la note \u{00E9}tait fausse. Vous avez dit d\u{2019}o\u{00F9} elle venait, \u{00E0} quelle heure, produite par quoi, \u{00E0} partir de quel fichier, et que le mot \u{00AB} valid\u{00E9}e \u{00BB} n\u{2019}\u{00E9}tait dans aucune version de la source. Il a fallu quarante secondes, et personne n\u{2019}a eu \u{00E0} vous croire sur parole.\n\nLa r\u{00E9}union a chang\u{00E9} d\u{2019}objet. Les astreintes n\u{2019}ont pas \u{00E9}t\u{00E9} distribu\u{00E9}es ce matin-l\u{00E0}, et les deux prestataires ont appris leur reconduction avant midi. Ce que vous avez rendu opposable, ce n\u{2019}est pas votre doute : c\u{2019}est une date de cr\u{00E9}ation \u{00E0} 6 h 47.",
            choices: [],
            outcome: .accord),
        "fin-partielle-intuition": DemoNode(
            id: "fin-partielle-intuition",
            title: "Vous aviez raison, et cela n\u{2019}a pas suffi",
            text: "\u{00AB} Elle ne m\u{2019}inspire pas confiance \u{00BB} est une phrase inv\u{00E9}rifiable. Votre tutrice a r\u{00E9}pondu qu\u{2019}elle comprenait, qu\u{2019}elle regarderait, et la r\u{00E9}union a continu\u{00E9}. Elle a regard\u{00E9} le lendemain ; entre-temps les astreintes avaient \u{00E9}t\u{00E9} distribu\u{00E9}es et un prestataire avait cherch\u{00E9} un autre contrat.\n\nLe fond \u{00E9}tait juste. Ce qui manquait tenait en une ligne : l\u{2019}horodatage et le compte producteur, que vous aviez sous les yeux. Rejouez : la m\u{00EA}me sc\u{00E8}ne se gagne avec un fait dat\u{00E9} au lieu d\u{2019}une impression.",
            choices: [],
            outcome: .partielle),
        "fin-rupture-relais": DemoNode(
            id: "fin-rupture-relais",
            title: "Vous l\u{2019}avez rendue vraie",
            text: "Vous avez diffus\u{00E9} le document \u{00E0} quarante personnes en trois secondes, avec la seule chose qui lui manquait : quelqu\u{2019}un qui l\u{2019}assume. \u{00C0} 9 h, la note n\u{2019}\u{00E9}tait plus un fichier sans auteur, elle \u{00E9}tait \u{00AB} ce que l\u{2019}\u{00E9}quipe a re\u{00E7}u ce matin \u{00BB}. Les astreintes ont \u{00E9}t\u{00E9} distribu\u{00E9}es dessus. Deux prestataires ne l\u{2019}ont pas \u{00E9}t\u{00E9}.\n\nL\u{2019}enqu\u{00EA}te interne a dur\u{00E9} six jours et n\u{2019}a d\u{00E9}sign\u{00E9} personne, parce qu\u{2019}il n\u{2019}y avait personne \u{00E0} d\u{00E9}signer : une hypoth\u{00E8}se de cadrage, un compte applicatif \u{00E0} 6 h 47, et une cha\u{00EE}ne humaine qui n\u{2019}a rien v\u{00E9}rifi\u{00E9}. Il n\u{2019}y a rien \u{00E0} rattraper depuis ce point. Reprenez au mardi matin ; la note attend toujours dans la bo\u{00EE}te commune.",
            choices: [],
            outcome: .rupture),
        "fin-rupture-inertie": DemoNode(
            id: "fin-rupture-inertie",
            title: "Personne n\u{2019}a v\u{00E9}rifi\u{00E9} \u{00E0} votre place",
            text: "Vous avez attendu. Neuf personnes ont lu la m\u{00EA}me note que vous et aucune n\u{2019}a ouvert les propri\u{00E9}t\u{00E9}s du fichier \u{2014} non par n\u{00E9}gligence, mais parce qu\u{2019}un texte propre et dat\u{00E9} ne donne aucune raison de le faire. Vous \u{00E9}tiez la seule personne \u{00E0} en avoir une.\n\n\u{00C0} 11 h 40, le planning d\u{2019}astreintes \u{00E9}tait sign\u{00E9} et la r\u{00E9}organisation act\u{00E9}e. Une d\u{00E9}cision que personne n\u{2019}avait prise est devenue une d\u{00E9}cision que personne ne peut plus d\u{00E9}faire. Reprenez : la fen\u{00EA}tre o\u{00F9} votre information valait quelque chose durait cinquante minutes.",
            choices: [],
            outcome: .rupture),

        "reunion-table": DemoNode(
            id: "reunion-table",
            title: "La r\u{00E9}union o\u{00F9} personne ne doute",
            text: "Jeudi 14 h 00, neuf cadres et un projecteur. La recommandation a \u{00E9}t\u{00E9} produite \u{00E0} partir de quatre-vingts documents internes. Elle est claire, chiffr\u{00E9}e, et les neuf personnes autour de la table l\u{2019}ont lue. Trois ont dit qu\u{2019}elle recoupait leur intuition. Le comit\u{00E9} valide dans vingt minutes.\n\nLe point 3 dimensionne le r\u{00E9}seau logistique sur quatre entrep\u{00F4}ts. Il y en a cinq depuis janvier. Vous le savez parce que vous avez c\u{00E2}bl\u{00E9} l\u{2019}int\u{00E9}gration du cinqui\u{00E8}me en mars, seule, pendant trois semaines. Vous \u{00EA}tes la seule personne du b\u{00E2}timent \u{00E0} l\u{2019}avoir fait.",
            choices: [
                DemoChoice(id: "reunion-silence", text: "Se taire : neuf cadres exp\u{00E9}riment\u{00E9}s ont valid\u{00E9}, l\u{2019}erreur est probablement de votre c\u{00F4}t\u{00E9}", target: "fin-rupture-silence", posture: "Courage"),
                DemoChoice(id: "reunion-parler", text: "Prendre la parole maintenant, avant le vote", target: "reunion-formulation", posture: "Courage")
            ],
            interaction: .init(label: "Relire le point 3", hint: "Le raisonnement a \u{00E9}t\u{00E9} v\u{00E9}rifi\u{00E9} par neuf personnes. Ses entr\u{00E9}es ne l\u{2019}ont \u{00E9}t\u{00E9} par personne.", symbol: "text.magnifyingglass")),
        "reunion-formulation": DemoNode(
            id: "reunion-formulation",
            title: "Tout se joue sur la formulation",
            text: "Vous levez la main. La salle se tourne vers vous et vous disposez d\u{2019}environ six secondes avant que l\u{2019}attention retombe. Ce que vous allez dire ne sera pas jug\u{00E9} sur sa justesse, mais sur ce qu\u{2019}il oblige la salle \u{00E0} faire.\n\nDeux phrases vous viennent. L\u{2019}une nomme un responsable. L\u{2019}autre nomme un \u{00E9}cart.",
            choices: [
                DemoChoice(id: "reunion-accuser", text: "\u{00AB} Le point 3 est faux, personne n\u{2019}a v\u{00E9}rifi\u{00E9} les donn\u{00E9}es d\u{2019}entr\u{00E9}e. \u{00BB}", target: "reunion-repli", posture: "Courage"),
                DemoChoice(id: "reunion-ecart", text: "\u{00AB} Le point 3 dimensionne sur quatre entrep\u{00F4}ts. Nous en exploitons cinq depuis janvier. \u{00BB}", target: "reunion-verification", posture: "Courage")
            ]),
        "reunion-verification": DemoNode(
            id: "reunion-verification",
            title: "Quinze secondes de silence",
            text: "Personne ne vous contredit, parce qu\u{2019}un nombre d\u{2019}entrep\u{00F4}ts n\u{2019}est pas une opinion. Le directeur des op\u{00E9}rations ouvre son t\u{00E9}l\u{00E9}phone et confirme. La question qui suit n\u{2019}est pas \u{00AB} avez-vous raison \u{00BB} mais \u{00AB} qu\u{2019}est-ce qu\u{2019}on fait des vingt minutes qui restent \u{00BB}.\n\nVotre tutrice vous regarde. Elle peut reprendre le sujet \u{00E0} son compte pour la suite du comit\u{00E9} : ce serait plus confortable pour vous, et plus audible pour eux.",
            choices: [
                DemoChoice(id: "reunion-porter", text: "Porter vous-m\u{00EA}me le constat : vous \u{00EA}tes la seule \u{00E0} conna\u{00EE}tre l\u{2019}int\u{00E9}gration", target: "fin-accord-ecart", posture: "Courage"),
                DemoChoice(id: "reunion-deleguer", text: "Laisser votre tutrice reprendre le sujet", target: "fin-rupture-sous-traitance", posture: "Courage")
            ]),
        "reunion-repli": DemoNode(
            id: "reunion-repli",
            title: "Vous avez nomm\u{00E9} un coupable",
            text: "\u{00AB} Personne n\u{2019}a v\u{00E9}rifi\u{00E9} \u{00BB} met neuf personnes en position de se d\u{00E9}fendre, et la premi\u{00E8}re r\u{00E9}ponse arrive tout de suite : la m\u{00E9}thode a \u{00E9}t\u{00E9} valid\u{00E9}e, les sources sont internes, et vous \u{00EA}tes ici depuis onze semaines. L\u{2019}\u{00E9}change d\u{00E9}rive sur votre l\u{00E9}gitimit\u{00E9} pendant deux minutes ; le point 3 n\u{2019}est plus au centre.\n\nIl vous reste douze minutes et un cr\u{00E9}dit tr\u{00E8}s entam\u{00E9}. Vous pouvez encore poser le seul \u{00E9}l\u{00E9}ment que personne ne peut vous retirer.",
            choices: [
                DemoChoice(id: "reunion-reformuler", text: "Revenir au fait : quatre entrep\u{00F4}ts au point 3, cinq en exploitation", target: "fin-partielle-reformulation", posture: "Courage")
            ]),
        "fin-accord-ecart": DemoNode(
            id: "fin-accord-ecart",
            title: "Un comit\u{00E9} qui ne vote pas",
            text: "Le comit\u{00E9} n\u{2019}a pas vot\u{00E9}. Le point 3 est reparti en r\u{00E9}vision avec la seule personne capable de dire ce que change le cinqui\u{00E8}me entrep\u{00F4}t sur les flux \u{2014} vous. Ce n\u{2019}\u{00E9}tait pas du courage au sens o\u{00F9} on l\u{2019}entend d\u{2019}habitude : vous avez choisi le moment (avant le vote), la forme (un \u{00E9}cart v\u{00E9}rifiable) et le destinataire (la salle enti\u{00E8}re, pas un couloir).\n\nLa recommandation n\u{2019}\u{00E9}tait pas mauvaise. Neuf personnes en avaient v\u{00E9}rifi\u{00E9} le raisonnement, et aucune les entr\u{00E9}es. C\u{2019}est le d\u{00E9}faut le plus courant et le plus cher de 2026.",
            choices: [],
            outcome: .accord),
        "fin-partielle-reformulation": DemoNode(
            id: "fin-partielle-reformulation",
            title: "Rattrap\u{00E9} de justesse",
            text: "Le fait a fini par passer et le point 3 est reparti en r\u{00E9}vision. Mais il aura fallu douze minutes, une discussion sur votre anciennet\u{00E9} et l\u{2019}intervention de votre tutrice pour que la salle y revienne. Vous avez d\u{00E9}pens\u{00E9} pour \u{00EA}tre \u{00E9}cout\u{00E9}e un cr\u{00E9}dit que vous n\u{2019}aurez pas la prochaine fois.\n\nLa diff\u{00E9}rence entre les deux phrases ne tenait pas au courage : elle tenait \u{00E0} ce qu\u{2019}elles obligeaient la salle \u{00E0} faire \u{2014} se d\u{00E9}fendre, ou v\u{00E9}rifier. Rejouez la sc\u{00E8}ne en ouvrant par l\u{2019}\u{00E9}cart.",
            choices: [],
            outcome: .partielle),
        "fin-rupture-silence": DemoNode(
            id: "fin-rupture-silence",
            title: "L\u{2019}exp\u{00E9}rience suppos\u{00E9}e des autres",
            text: "Le comit\u{00E9} a valid\u{00E9} \u{00E0} l\u{2019}unanimit\u{00E9}. Le dimensionnement est parti en appel d\u{2019}offres sur quatre entrep\u{00F4}ts, le cinqui\u{00E8}me a \u{00E9}t\u{00E9} trait\u{00E9} en exception manuelle pendant huit mois, et deux personnes ont \u{00E9}t\u{00E9} recrut\u{00E9}es pour tenir cette exception. Personne ne saura jamais que la d\u{00E9}cision reposait sur une donn\u{00E9}e de d\u{00E9}cembre.\n\nVous vous \u{00EA}tes tue parce que neuf personnes exp\u{00E9}riment\u{00E9}es \u{00E9}taient d\u{2019}accord. Elles \u{00E9}taient d\u{2019}accord sur un raisonnement, pas sur ses entr\u{00E9}es, et vous \u{00E9}tiez la seule personne du b\u{00E2}timent \u{00E0} conna\u{00EE}tre les entr\u{00E9}es. La situation ne se rattrape pas apr\u{00E8}s le vote. Reprenez avant.",
            choices: [],
            outcome: .rupture),
        "fin-rupture-sous-traitance": DemoNode(
            id: "fin-rupture-sous-traitance",
            title: "Le courage sous-trait\u{00E9}",
            text: "Votre tutrice a repris le sujet, de bonne foi, avec ce qu\u{2019}elle en savait \u{2014} c\u{2019}est-\u{00E0}-dire un nombre. Interrog\u{00E9}e sur les flux inter-sites, elle n\u{2019}a pas pu r\u{00E9}pondre. Faute de r\u{00E9}ponse dans la salle, le comit\u{00E9} a estim\u{00E9} l\u{2019}\u{00E9}cart mineur et maintenu la recommandation avec une r\u{00E9}serve au proc\u{00E8}s-verbal.\n\nLa r\u{00E9}serve n\u{2019}a jamais \u{00E9}t\u{00E9} instruite. Vous aviez l\u{2019}information ; vous l\u{2019}avez confi\u{00E9}e \u{00E0} quelqu\u{2019}un qui ne pouvait pas la d\u{00E9}fendre. Une objection port\u{00E9}e par la mauvaise personne co\u{00FB}te autant qu\u{2019}une objection tue. Reprenez.",
            choices: [],
            outcome: .rupture),

        "spec-demande": DemoNode(
            id: "spec-demande",
            title: "La sp\u{00E9}cification avant le code",
            text: "Lundi 9 h 30, dix jours. La demande fait trois phrases : \u{00AB} Permettre au client d\u{2019}annuler une commande et d\u{2019}\u{00EA}tre rembours\u{00E9} automatiquement. Pr\u{00E9}voir les cas partiels. Livraison dans dix jours. \u{00BB} Vous la collez dans l\u{2019}assistant pour cadrer. Avant que vous ayez fini de lire, l\u{2019}impl\u{00E9}mentation compl\u{00E8}te est l\u{00E0} \u{2014} services, migrations, gestion d\u{2019}erreurs, tests.\n\nElle est bonne. Elle est coh\u{00E9}rente. En haut du fichier de configuration, une ligne : REFUND_WINDOW_HOURS = 24. Personne n\u{2019}a d\u{00E9}cid\u{00E9} vingt-quatre heures. Ce nombre n\u{2019}est nulle part dans la demande.",
            choices: [
                DemoChoice(id: "spec-coder", text: "Partir de ce code : il est propre, et dix jours c\u{2019}est court", target: "fin-rupture-constante", posture: "Transmission"),
                DemoChoice(id: "spec-ecrire", text: "Fermer l\u{2019}\u{00E9}diteur et \u{00E9}crire d\u{2019}abord ce qui doit \u{00EA}tre vrai", target: "spec-affirmations", posture: "Transmission")
            ],
            interaction: .init(label: "Chercher l\u{2019}origine de la constante", hint: "Une valeur par d\u{00E9}faut recopi\u{00E9}e d\u{2019}une documentation devient une d\u{00E9}cision politique sans d\u{00E9}cideur.", symbol: "number.square")),
        "spec-affirmations": DemoNode(
            id: "spec-affirmations",
            title: "Ce qui doit \u{00EA}tre vrai",
            text: "Vous \u{00E9}crivez neuf affirmations v\u{00E9}rifiables, sans une ligne de code. \u{00AB} Un remboursement int\u{00E9}gral est possible tant que la commande n\u{2019}est pas exp\u{00E9}di\u{00E9}e. \u{00BB} \u{00AB} Au-del\u{00E0}, le remboursement est partiel et proratis\u{00E9} sur les articles non exp\u{00E9}di\u{00E9}s. \u{00BB} \u{00AB} La fen\u{00EA}tre de remboursement est de quarante-huit heures. \u{00BB} \u{2014} celle-l\u{00E0}, vous \u{00EA}tes all\u{00E9}e la demander au m\u{00E9}tier, qui a r\u{00E9}pondu quarante-huit sans h\u{00E9}siter une seconde.\n\nNeuf affirmations, dont trois qu\u{2019}aucun mod\u{00E8}le ne pouvait deviner : elles ne sont \u{00E9}crites nulle part, elles vivent dans la t\u{00EA}te de deux personnes au service client.",
            choices: [
                DemoChoice(id: "spec-signer", text: "Faire signer les neuf affirmations par le m\u{00E9}tier avant d\u{2019}\u{00E9}crire quoi que ce soit", target: "spec-tests", posture: "Transmission"),
                DemoChoice(id: "spec-classer", text: "Classer le document et commencer \u{00E0} d\u{00E9}velopper : le temps presse", target: "fin-rupture-document-mort", posture: "Transmission")
            ],
            interaction: .init(label: "Nommer le cas limite absent", hint: "Votre propre sp\u{00E9}cification en oublie un : la commande exp\u{00E9}di\u{00E9}e puis refus\u{00E9}e \u{00E0} la livraison. Le sc\u{00E9}nario complet vous demande de le formuler vous-m\u{00EA}me, en texte libre.", symbol: "text.cursor")),
        "spec-tests": DemoNode(
            id: "spec-tests",
            title: "Trois r\u{00E8}gles \u{00E9}chouent",
            text: "Les neuf affirmations sont devenues neuf tests avant la premi\u{00E8}re ligne d\u{2019}impl\u{00E9}mentation. Vous laissez ensuite l\u{2019}assistant proposer le code : il produit \u{00E0} peu pr\u{00E8}s la m\u{00EA}me chose que lundi, en quatre minutes.\n\nSix tests passent. Trois \u{00E9}chouent \u{2014} exactement les trois r\u{00E8}gles m\u{00E9}tier qu\u{2019}aucun mod\u{00E8}le ne pouvait deviner, dont la fen\u{00EA}tre \u{00E0} quarante-huit heures. La suite de tests vient de faire ce qu\u{2019}aucune relecture humaine n\u{2019}aurait fait \u{00E0} cette vitesse : dire non, pr\u{00E9}cis\u{00E9}ment, \u{00E0} un code convaincant.",
            choices: [
                DemoChoice(id: "spec-autorite", text: "Corriger jusqu\u{2019}au vert, et faire de la suite l\u{2019}autorit\u{00E9} du projet", target: "fin-accord-specification", posture: "Transmission"),
                DemoChoice(id: "spec-recette", text: "Noter les trois \u{00E9}carts et les traiter \u{00E0} la recette, avec le reste", target: "fin-partielle-recette", posture: "Transmission")
            ]),
        "fin-accord-specification": DemoNode(
            id: "fin-accord-specification",
            title: "Ce qui reste rare n\u{2019}est plus le code",
            text: "Livr\u{00E9} en huit jours au lieu de dix. Ce n\u{2019}est pas l\u{2019}impl\u{00E9}mentation qui a pris du temps \u{2014} elle en a pris quatre minutes \u{2014} mais les six heures pass\u{00E9}es \u{00E0} \u{00E9}crire ce qui devait \u{00EA}tre vrai et \u{00E0} le faire signer. Ces six heures sont le seul endroit du projet o\u{00F9} une d\u{00E9}cision a \u{00E9}t\u{00E9} prise.\n\nDeux mois plus tard, une \u{00E9}volution est demand\u{00E9}e. Le code a \u{00E9}t\u{00E9} r\u{00E9}\u{00E9}crit deux fois depuis ; les neuf affirmations, elles, sont toujours l\u{00E0}, toujours ex\u{00E9}cut\u{00E9}es \u{00E0} chaque int\u{00E9}gration. C\u{2019}est exactement l\u{00E0} que vit le Spec Driven Development : l\u{2019}impl\u{00E9}mentation est devenue instantan\u{00E9}e, la d\u{00E9}cision \u{00E9}crite ne l\u{2019}est pas.",
            choices: [],
            outcome: .accord),
        "fin-partielle-recette": DemoNode(
            id: "fin-partielle-recette",
            title: "Une sp\u{00E9}cification que rien n\u{2019}ex\u{00E9}cute",
            text: "Les trois \u{00E9}carts sont arriv\u{00E9}s en recette avec vingt-deux autres points. Deux ont \u{00E9}t\u{00E9} corrig\u{00E9}s ; le troisi\u{00E8}me \u{2014} la fen\u{00EA}tre de remboursement \u{2014} a \u{00E9}t\u{00E9} jug\u{00E9} mineur et report\u{00E9}. Il est parti en production \u{00E0} vingt-quatre heures. Le service client l\u{2019}a d\u{00E9}couvert en quatre jours, sur onze dossiers.\n\nVous aviez la bonne sp\u{00E9}cification, \u{00E9}crite et sign\u{00E9}e. Elle est rest\u{00E9}e un document. Ce qui la rend opposable, c\u{2019}est qu\u{2019}elle \u{00E9}choue automatiquement quand le code s\u{2019}en \u{00E9}carte, et pas plus tard. Rejouez la fin.",
            choices: [],
            outcome: .partielle),
        "fin-rupture-constante": DemoNode(
            id: "fin-rupture-constante",
            title: "Vingt-quatre heures que personne n\u{2019}a d\u{00E9}cid\u{00E9}es",
            text: "Vous avez livr\u{00E9} en six jours. Trente-huit jours plus tard, r\u{00E9}union de crise : la fen\u{00EA}tre de remboursement est de vingt-quatre heures, le m\u{00E9}tier l\u{2019}a toujours fix\u{00E9}e \u{00E0} quarante-huit, et deux cent dix clients ont \u{00E9}t\u{00E9} refus\u{00E9}s \u{00E0} tort. Interrog\u{00E9}e sur l\u{2019}origine de la r\u{00E8}gle, vous avez expliqu\u{00E9} qu\u{2019}elle vous avait sembl\u{00E9} raisonnable.\n\nC\u{2019}est exact : elle l\u{2019}\u{00E9}tait. Elle venait d\u{2019}un exemple de documentation, recopi\u{00E9} par un mod\u{00E8}le, valid\u{00E9} par personne, et vous l\u{2019}avez rationalis\u{00E9}e apr\u{00E8}s coup au lieu de chercher qui l\u{2019}avait d\u{00E9}cid\u{00E9}e. Un d\u{00E9}faut de ce type ne se r\u{00E9}pare pas en production, il se pr\u{00E9}vient avant la premi\u{00E8}re ligne. Reprenez au lundi matin.",
            choices: [],
            outcome: .rupture),
        "fin-rupture-document-mort": DemoNode(
            id: "fin-rupture-document-mort",
            title: "Sign\u{00E9}, class\u{00E9}, jamais ex\u{00E9}cut\u{00E9}",
            text: "Vos neuf affirmations \u{00E9}taient justes, et le document existe toujours, \u{00E0} jour, dans l\u{2019}espace partag\u{00E9}. Le code livr\u{00E9} en contredit quatre. Personne ne s\u{2019}en est aper\u{00E7}u, parce qu\u{2019}entre le document et le code il n\u{2019}y avait rien : aucun test ne reliait l\u{2019}un \u{00E0} l\u{2019}autre.\n\nVous avez transmis un raisonnement \u{00E0} des humains occup\u{00E9}s au lieu de le transmettre \u{00E0} une machine qui v\u{00E9}rifie. C\u{2019}est la forme la plus co\u{00FB}teuse de bonne intention : elle a l\u{2019}air d\u{2019}un travail fait. Reprenez, et transformez les affirmations en tests avant de d\u{00E9}velopper.",
            choices: [],
            outcome: .rupture)
    ]
}
