import CoreGraphics
import Foundation

enum PlayerExperiencePresentation {
    /// Les six postures de la configuration de référence « Le Diapason ».
    static let diapasonPostures = ["Lucidité", "Discernement", "Arbitrage", "Courage", "Transmission", "Autonomie"]

    /// Titre du bilan de démonstration, selon la nature de la fin atteinte.
    static func demoOutcomeTitle(_ outcome: DemoOutcome?) -> String {
        switch outcome {
        case .accord: "Vous avez tenu la posture, et vous savez pourquoi."
        case .partielle: "Le résultat est là ; le raisonnement ne l’est pas."
        case .rupture: "La situation ne peut plus être rattrapée."
        case nil: "Chemin accompli"
        }
    }

    static func demoOutcomeNote(_ outcome: DemoOutcome?) -> String {
        switch outcome {
        case .accord: "Le résultat est bon et le raisonnement est consolidé : ce que vous avez avancé était vérifiable par quelqu’un d’autre que vous."
        case .partielle: "Vous avez eu raison sans rendre votre raison opposable. Une reprise sur le même chemin change l’issue à moindre coût."
        case .rupture: "Le moteur ne connaît pas d’échec : c’est la conséquence, dans le monde, qui ferme la porte. Il n’y a pas de reprise en cours de route — la scène se rejoue depuis le début."
        case nil: "La démo s’arrête ici : votre histoire ne repart pas en boucle."
        }
    }

    static func demoFrequencyLabel(_ outcome: DemoOutcome?) -> String {
        switch outcome {
        case .rupture: "Aucune fréquence : la démarche n’a pas été rendue explicite."
        case .partielle: "Fréquence du doute, non consolidée : le fait manquait à l’intuition."
        default: "Fréquence du doute : vous avez suspendu une conclusion trop fluide."
        }
    }

    /// Postures traversées, déduites des choix réellement disponibles sur le chemin parcouru.
    static func demoPostures(_ path: [String]) -> [String] {
        var seen: [String] = []
        for id in path {
            guard let node = DemoStory.node(id: id) else { continue }
            for posture in node.choices.map(\.posture) where !seen.contains(posture) && diapasonPostures.contains(posture) {
                seen.append(posture)
            }
        }
        // Le nœud d'accueil propose les trois situations : ne rien retenir de lui
        // si le joueur n'est pas encore entré dans l'une d'elles.
        return path.count > 1 ? seen.filter { posture in
            path.dropFirst().contains { DemoStory.node(id: $0)?.choices.contains { $0.posture == posture } ?? false }
        } : []
    }

    static let worldMapSize = CGSize(width: 1536, height: 1024)
    /// Centres des six champs dessinés dans `WorldMap` (`diapason-domains.svg`).
    ///
    /// Ces coordonnées ne sont pas relevées après coup sur une image existante :
    /// elles sont écrites en même temps que la composition, et les deux se
    /// modifient ensemble. Elles sont identiques à `worldDoorAnchors` du client
    /// web, qui affiche le même plan. L'anneau évite le coin supérieur gauche,
    /// occupé par le titre de la carte.
    ///
    /// Il en faut au moins autant que de catégories publiées : la configuration
    /// de référence en compte six. Avec cinq ancres, la sixième posture retombait
    /// sur la disposition en grille calculée, sans rapport avec le dessin.
    static let doorAnchors = [
        CGPoint(x: 768, y: 268), CGPoint(x: 1200, y: 360), CGPoint(x: 1240, y: 700),
        CGPoint(x: 830, y: 800), CGPoint(x: 420, y: 716), CGPoint(x: 392, y: 430)
    ]
    /// En portrait, `projectMapPoint` recadre en `cover` sur la largeur : seule
    /// une bande centrale du plan reste visible, en pratique `x` entre 530 et
    /// 1005 sur un iPhone courant. Les ancres larges tomberaient hors champ.
    /// La grille est aussi décalée vers le bas, sous le titre de la carte.
    static let compactDoorAnchors = [
        CGPoint(x: 658, y: 416), CGPoint(x: 879, y: 416), CGPoint(x: 658, y: 618),
        CGPoint(x: 879, y: 618), CGPoint(x: 658, y: 820), CGPoint(x: 879, y: 820)
    ]

