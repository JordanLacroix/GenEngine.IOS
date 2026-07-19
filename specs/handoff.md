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
- **Paramètres serveur avant connexion.** `ServerSettingsPanel` (`Features/Settings`) règle les six services en mode **groupé** (hôte et schéma communs, un port par service) ou **unitaire** (une URL complète par service), `organization` compris. Il est atteignable depuis le menu de l'accueil anonyme (`WelcomeView.welcomeMenu`), depuis `AccountView` et depuis `AdministrationView`. Il est disponible en Release : c'est une exception documentée à l'invariant 5, prise parce qu'un appareil neuf n'avait aucun recours face à l'adresse compilée. Chaque service a un contrôle de connectivité (`EndpointProbe`) qui annonce une réponse HTTP, sans prétendre valider le service. La persistance passe par `EndpointStore`, inchangé.
- **Une seule barre d'onglets.** La barre `UniverseSection` de `PlayerExperienceView` a disparu ; ses quatre panneaux sont des actions du bandeau haut, qui se place dans la zone réservée par `HUDMetrics` via la zone sûre étendue par `GameShellView`. La carte est l'état de repos, plus un onglet.
- **Formulaire de connexion unique.** `SignInPanel` remplace les deux copies divergentes de `WelcomeView` et `AccountView`.
- **Carte sans plafond.** `PlayerExperiencePresentation.doorAnchors(count:for:)` conserve les cinq ancrages dessinés à la main tant qu'ils suffisent, puis disperse les suivants sur une grille décalée déterministe. Le `prefix(5)` a disparu des deux emplacements. Chaque porte affiche sa progression (`doorProgress`), la même donnée que `LibraryView`.
- **Confirmations et succès visibles.** `ConfirmationAction` + `.confirmation(_:)` couvrent déconnexion, sortie de démonstration, sortie de partie (bouton **et** fermeture du `fullScreenCover`, désormais non dismissible interactivement), suppressions d'unité, catégorie, parcours, familier, libellé, utilisateur, rôle, membership, affectation, et archivage Studio. `AppState.successMessage` alimente un bandeau annoncé à VoiceOver ; les opérations de jeu répétées (choix, narration) n'en déclenchent pas.
- **Démonstration Diapason hors ligne.** 23 scènes exactement dans `DemoStory` (`StoryModels.swift:123-291`). Un nœud d'accueil ouvre sur trois situations — La note de service (Lucidité), La réunion où personne ne doute (Courage), La spécification avant le code (Transmission). Douze fins suivant la convention `fin-accord-*`, `fin-partielle-*`, `fin-rupture-*` : exactement 6 ruptures, 2 par situation. `DemoNode.title`, `DemoNode.outcome` et `DemoChoice.posture` restent locaux à la frontière de démonstration. Aucun appel réseau.

## Manques honnêtes et points cassés

Ce sont les points à ne pas présenter comme résolus.

