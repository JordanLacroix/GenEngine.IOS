# Passage de relais

Dernière mise à jour : 19 juillet 2026.

Ce document dit ce qui est **réellement livré**, ce qui est **cassé ou douteux** et ce qui est **délibérément absent**. Chaque affirmation ci-dessous a été vérifiée dans le code, pas reprise d'un handoff précédent.

## Le produit

GenEngine est un moteur narratif paramétrable vendu aux écoles d'ingénieurs, aux entreprises et aux organismes de formation. « Le Diapason » en est la configuration de référence : 2026, notre monde, l'IA partout, le joueur apprenti en école d'ingénieurs. Six postures — Lucidité, Discernement, Arbitrage, Courage, Transmission, Autonomie — remplacent les catégories par matière, pour dix scénarios. Ce dépôt est le client iOS.

## Livré et vérifié dans le code

- Application SwiftUI universelle iPhone/iPad, générée par XcodeGen, Swift 6 en concurrence stricte.
- Identity, catalogue Authoring, parcours Play complet, Configuration, PlayerExperience et Organization sont raccordés. Le client appelle les six services directement.
- Jetons en Keychain ; références de session opaques ; endpoints et préférences non sensibles en `UserDefaults`.
- **Coque HUD plein écran.** `GameShellView` a remplacé le `TabView` et le `NavigationStack` racine : il n'existe plus aucun `TabView` dans le dépôt, et le seul `NavigationStack` restant est dans `DeveloperView`, qui est du code mort. La destination courante est rendue bord à bord ; navigation en barre basse en largeur compacte, en rail vertical gauche en largeur régulière (`GameShellView.swift:20, 60, 62`). La partie est présentée en `fullScreenCover` (`RootView.swift:15`).
- **Démonstration fermée une fois authentifié, dans le modèle.** `isDemoAvailable` vaut `!isAuthenticated` (`AppState.swift:103`) ; `unlockDemo()`, `startDemo()` et `open(_:)` refusent la fixture (`:170, :541, :528`) ; `discardDemoAccess()` est appelé par `login()`, `register()` et `loginWithMicrosoft()` (`:216, :229, :246`) ; `DemoStory.library` quitte le catalogue (`:145`). Ce n'est pas un simple masquage de vue.
- **Audio derrière un protocole, piloté par manifeste.** `GameAudioDirector` ne connaît que `GameAudioEngine` ; `BundledGameAudioEngine` lit `audio-manifest.json` de schéma `1` ; `SilentGameAudioEngine` sert les tests. Trois couches indépendantes (cas `ambience`, `music`, `effects`, ce dernier libellé « Signaux »). Aucun nom de fichier codé en dur. Une version de schéma inconnue est refusée explicitement (`GameAudio.swift:147`). Le son est désactivable en permanence depuis la barre haute.
- **Graphe de quête et mémoire cumulée.** `QuestGraphPresentation` expose deux adaptateurs, `build(tree:…)` en partie et `build(structure:…)` hors partie (`:108`, `:137`), convergeant vers une seule mise en page à rangs BFS (`:221`). `QuestGraphView` dessine un `Canvas` doublé d'une liste textuelle.
- **Structure d'un scénario hors partie.** `GenEngineAPI.scenarioStructure(scenarioVersionId:)` consomme `GET /scenario-versions/{id}/tree` (`GenEngineAPI.swift:59, 379`). `ScenarioStructure` est un type distinct de `NarrativeTree` : il ne porte volontairement ni état de scène, ni évaluation de condition, faute d'état de monde hors session (`APIModels.swift:203`).
- **Catalogue paginé, recherche serveur.** `GET /catalog` est consommé sous la forme de l'enveloppe unifiée `{ items, page, pageSize, total }` de GenEngine#55, via `PagedList` (`Core/Models/PagedList.swift`), dont le décodage est tolérant : un tableau nu — le contrat antérieur — reste lu comme une page unique complète, et une métadonnée absente retombe sur une valeur cohérente avec `items`. `AppState` conserve `catalogPage`, `catalogTotal` et `catalogQuery` ; `loadMorePublishedStories()` ajoute la page suivante et `searchCatalog(_:)` repart de la première page avec une recherche **appliquée par le serveur**, jamais par filtrage de la page affichée. `units` et `periods` sont désormais parcourus page par page dans `LiveGenEngineAPI.allPages`, l'écran d'administration ayant réellement besoin de l'arbre entier ; le journal envoie `pageSize` et non plus `limit`.

  Comportement par écran : **Bibliothèque**, surface exhaustive, chargement progressif au défilement plus un bouton « Charger la suite » et un compteur « n sur total » ; **Accueil**, même chargement progressif au défilement ; **carte du joueur**, dock horizontal passé en `LazyHStack`, qui demande la page suivante en fin de défilement et avance dans les pages tant qu'une porte sélectionnée n'a encore aucun récit chargé.