    static func doorAnchors(for viewport: CGSize) -> [CGPoint] {
        viewport.width < viewport.height ? compactDoorAnchors : doorAnchors
    }

    // MARK: - Disposition des portes

    /// Placement des portes, **en points écran**.
    ///
    /// La première version de ce correctif disposait les ancrages dans le repère de la
    /// carte, puis les projetait par `projectMapPoint`, qui est un aspect-fill. Deux défauts
    /// en découlaient, tous deux vérifiés par le calcul :
    ///
    /// - en portrait, la carte 1536×1024 est rognée horizontalement et seule une fenêtre
    ///   étroite du monde reste visible ; sur iPhone 393×852 avec six catégories, cinq
    ///   portes sur six tombaient hors cadre — davantage que n'en masquait le `prefix(5)`
    ///   qu'elles remplaçaient ;
    /// - l'espacement écran valant « pas monde × échelle », il se contractait quand le
    ///   nombre de catégories montait : à quinze portes sur iPhone paysage, 107 points
    ///   séparaient des portes larges de 150. Les portes tardives, dessinées par-dessus,
    ///   captaient les taps de leurs voisines.
    ///
    /// Toute constante posée en coordonnées monde est juste sur un appareil et fausse sur
    /// le suivant. La disposition est donc calculée ici dans l'espace écran, où vivent la
    /// taille des portes et la cible tactile ; la carte redevient un décor.
    struct DoorPlacement: Equatable, Sendable {
        /// Centres des portes de la page courante, en points écran.
        var positions: [CGPoint]
        /// Taille effective d'une porte, réduite jusqu'à ce que la page tienne.
        var size: CGSize
        /// Indices des catégories affichées sur cette page.
        var range: Range<Int>
        var page: Int
        var pageCount: Int
        /// Nombre de portes qu'une page peut porter lisiblement.
        var capacity: Int
        /// Zone écran réellement dévolue aux portes, insets résolus compris.
        var field: CGRect
        /// `true` si la disposition suit les ancrages dessinés sur la carte plutôt que la
        /// grille de repli. Exposé pour que les tests puissent vérifier que ce chemin vit
        /// encore là où l'écran le permet, au lieu d'être devenu du code mort silencieux.
        var usesMapAnchors = false

        var isPaginated: Bool { pageCount > 1 }
    }

    /// Insets réellement applicables. Les valeurs nominales sont dimensionnées pour un
    /// téléphone en portrait ; sur un écran court — iPhone en paysage, 393 points de haut —
    /// elles ne laissaient que 109 points, moins qu'une porte, et le champ devenait vide.
    /// Elles sont donc plafonnées en proportion de la hauteur disponible.
    static func resolvedDoorInsets(
        viewport: CGSize,
        topInset: CGFloat = doorFieldTopInset,
        bottomInset: CGFloat = doorFieldBottomInset
    ) -> (top: CGFloat, bottom: CGFloat) {
        (min(topInset, viewport.height * 0.16), min(bottomInset, viewport.height * 0.38))
    }

    /// Espace réservé au bandeau interne et au dock des récits, retiré du champ des portes.
    static let doorFieldTopInset: CGFloat = 84
    static let doorFieldBottomInset: CGFloat = 200
    static let doorSpacing: CGFloat = 12
    static let doorMargin: CGFloat = 16
    /// En deçà, une porte ne peut plus porter son nom, son rang et sa progression.
    static let minimumDoorSize = CGSize(width: 132, height: 116)
    static let maximumDoorSize = CGSize(width: 210, height: 188)