- **Rien n'a jamais été vu à l'écran.** La coque HUD et la démonstration Diapason n'ont été validées que par build et tests, sur instruction du propriétaire du dépôt. Aucun rendu n'a été observé sur simulateur ni sur appareil. Toute affirmation visuelle de ce dépôt est une intention, pas un constat.
- **Valeurs de `HUDMetrics` non calibrées.** `topBarHeight: 74`, `bottomBarHeight: 96`, `railWidth: 108` sont des estimations posées sans mesure à l'écran. Seul `minimumTarget: 44` correspond à une contrainte réelle.
- **Bandeau interne jamais vu à l'écran.** La seconde barre d'onglets a été retirée et le bandeau restant s'appuie sur `HUDMetrics`, mais aucune de ces deux décisions n'a été observée en rendu : elles sont correctes par construction, pas par constat.
- **Écran de paramètres jamais vu à l'écran.** `ServerSettingsPanel` compile et ses règles d'adressage sont couvertes par `EndpointDraftTests`. Sa mise en page, son comportement clavier et le rendu du contrôle de connectivité n'ont été observés ni en simulateur ni sur appareil.
- **Dispersion des portes non observée.** `dispersedAnchors` garantit par test que chaque catégorie reçoit un ancrage distinct dans le cadre de la carte. Elle ne garantit pas que les cartes de porte ne se chevauchent pas visuellement au-delà d'une douzaine de catégories : ce point demande un rendu réel.
- **Aucun pack audio.** Aucun `audio-manifest.json` n'est livré et le dépôt ne contient aucun fichier son. Il n'existe **ni boucle d'ambiance, ni musique**. L'application est donc silencieuse ; le panneau de son l'annonce plutôt que de laisser croire à une panne. Le backend ne publie aucun contrat audio.
- **Aucun portrait de personnage.** Le catalogue d'assets ne contient que quatre illustrations : `FamiliarAster` (la créature compagnon), `IntroGateway`, `TutorialKey` et `WorldMap`. Aucun portrait humain.
- **Pas de game-over de première classe.** `SessionStatus` ne connaît que `awaitingInput, paused, completed, abandoned, awaitingExternalInput, awaitingValidation` : aucun drapeau d'échec. L'échec est **narratif uniquement**, porté par le texte et par l'interface — sur une rupture, le bilan bascule ses actions et « Reprendre depuis le début » devient l'action principale (`PlayerView.swift:223-231`). Note : un `AudioCue.gameOver` existe, mais c'est un nom de signal joué sur toute fin, y compris un accord, pas un état.
- **Mémoire de démonstration jamais affichée.** `AppState.demoQuestGraph` (`:729`) n'est référencé par aucune vue : c'est du code mort. La mémoire cumulée de démonstration n'apparaît donc pas dans le journal — et non pas « n'apparaît plus une fois authentifié », comme l'affirmaient les versions précédentes de ce document.
- **`discardDemoAccess()` ne purge pas la mémoire.** `demoDiscoveredNodeIDs` et `demoDiscoveredChoiceIDs` (`AppState.swift:65-66`) survivent à la connexion et réapparaîtraient après `signOut()`.
- **Liste textuelle du graphe repliée.** La liste qui double le `Canvas` de `QuestGraphView` est dans un `DisclosureGroup` fermé par défaut (`:14, :31`). Elle devient le mode principal au-delà de 60 nœuds ou en tailles de texte d'accessibilité (`:16-18`), mais reste repliée. Le `Canvas` est un unique élément d'accessibilité opaque.
- **Postures inégalement exercées.** Les six postures sont déclarées (`PlayerExperiencePresentation.swift:6`), mais la démonstration n'en exerce que trois par ses choix (Lucidité, Courage, Transmission). Discernement et Autonomie n'apparaissent que sur des entrées `.comingSoon` ; **Arbitrage n'apparaît nulle part** en dehors du tableau de déclaration.
- **Repli de monnaie non atteint.** Le couple « Accords » / `♪` ne vivait que dans la vue morte `header`, supprimée : il n'existe donc plus nulle part. Le bandeau réellement rendu affiche `✦` et le nom de monnaie en libellé d'accessibilité seulement. L'ancien libellé « Braises » a bien disparu du dépôt.
- **`AppState.importAndPublish` sans point d'entrée.** La fonction reste compilée en DEBUG, mais son unique appelant (`DeveloperView`) et son unique fixture (`GenEngine/Resources/forest-choice.json`) ont été supprimés. Elle n'est atteignable depuis aucune interface. Elle est conservée, et non retirée, parce que `scenarioVersionID` et `publishedTitle` — qu'elle seule alimente — sont lus par `AppState.stories` : la retirer rendrait cette branche morte à son tour, ce qui déborde du lot.

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

La priorité raisonnable est de **regarder l'application tourner** avant d'ajouter quoi que ce soit : lancer la coque HUD, l'écran de paramètres, la carte et la démonstration Diapason sur simulateur iPhone et iPad, puis calibrer `HUDMetrics`, vérifier que le bandeau interne ne recouvre plus rien et regarder ce que donne une carte à quinze portes.

Toute nouvelle tranche dépendant d'un contrat backend non publié — l'audio en premier lieu — reste hors périmètre.

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux, réservée à l'état anonyme.
- Outils sensibles (import Authoring, journal brut) limités à Debug. L'adressage des services fait exception assumée : c'est un réglage d'appareil, disponible en Release et avant connexion.
- Toute action qui perd du travail, ferme une session ou supprime une donnée passe par une confirmation.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.
- Présentation plein écran : aucune chrome de navigation système ne revient.
- Son toujours désactivable et jamais seul porteur d'une information.
- Masquer une destination du HUD reste une commodité de présentation, jamais un contrôle d'accès.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l'historique de conversation — et sans confondre ce qui est livré avec ce qui a seulement été écrit.