- **Démonstration Diapason hors ligne.** 23 scènes exactement dans `DemoStory` (`StoryModels.swift:123-291`). Un nœud d'accueil ouvre sur trois situations — La note de service (Lucidité), La réunion où personne ne doute (Courage), La spécification avant le code (Transmission). Douze fins suivant la convention `fin-accord-*`, `fin-partielle-*`, `fin-rupture-*` : exactement 6 ruptures, 2 par situation. `DemoNode.title`, `DemoNode.outcome` et `DemoChoice.posture` restent locaux à la frontière de démonstration. Aucun appel réseau.

## Manques honnêtes et points cassés

Ce sont les points à ne pas présenter comme résolus.

- **Rien n'a jamais été vu à l'écran.** La coque HUD et la démonstration Diapason n'ont été validées que par build et tests, sur instruction du propriétaire du dépôt. Aucun rendu n'a été observé sur simulateur ni sur appareil. Toute affirmation visuelle de ce dépôt est une intention, pas un constat.
- **Pagination jamais vérifiée de bout en bout.** La PR backend GenEngine#55 qui introduit l'enveloppe paginée n'est pas fusionnée : le client n'a été confronté qu'au contrat documenté et à des doubles de test qui en reproduisent la sémantique. Aucun appel réel à un serveur renvoyant la nouvelle enveloppe n'a eu lieu. Les deux lots doivent être fusionnés ensemble : séparément, l'un casse l'autre.
- **Comptages par catégorie encore partiels.** Les cartes de catégorie de la bibliothèque et la progression des portes comptent les récits **déjà chargés**, pas ceux que le serveur déclare pour la catégorie. Le chiffre se corrige au fil des pages ; une agrégation par catégorie côté serveur serait la vraie réponse et n'existe pas.
- **Valeurs de `HUDMetrics` non calibrées.** `topBarHeight: 74`, `bottomBarHeight: 96`, `railWidth: 108` sont des estimations posées sans mesure à l'écran. Seul `minimumTarget: 44` correspond à une contrainte réelle.
- **Deux HUD superposés.** `PlayerExperienceView` conserve son propre HUD de sections (`gameHUD`, `:81-102` : ligne haute clé/solde/compagnon, ligne basse de cinq capsules sur `UniverseSection`) sous le HUD de la coque, avec la même largeur maximale de 620 points que la barre basse. Cette cohabitation n'a jamais été vue à l'écran et n'a pas été arbitrée.
- **Aucun pack audio.** Aucun `audio-manifest.json` n'est livré et le dépôt ne contient aucun fichier son. Il n'existe **ni boucle d'ambiance, ni musique**. L'application est donc silencieuse ; le panneau de son l'annonce plutôt que de laisser croire à une panne. Le backend ne publie aucun contrat audio.
- **Aucun portrait de personnage.** Le catalogue d'assets ne contient que quatre illustrations : `FamiliarAster` (la créature compagnon), `IntroGateway`, `TutorialKey` et `WorldMap`. Aucun portrait humain.
- **Pas de game-over de première classe.** `SessionStatus` ne connaît que `awaitingInput, paused, completed, abandoned, awaitingExternalInput, awaitingValidation` : aucun drapeau d'échec. L'échec est **narratif uniquement**, porté par le texte et par l'interface — sur une rupture, le bilan bascule ses actions et « Reprendre depuis le début » devient l'action principale (`PlayerView.swift:223-231`). Note : un `AudioCue.gameOver` existe, mais c'est un nom de signal joué sur toute fin, y compris un accord, pas un état.
- **Mémoire de démonstration jamais affichée.** `AppState.demoQuestGraph` (`:729`) n'est référencé par aucune vue : c'est du code mort. La mémoire cumulée de démonstration n'apparaît donc pas dans le journal — et non pas « n'apparaît plus une fois authentifié », comme l'affirmaient les versions précédentes de ce document.
- **`discardDemoAccess()` ne purge pas la mémoire.** `demoDiscoveredNodeIDs` et `demoDiscoveredChoiceIDs` (`AppState.swift:65-66`) survivent à la connexion et réapparaîtraient après `signOut()`.
- **Liste textuelle du graphe repliée.** La liste qui double le `Canvas` de `QuestGraphView` est dans un `DisclosureGroup` fermé par défaut (`:14, :31`). Elle devient le mode principal au-delà de 60 nœuds ou en tailles de texte d'accessibilité (`:16-18`), mais reste repliée. Le `Canvas` est un unique élément d'accessibilité opaque.
- **Postures inégalement exercées.** Les six postures sont déclarées (`PlayerExperiencePresentation.swift:6`), mais la démonstration n'en exerce que trois par ses choix (Lucidité, Courage, Transmission). Discernement et Autonomie n'apparaissent que sur des entrées `.comingSoon` ; **Arbitrage n'apparaît nulle part** en dehors du tableau de déclaration.
- **Repli de monnaie non atteint.** Le couple « Accords » / `♪` existe bien, mais dans la vue morte `header` (`PlayerExperienceView.swift:153`). Le HUD réellement rendu (`:86`) affiche `✦` et aucun nom de monnaie. L'ancien libellé « Braises » a bien disparu du dépôt.
- **Code mort à retirer.** `DeveloperView` n'est instancié nulle part ; ses diagnostics ont été **réimplémentés**, pas déplacés, dans `AdministrationView` (`:458-467`). Conséquence : `AppState.importAndPublish` (DEBUG) n'est plus atteignable depuis l'interface. Dans `PlayerExperienceView`, `keyStatus`, `header` et `sectionPicker` sont également sans appelant.