    /// Dispose `total` portes dans le viewport, en paginant si elles ne tiennent pas toutes.
    ///
    /// Aucune catégorie n'est écartée : celles qui ne tiennent pas sur la page courante
    /// restent atteignables par la pagination, que l'interface rend visible. Empiler des
    /// portes illisibles les unes sur les autres serait une disparition silencieuse
    /// déguisée en affichage.
    static func doorPlacement(
        total: Int,
        page: Int = 0,
        viewport: CGSize,
        topInset: CGFloat = doorFieldTopInset,
        bottomInset: CGFloat = doorFieldBottomInset
    ) -> DoorPlacement {
        let insets = resolvedDoorInsets(viewport: viewport, topInset: topInset, bottomInset: bottomInset)
        let usableWidth = viewport.width - doorMargin * 2
        let usableHeight = viewport.height - insets.top - insets.bottom
        let field = CGRect(x: doorMargin, y: insets.top, width: usableWidth, height: usableHeight)
        guard total > 0, usableWidth >= minimumDoorSize.width, usableHeight >= minimumDoorSize.height else {
            return DoorPlacement(positions: [], size: minimumDoorSize, range: 0..<0, page: 0, pageCount: 1, capacity: 0, field: field)
        }

        let columns = max(1, Int(((usableWidth + doorSpacing) / (minimumDoorSize.width + doorSpacing)).rounded(.down)))
        let rows = max(1, Int(((usableHeight + doorSpacing) / (minimumDoorSize.height + doorSpacing)).rounded(.down)))
        let capacity = columns * rows
        let pageCount = max(1, Int((Double(total) / Double(capacity)).rounded(.up)))
        let page = min(max(page, 0), pageCount - 1)
        let start = page * capacity
        let end = min(total, start + capacity)
        let count = end - start

        // Colonnes de la page : assez pour tenir en `rows` rangées, jamais plus que `columns`.
        let balanced = max(1, Int((Double(count) * Double(usableWidth) / Double(usableHeight)).squareRoot().rounded(.up)))
        let required = max(1, Int((Double(count) / Double(rows)).rounded(.up)))
        let pageColumns = min(columns, max(balanced, required))
        let pageRows = max(1, Int((Double(count) / Double(pageColumns)).rounded(.up)))

        let cellWidth = usableWidth / CGFloat(pageColumns)
        let cellHeight = usableHeight / CGFloat(pageRows)
        // La porte tient strictement dans sa cellule. Les cellules pavant la zone utile,
        // deux portes ne peuvent ni se recouvrir ni sortir du cadre — quel que soit l'écran.
        let size = CGSize(
            width: min(maximumDoorSize.width, cellWidth - doorSpacing),
            height: min(maximumDoorSize.height, cellHeight - doorSpacing))

        // Les ancrages dessinés à la main suivent des reliefs de la carte : ils restent
        // préférés, mais seulement là où ils tiennent réellement à l'écran. C'est ce
        // contrôle qui manquait — ils étaient posés sans vérifier qu'ils tombaient dans le cadre.
        if pageCount == 1, let handmade = handmadeDoorPositions(count: count, viewport: viewport, size: size, field: field) {
            return DoorPlacement(positions: handmade, size: size, range: start..<end, page: page, pageCount: pageCount, capacity: capacity, field: field, usesMapAnchors: true)
        }

        let positions = (0..<count).map { index -> CGPoint in
            CGPoint(
                x: field.minX + cellWidth * (CGFloat(index % pageColumns) + 0.5),
                y: field.minY + cellHeight * (CGFloat(index / pageColumns) + 0.5))
        }
        return DoorPlacement(positions: positions, size: size, range: start..<end, page: page, pageCount: pageCount, capacity: capacity, field: field)
    }

    /// Ancrages dessinés à la main, projetés — ou `nil` s'ils ne tiennent pas dans ce
    /// viewport, à cette taille de porte.
    static func handmadeDoorPositions(
        count: Int,
        viewport: CGSize,
        size: CGSize,
        field: CGRect
    ) -> [CGPoint]? {
        let anchors = doorAnchors(for: viewport)
        guard count > 0, count <= anchors.count, field.width >= size.width, field.height >= size.height else { return nil }
        // Un ancrage légèrement débordant est ramené dans le champ plutôt que de faire
        // rejeter toute la disposition : la carte garde son caractère là où c'est possible.
        let positions = anchors.prefix(count).map { anchor -> CGPoint in
            let projected = projectMapPoint(anchor, into: viewport)
            return CGPoint(
                x: min(max(projected.x, field.minX + size.width / 2), field.maxX - size.width / 2),
                y: min(max(projected.y, field.minY + size.height / 2), field.maxY - size.height / 2))
        }
        let rects = positions.map { center in
            CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        }
        // Le recadrage peut rapprocher deux portes : si elles se touchent, la grille reprend
        // la main. Aucune disposition ne sort d'ici avec un recouvrement.
        for (index, rect) in rects.enumerated() {
            let padded = rect.insetBy(dx: -doorSpacing / 2, dy: -doorSpacing / 2)
            if rects.dropFirst(index + 1).contains(where: { padded.intersects($0) }) { return nil }
        }
        return Array(positions)
    }

    /// Progression affichée sur une porte. La donnée existe déjà et est présentée
    /// à l'identique dans la bibliothèque ; la carte ne l'inventait simplement pas.
    struct DoorProgress: Equatable, Sendable {
        var total: Int
        var started: Int

        var percent: Int { total == 0 ? 0 : Int((Double(started) / Double(total) * 100).rounded()) }
        var fraction: Double { total == 0 ? 0 : Double(started) / Double(total) }

        var label: String {
            guard total > 0 else { return "Aucun récit configuré" }
            return "\(started)/\(total) récit\(total > 1 ? "s" : "") commencé\(started > 1 ? "s" : "") · \(percent) %"
        }
    }

    static func doorProgress(
        category: CategoryDefinition,
        stories: [StorySummary],
        savedSessions: [SavedSession]
    ) -> DoorProgress {
        let scenarioIds = Set(category.scenarioIds ?? [])
        let categoryStories = stories.filter { story in story.scenarioID.map(scenarioIds.contains) == true }
        let startedVersions = Set(savedSessions.map(\.scenarioVersionId))
        let started = categoryStories.filter { story in
            if case let .published(versionID) = story.availability { return startedVersions.contains(versionID) }
            return false
        }.count
        return DoorProgress(total: categoryStories.count, started: started)
    }

    static func projectMapPoint(_ point: CGPoint, into viewport: CGSize) -> CGPoint {
        let scale = max(viewport.width / worldMapSize.width, viewport.height / worldMapSize.height)
        return CGPoint(
            x: (viewport.width - worldMapSize.width * scale) / 2 + point.x * scale,
            y: (viewport.height - worldMapSize.height * scale) / 2 + point.y * scale)
    }

    static func journalTypeLabel(_ value: String) -> String {
        [
            "ChoiceSelected": "Choix effectué",
            "NarrationContinued": "Récit poursuivi",
            "QuizAnswered": "Question résolue",
            "TextSubmitted": "Réponse écrite",
            "ScenarioCompleted": "Histoire terminée"
        ][value] ?? value.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
    }

    static func familiarOptionLabel(_ value: String) -> String {
        [
            "spark": "Étincelle", "owl": "Chouette", "fox": "Renard",
            "Warm": "Chaleureux", "Playful": "Joueur", "Direct": "Direct", "Mysterious": "Mystérieux"
        ][value] ?? value
    }

    static func uniqueJournalEntries(_ entries: [PlayerJournalEntryView]) -> [PlayerJournalEntryView] {
        var seen = Set<String>()
        return entries.filter { entry in
            let key = [entry.type, entry.sessionId?.uuidString, entry.referenceId, entry.scenarioVersionId?.uuidString, entry.title, entry.summary, entry.occurredAt.ISO8601Format()]
                .map { ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    static func uniqueMasteries(_ masteries: [ScenarioMasteryView]) -> [ScenarioMasteryView] {
        var byVersion: [UUID: ScenarioMasteryView] = [:]
        for mastery in masteries where byVersion[mastery.scenarioVersionId].map({ mastery.updatedAt > $0.updatedAt }) ?? true {
            byVersion[mastery.scenarioVersionId] = mastery
        }
        return Array(byVersion.values).sorted { $0.updatedAt > $1.updatedAt }
    }
}