## Délibérément absent

- Aucun moteur narratif embarqué : les règles restent dans `GenEngine.Narrative`, côté serveur.
- Aucun repli silencieux sur la fixture : un refus serveur produit un message et une action de reprise.
- Aucun contrat audio serveur : `ExperienceDocument` n'a pas été modifié, rien n'a été raccordé.
- Aucun état de scène hors session : `ScenarioStructure` ne l'expose pas, parce qu'il n'existe pas.
- Aucun point d'entrée public unique : le client appelle les six services directement, ce qui reste à corriger avant distribution.
- Aucune licence.

## Démarrage rapide de reprise

```bash
git status --short --branch
git pull --ff-only
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

`GenEngine/Core/Configuration/ServiceEndpoints.swift` porte souvent une modification locale non committée (adresse privée pour test sur appareil) : ne pas la committer, ne pas la révoquer.

## Prochaine unité de travail

Rien n'est cadré et aucune tranche fonctionnelle n'est engagée.

La priorité raisonnable est de **regarder l'application tourner** avant d'ajouter quoi que ce soit : lancer la coque HUD et la démonstration Diapason sur simulateur iPhone et iPad, puis calibrer `HUDMetrics`, trancher la cohabitation des deux HUD dans `PlayerExperienceView` et retirer le code mort listé ci-dessus.

Toute nouvelle tranche dépendant d'un contrat backend non publié — l'audio en premier lieu — reste hors périmètre.

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux, réservée à l'état anonyme.
- Outils sensibles limités à Debug.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.
- Présentation plein écran : aucune chrome de navigation système ne revient.
- Son toujours désactivable et jamais seul porteur d'une information.
- Masquer une destination du HUD reste une commodité de présentation, jamais un contrôle d'accès.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l'historique de conversation — et sans confondre ce qui est livré avec ce qui a seulement été écrit.
