# Passage de relais

Dernière mise à jour : 21 juillet 2026.

Ce document dit ce qui est **réellement livré**, ce qui est **cassé ou douteux** et ce qui est **délibérément absent**. Chaque affirmation ci-dessous a été vérifiée dans le code, pas reprise d'un handoff précédent.

## Le produit

GenEngine est un moteur narratif paramétrable vendu aux écoles d'ingénieurs, aux entreprises et aux organismes de formation. « Le Diapason » en est la configuration de référence : 2026, notre monde, l'IA partout, le joueur apprenti en école d'ingénieurs. Six postures — Lucidité, Discernement, Arbitrage, Courage, Transmission, Autonomie — remplacent les catégories par matière, pour dix scénarios. Ce dépôt est le client iOS.

## Livré et vérifié dans le code

- Application SwiftUI universelle iPhone/iPad, générée par XcodeGen, Swift 6 en concurrence stricte.
- Identity, catalogue Authoring, parcours Play complet, Configuration, PlayerExperience et Organization sont raccordés. Le client appelle les six services directement.
- Jetons en Keychain ; références de session opaques ; endpoints et préférences non sensibles en `UserDefaults`.
- **Coque HUD plein écran.** `GameShellView` a remplacé le `TabView` et le `NavigationStack` racine : il n'existe plus aucun `TabView` ni aucun `NavigationStack` dans le dépôt, `DeveloperView` ayant été supprimée. La destination courante est rendue bord à bord ; navigation en barre basse en largeur compacte, en rail vertical gauche en largeur régulière (`GameShellView.swift:20, 60, 62`). La partie est présentée en `fullScreenCover` (`RootView.swift:15`).
- **Démonstration fermée une fois authentifié, dans le modèle.** `isDemoAvailable` vaut `!isAuthenticated` (`AppState.swift:103`) ; `unlockDemo()`, `startDemo()` et `open(_:)` refusent la fixture (`:170, :541, :528`) ; `discardDemoAccess()` est appelé par `login()`, `register()` et `loginWithMicrosoft()` (`:216, :229, :246`) ; `DemoStory.library` quitte le catalogue (`:145`). Ce n'est pas un simple masquage de vue.
- **Audio derrière un protocole, piloté par manifeste.** `GameAudioDirector` ne connaît que `GameAudioEngine` ; `BundledGameAudioEngine` lit `audio-manifest.json` de schéma `1` ; `SilentGameAudioEngine` sert les tests. Trois couches indépendantes (cas `ambience`, `music`, `effects`, ce dernier libellé « Signaux »). Aucun nom de fichier codé en dur. Une version de schéma inconnue est refusée explicitement (`GameAudio.swift:147`). Le son est désactivable en permanence depuis la barre haute.
- **Graphe de quête et mémoire cumulée.** `QuestGraphPresentation` expose deux adaptateurs, `build(tree:…)` en partie et `build(structure:…)` hors partie (`:108`, `:137`), convergeant vers une seule mise en page à rangs BFS (`:221`). `QuestGraphView` dessine un `Canvas` doublé d'une liste textuelle.
- **Structure d'un scénario hors partie.** `GenEngineAPI.scenarioStructure(scenarioVersionId:)` consomme `GET /scenario-versions/{id}/tree` (`GenEngineAPI.swift:59, 379`). `ScenarioStructure` est un type distinct de `NarrativeTree` : il ne porte volontairement ni état de scène, ni évaluation de condition, faute d'état de monde hors session (`APIModels.swift:203`).
- **Catalogue paginé, recherche serveur.** `GET /catalog` est consommé sous la forme de l'enveloppe unifiée `{ items, page, pageSize, total }` de GenEngine#55, via `PagedList` (`Core/Models/PagedList.swift`), dont le décodage est tolérant : un tableau nu — le contrat antérieur — reste lu comme une page unique complète, et une métadonnée absente retombe sur une valeur cohérente avec `items`. `AppState` conserve `catalogPage`, `catalogTotal` et `catalogQuery` ; `loadMorePublishedStories()` ajoute la page suivante et `searchCatalog(_:)` repart de la première page avec une recherche **appliquée par le serveur**, jamais par filtrage de la page affichée. `units` et `periods` sont désormais parcourus page par page dans `LiveGenEngineAPI.allPages`, l'écran d'administration ayant réellement besoin de l'arbre entier ; le journal envoie `pageSize` et non plus `limit`.

  Comportement par écran : **Bibliothèque**, surface exhaustive, chargement progressif au défilement plus un bouton « Charger la suite » et un compteur « n sur total » ; **Accueil**, même chargement progressif au défilement ; **carte du joueur**, panneau de porte `LazyVStack` qui demande la page suivante en fin de défilement, offre un bouton « Charger la suite », et avance dans les pages tant que la porte sélectionnée n'a encore aucun récit chargé — cette avance vit sur la carte et non dans le panneau, pour qu'une porte refermée en cours de chargement ne reparte pas de zéro.

  **Deux paginations distinctes coexistent sur la carte et ne doivent pas être confondues.** `doorPage` pagine l'**affichage** des portes quand le viewport ne peut pas toutes les porter : c'est un état local à la vue, sans aucun appel réseau, portant sur les catégories du document de configuration. La pagination du catalogue porte sur le **contenu** servi par `GET /catalog`. L'avance automatique du panneau de porte est donc clavetée sur `selectedCategoryID`, jamais sur `doorPage` : changer de page de portes ne déclenche aucun chargement, et une porte n'est pas une page de catalogue.
- **Paramètres serveur avant connexion.** `ServerSettingsPanel` (`Features/Settings`) règle les six services en mode **groupé** (hôte et schéma communs, un port par service) ou **unitaire** (une URL complète par service), `organization` compris. Il est atteignable depuis le menu de l'accueil anonyme (`WelcomeView.welcomeMenu`), depuis `AccountView` et depuis `AdministrationView`. Il est disponible en Release : c'est une exception documentée à l'invariant 5, prise parce qu'un appareil neuf n'avait aucun recours face à l'adresse compilée. Chaque service a un contrôle de connectivité (`EndpointProbe`) qui annonce une réponse HTTP, sans prétendre valider le service. La persistance passe par `EndpointStore`, inchangé.
- **Une seule barre d'onglets.** La barre `UniverseSection` de `PlayerExperienceView` a disparu ; ses quatre panneaux sont des actions du bandeau haut, qui se place dans la zone réservée par `HUDMetrics` via la zone sûre étendue par `GameShellView`. La carte est l'état de repos, plus un onglet.
- **Formulaire de connexion unique.** `SignInPanel` remplace les deux copies divergentes de `WelcomeView` et `AccountView`.
- **Carte sans plafond, disposée en espace écran.** `PlayerExperiencePresentation.doorPlacement(total:page:viewport:)` calcule les positions **en points écran**, pas en coordonnées monde. C'est la correction d'un défaut réel de la première version : les ancrages étaient posés dans le repère de la carte puis projetés par un aspect-fill, si bien qu'en portrait cinq portes sur six sortaient du cadre — davantage que n'en masquait le `prefix(5)` qu'elles remplaçaient — et qu'en paysage les portes se recouvraient et se volaient leurs zones tactiles dès quinze catégories. Les portes tiennent désormais chacune dans une cellule d'un pavage de la zone utile : ni débordement, ni recouvrement, sur aucun viewport testé. Quand l'écran ne peut pas toutes les porter lisiblement, une **pagination** annoncée prend le relais plutôt qu'un empilement muet. Les ancrages dessinés à la main restent utilisés là où ils tiennent réellement (`usesMapAnchors`), typiquement sur iPad en paysage. Chaque porte affiche sa progression (`doorProgress`), la même donnée que `LibraryView`. **Une porte reste une porte** : elle n'affiche pas les récits qu'elle sert, elle les ouvre. Le clic sélectionne la porte *et* ouvre `doorScenarioPanel` ; refermer le panneau ne perd pas la sélection, ouverture et sélection étant deux états distincts.
- **Confirmations et succès visibles.** `ConfirmationAction` + `.confirmation(_:)` couvrent déconnexion, sortie de démonstration, sortie de partie (bouton **et** fermeture du `fullScreenCover`, désormais non dismissible interactivement), suppressions d'unité, catégorie, parcours, familier, libellé, utilisateur, rôle, membership, affectation, et archivage Studio. `AppState.successMessage` alimente un bandeau annoncé à VoiceOver ; les opérations de jeu répétées (choix, narration) n'en déclenchent pas.
- **Identité et charte servies, consommées avant authentification.** `GET /client-bootstrap/{frontId}` (route **anonyme**, service Configuration) est consommé au démarrage par `AppState.loadClientBootstrap()`, avant toute connexion et quel que soit l'état d'authentification. Il alimente `gameName`, `tagline`, le dictionnaire de copies (`copy(_:fallback:)` lit les copies publiées, puis celles de l'amorce, puis le défaut compilé) et `isDemoAvailable` via `demoEnabled`. `BrandTheme.shared` applique `branding.theme.colors` et `branding.accentPalette` ; `GenEngineTheme` n'expose plus de couleur compilée mais des propriétés calculées lues sur cette palette, si bien qu'aucun des sites d'appel existants n'a changé. Un échec de la route laisse en place `BrandPalette.fallback` — les couleurs historiques — et journalise l'erreur sans la masquer.

  **Le substrat sombre est conservé délibérément.** Le moteur publie `colorScheme: "Light"` et une surface crème, destinés au client Web ; la coque iOS est une présentation immersive plein écran. Reprendre `surface` comme fond donnerait du texte crème sur crème. Sont donc repris du serveur les accents, les jetons nommés et la teinte d'encre, cette dernière assombrie pour servir de base au dégradé.
- **Jetons d'accent nommés rendables.** `StoryAccent` n'est plus une énumération fermée à trois cas qui perdait le jeton servi : c'est un porteur de jeton (`or`, `azur`, `encre`, `sauge`, `cuivre`, `aube`, `amber`…) résolu contre `branding.accentPalette`. Un jeton inconnu retombe sur une couleur lisible plutôt que de disparaître. **Limite connue** : `PublishedScenarioView` ne publie aucun accent, donc les cartes de scénario du catalogue conservent une alternance locale ; seuls catégories, parcours et familiers portent réellement un jeton servi.

- **Aide intégrée par champ, servie et non recopiée.** `GET /admin/configuration/field-descriptors` (service Configuration, permission `config.read`) sert **202 descripteurs** — `path`, `label`, `description`, `example`, `constraint`. Le client les consomme (`GenEngineAPI.configurationFieldDescriptors()`), les indexe par chemin (`ConfigurationFieldCatalog`) et les met en cache dans le répertoire Caches (`ConfigurationFieldCache`) : le catalogue décrit le **schéma**, pas un front, et ne bouge qu'avec la version du moteur. Les phrases restent maintenues côté moteur, où un test de complétude bidirectionnel interdit qu'un champ du document reste sans descripteur ; les recopier ici les ferait diverger.

  **Présentation retenue : repliée derrière un bouton ⓘ en fin de ligne**, pas dépliée sous le champ. C'est un arbitrage de densité assumé : le panneau « Accueil & aide » aligne une vingtaine de contrôles, et deux à trois lignes ajoutées par champ auraient transformé un formulaire de deux écrans en notice de six en portrait. Le coût vertical de l'affordance est nul ; seule la largeur perd la cible tactile de 44 pt. Le contenu s'ouvre en popover ancré au champ, y compris en compact (`presentationCompactAdaptation(.popover)`), pour ne pas perdre de vue le champ décrit.

  **L'accessibilité ne reconduit pas cet arbitrage.** Un lecteur d'écran ne survole pas un encart : la description et la contrainte sont posées en `accessibilityHint` **du champ lui-même**, donc annoncées avec lui, et le bouton ⓘ est retiré de l'arbre d'accessibilité (`accessibilityHidden`). Un utilisateur VoiceOver entend toute l'aide sans rien ouvrir et ne parcourt aucun élément supplémentaire.

  **Repli.** Un chemin absent du catalogue — moteur plus ancien, `config.read` refusé, moteur injoignable — rend le champ **inchangé** : ni bouton, ni encart vide, ni texte inventé. Couvert par `ConfigurationFieldHelpTests`.

  **Limite.** L'adressage des six services (`ServerSettingsPanel`) est un réglage **de l'appareil** : il n'appartient pas au document de configuration, n'apparaît dans aucun descripteur servi, et le moteur ne peut pas le décrire. Ses trois textes d'aide sont donc écrits dans le client et assumés comme locaux, avec la même présentation et le même contrat d'accessibilité.
- **Décodage tolérant des états servis.** `InteractionKind` et `SessionStatus` portent un cas `unknown(String)` et ne jettent plus jamais. Ce n'était pas une précaution théorique : le moteur sert le schéma v6 avec `kind: "Document"`, absent de l'énumération, ce qui faisait échouer le décodage **entier** de `CurrentStep` — donc bloquait la session au lieu de la dégrader. Le moteur restant autoritatif sur les états narratifs et en ajoutant au fil des versions, une énumération fermée sur une valeur servie est un blocage différé. Couvert par `TolerantStepDecodingTests`.
- **Documents consultables (schéma v6).** `CurrentStep` porte `document`, `isOptional` et `exitChoices`. `ConsultableDocument` modélise les blocs `paragraph`, `lines` et `table` discriminés par `$type` ; un `$type` inconnu ou une charge utile malformée devient `.unsupported`, qui **occupe toujours son rang** — seule identité qu'un bloc possède — et que la vue ignore silencieusement pendant que le reste se rend. `nature`, `marker` et `unit` sont déclarés `X | string` au contrat et sont donc décodés en `String`, interprétés à la présentation : les typer en énumération fermée aurait reconduit exactement le défaut ci-dessus.

  `DocumentPresentation` est un modèle Swift pur, sans SwiftUI, porté depuis `document-presentation.ts` du client Web : libellés de nature, famille de rendu dérivée de la nature *puis* des blocs, marqueurs, phrase d'échantillon accordée en genre et en nombre, et pourcentage plancher à 1 %. Le plancher n'est pas cosmétique : 6 sur 412 arrondit à 0, et une jauge vide se lit comme « rien n'est montré » alors que six lignes le sont. Le séparateur de milliers est posé explicitement (U+202F) plutôt que délégué à `Locale`, la locale de l'appareil n'étant pas forcément française. Couvert par `DocumentPresentationTests`, porté des 16 tests du client Web.

  `POST /sessions/{id}/document-consultations` (`GenEngineAPI.consultDocument`) ne part **que** sur un clic explicite sur « Consulter ce document » : côté moteur c'est une commande joueur idempotente qui consomme un tour, pas une lecture. Le document est donc rendu **avec** ses `exitChoices`, jamais à leur place — consulter reste un choix qui coûte.

  **Accessibilité.** La gouttière (`+`, `−`, `!`) et la couleur de ligne sont décoratives et retirées de l'arbre d'accessibilité ; le marqueur est énoncé en toutes lettres (« Ajouté », « Erreur ») dans le libellé de la ligne, avec son rang. Une rangée de table est lue en entier, colonne par colonne, plutôt qu'en cellules isolées. La table défile dans son propre conteneur horizontal : le corps de l'écran ne défile jamais latéralement.
- **Statistiques joueur et récompenses conditionnelles sur le profil.** `GET /me/experience` sert désormais deux champs additifs, `stats` et `rewards`, lus par `PlayerExperienceView` (`APIModels.swift`). Les deux sont **optionnels et tolérants** : absents, vides ou avec une entrée malformée, ils dégradent en liste sans jamais faire échouer le décodage de l'expérience (`LossyArray`, même intention que `TolerantBlock`). Le `mode` d'une récompense et le `type` d'un octroi sont décodés en `String` et interprétés à la présentation par une énumération à repli (`ProfilePresentation.RewardMode`, `GrantNature`) — jamais en énumération fermée qui jetterait sur une nature ajoutée par un moteur plus récent. `ProfilePresentation` (modèle Swift pur, sans SwiftUI) borne la valeur d'une statistique à son plafond publié à la lecture, sépare les récompenses obtenues des récompenses à venir et calcule la progression par condition (`current`/`target`) exactement comme `finale` la sert. `AccountView` affiche, pour un joueur connecté, chaque statistique (libellé, jauge doublée d'un texte, description) et chaque récompense — obtenue avec sa date, à venir avec ce qui reste, jamais présentée comme une porte fermée. Couvert par `ProfileStatsRewardsTests` (15 tests : absence, vide, entrée malformée écartée, `mode` inconnu, octroi de nature inconnue, bornage, partition, statut, progression). **Aucun rendu observé à l'écran** : la pile locale sert ces blocs vides, seule la forme a été vérifiée.
- **Démonstration Diapason hors ligne.** 23 scènes exactement dans `DemoStory` (`StoryModels.swift:123-291`). Un nœud d'accueil ouvre sur trois situations — La note de service (Lucidité), La réunion où personne ne doute (Courage), La spécification avant le code (Transmission). Douze fins suivant la convention `fin-accord-*`, `fin-partielle-*`, `fin-rupture-*` : exactement 6 ruptures, 2 par situation. `DemoNode.title`, `DemoNode.outcome` et `DemoChoice.posture` restent locaux à la frontière de démonstration. Aucun appel réseau.

### Fuites de marque : ce qui a été corrigé, ce qui est gardé

Le partage retenu : « GenEngine » est le nom du **moteur**. Il reste légitime dans une mention technique destinée à l'exploitant ou dans un identifiant ; il ne l'est pas là où l'utilisateur devrait lire le nom de **sa** configuration.

Corrigé — ces textes lisent désormais `state.gameName`, donc l'`applicationName` servi par l'amorce :

| Emplacement | Avant |
| --- | --- |
| `Info.plist` · `CFBundleDisplayName` | l'icône d'accueil affichait « GenEngine » |
| `ServerSettingsPanel` · introduction | « GenEngine appelle six services… » |
| `AppState.gameName` · dernier repli | `?? "GenEngine"` → nom du paquet |
| `AppState` · synopsis d'histoire publiée | « …votre environnement GenEngine. » |
| `AppState` · synopsis de session reprise | « …depuis le moteur GenEngine. » |
| `AppState` · titre de session sauvegardée | « Histoire GenEngine » |
| `PlayerView` · titre de partie | `?? "GenEngine"` |
| `AdministrationView` · sur-titre de scène | `?? "GenEngine"` |
| `AdministrationView` · origine de compte | « Compte GenEngine » |

`WelcomeView` (« les six services qui servent … ») lisait **déjà** `gameName` : la fuite observée au simulateur venait d'une compilation de `main`, où le correctif n'est pas encore fusionné.

Gardé délibérément :

- **Identifiants et clés de stockage** — `genengine.saved-sessions.v1`, `genengine.audio.settings.v1`, `genengine.service-endpoints`, `genengine.intro.last-version`, `com.jordanlacroix.genengine`, `genengine.familiar.asset-pack`. Les renommer orphelinerait les données déjà écrites sur les appareils, sans qu'aucun utilisateur ne voie jamais ces chaînes.
- **Schéma d'URL `genengine://auth`**, y compris la phrase d'`AdministrationView` qui demande de l'enregistrer dans Entra. C'est la valeur littérale à recopier dans un portail Azure : la traduire la rendrait fausse.
- **`FamiliarAssetPack`** · licence et attribution (« GenEngine project asset… », « Illustration originale générée pour GenEngine »). C'est un relevé de provenance, où le nom du projet producteur est l'information exacte.
- **Nom de cible, `PRODUCT_NAME` et identifiant de paquet** restent « GenEngine » : c'est l'identité de code, pas une identité affichée.

## Manques honnêtes et points cassés

Ce sont les points à ne pas présenter comme résolus.

- **Observé au simulateur, iPhone et iPad, session connectée.** L'accueil anonyme, la scène d'introduction, le menu, la coque HUD, l'accueil de démonstration et une partie de démonstration ont été **regardés tourner** sur iPhone 17 Pro / iOS 26.5, contre la pile locale. Trois défauts de rendu bloquants y ont été trouvés et corrigés (voir ci-dessous).

  L'écran « Mon univers » a ensuite été **regardé tourner sur iPad Pro 13 pouces / iOS 26.5, en portrait et en paysage, connecté** au compte `diapason-admin` de la pile locale. Le rail vertical a donc enfin été rendu. Trois défauts bloquants y ont été trouvés et corrigés (voir ci-dessous). Le non-regression iPhone a été revérifié à l'écran, connecté, après ces correctifs.

  **L'écran de paramètres, la bibliothèque, le Studio et l'administration n'ont toujours pas été observés**, non plus qu'aucun rendu sur appareil physique ni en Dynamic Type agrandi.

  **L'administration et l'écran de paramètres ont depuis été observés**, connectés à la pile locale, sur iPhone 17 Pro en portrait et sur iPad Pro 13 pouces en portrait **et** en paysage — voir « Harnais de capture » ci-dessous. Y ont été vus : l'accueil anonyme, le menu anonyme, `ServerSettingsPanel`, le panneau « Jeu & histoire » de l'administration avec ses boutons d'aide, et le popover d'aide ouvert sur `game.name` affichant bien le texte **servi** par le moteur (« Le titre affiché partout dans les clients et dans l'introduction. », contrainte « Obligatoire. », exemple « Le Diapason »). Aucun débordement ni recouvrement n'a été constaté sur ces écrans, dans aucune des orientations rendues.

  **La bibliothèque et le Studio n'ont toujours pas été observés**, non plus qu'aucun rendu sur appareil physique ni en Dynamic Type agrandi. Le popover d'aide n'a été ouvert **qu'en portrait sur iPhone** : en paysage sur iPad, la tape en coordonnées du harnais a manqué la cible et le popover n'a pas été rendu. Ne pas présenter ce cas comme vérifié.
- **Harnais de capture d'écran (`GenEngineUITests`).** Le simulateur ne reçoit pas la frappe clavier — elle est captée comme raccourcis — et `simctl` n'injecte aucune touche : sans pilotage du bureau, tout écran situé derrière une connexion est **inatteignable** pour un agent. `ScreenCaptureTests` contourne ce point en pilotant l'application depuis l'intérieur du simulateur et en joignant une capture par écran au bundle de résultat. Ce n'est **pas** un test : il n'assure presque rien et un passage vert ne dit rien de la lisibilité d'un écran. Il vit dans le schéma **`GenEngineScreens`**, délibérément hors du schéma `GenEngine` : la CI ne doit pas payer un lancement d'application par exécution.

  ```bash
  xcodebuild test -project GenEngine.xcodeproj -scheme GenEngineScreens \
    -destination 'platform=iOS Simulator,id=<UDID>' -resultBundlePath /tmp/screens.xcresult
  xcrun xcresulttool export attachments --path /tmp/screens.xcresult --output-path <dossier>
  ```

  Deux pièges rencontrés, tous deux corrigés dans le harnais : `CODE_SIGNING_ALLOWED=NO` prive l'application de son entitlement de trousseau et fait échouer la connexion sur `Keychain error (-34018)` — ne pas le passer pour ce schéma ; et une session survit d'une exécution à l'autre, ce qui envoyait la frappe dans le champ de recherche de la bibliothèque — réinitialiser par `xcrun simctl uninstall` puis `xcrun simctl keychain <UDID> reset`.

  Défauts trouvés en regardant, tous corrigés et re-vérifiés à l'écran :
  1. **Le HUD recouvrait l'écran entier.** La barre basse est un `ScrollView` horizontal, gourmand sur son axe transverse : il prenait toute la hauteur restante sous la barre haute, et son fond `.ultraThinMaterial` floutait tout le contenu derrière lui. L'écran de démonstration paraissait ne jamais charger — il était rendu, mais illisible sous un verre dépoli plein écran, les onglets flottant au centre. Corrigé par `.fixedSize(horizontal: false, vertical: true)` (`GameShellView.swift`).
  2. **`StoryCanvas` imposait sa largeur au contenu.** Ses halos décoratifs portent une taille intrinsèque fixe de 460 pt ; placés en frères dans un `ZStack`, ils imposaient cette largeur au conteneur. Sur un iPhone de 402 pt, tout le contenu était mis en page trop large et débordait des deux côtés — texte coupé à gauche **et** à droite, titre collé au bord. Les halos sont passés en `overlay` d'un dégradé souple, où ils ne participent plus au calcul de taille.
  3. **Une scène d'introduction sans image réservait la place de l'image absente.** Depuis le retrait des liens externes côté moteur, `imageUrl` est `null` et la mise en page laissait un tiers d'écran noir. La scène se referme désormais sur son texte (`ViewThatFits(in: .vertical)`) et ne bascule en version défilante que si le texte déborde réellement.

  Défauts trouvés en regardant l'iPad, tous corrigés et re-vérifiés à l'écran en portrait **et** en paysage :

  1. **Le décor de la carte élargissait toute la coque, hors de l'écran.** `immersiveWorld` posait `Image("WorldMap").resizable().scaledToFill()` en frère de `ZStack` : l'image y imposait sa taille intrinsèque. Mesuré au `GeometryReader`, la destination se mesurait **1359 pt de large dans une zone de 1236**. La `ZStack` adoptait cette largeur, puis toute la coque se recentrait dedans et partait d'une soixantaine de points vers la gauche, hors de l'écran — « Le Diapason » réduit à « apason », libellés du rail amputés (« …univers », « …othèque », « …inistra… »). Le défaut était trompeur : **les géométries rapportées par SwiftUI restaient justes**, c'est l'ancêtre qui était trop large. Corrigé en passant le décor par `sceneBackdrop`, où il ne participe plus au calcul de mise en page. `frame(maxWidth:maxHeight:)` suivi de `clipped()` a été essayé et **ne suffit pas** : vérifié à l'écran, le débord persiste.

     C'est la même classe de défaut que le deuxième défaut iPhone (`StoryCanvas`), et exactement ce contre quoi la remarque de `sceneBackdrop` mettait déjà en garde : `immersiveWorld` ne l'avait simplement jamais adopté. La cause n'était **ni** `railWidth`, **ni** `safeAreaInset` — les deux hypothèses de départ, l'une et l'autre écartées par la mesure.
  2. **Le bandeau interne voilait le tiers central de la carte.** Le `ScrollView` horizontal de `gameHUD` n'avait pas la contrainte `.fixedSize(horizontal: false, vertical: true)` reçue par la barre basse au premier défaut iPhone : il prenait toute la hauteur sous la barre haute, et son `glassPanel` voilait une colonne pleine hauteur de 620 pt. Sur iPad, trois portes sur six disparaissaient derrière. Corrigé en compact, le défaut avait survécu en régulier.
  3. **Les libellés du bandeau étaient rognés par leur panneau.** `LazyHStack` ne publie pas de hauteur idéale fiable : le `fixedSize` mesurait le bandeau trop court et « Journal », « Tierce », « Magasin », « Aide » étaient coupés par le bord du verre. Les deux bandeaux (`gameHUD` et la barre basse de la coque) sont repassés en `HStack` — quatre à six entrées, la paresse n'y gagnait rien.
- **Pagination jamais vérifiée de bout en bout.** GenEngine#55 est désormais fusionnée côté backend, mais le client n'a été confronté qu'au contrat documenté et à des doubles de test qui en reproduisent la sémantique — filtre, `Skip`/`Take`, `total` sur l'ensemble filtré. **Aucun appel réel à un serveur renvoyant la nouvelle enveloppe n'a eu lieu** depuis ce dépôt : ni le nombre de pages réellement servies, ni le comportement de la recherche sur des données réelles n'ont été observés. C'est la limite principale de cette tranche.
- **Comptages par catégorie encore partiels.** Les cartes de catégorie de la bibliothèque et la progression des portes comptent les récits **déjà chargés**, pas ceux que le serveur déclare pour la catégorie. Le chiffre se corrige au fil des pages ; une agrégation par catégorie côté serveur serait la vraie réponse et n'existe pas.
- **Valeurs de `HUDMetrics` partiellement calibrées.** `railWidth` est passé de 108 à **140**, calibré à l'écran sur iPad Pro 13 pouces : à 108, « Administration » — un mot insécable — et « Bibliothèque » ne tenaient pas. À 140 les cinq libellés par défaut tiennent sans troncature ; les libellés restant configurables par le serveur, `minimumScaleFactor` demeure le filet. `topBarHeight: 74` et `bottomBarHeight: 96` restent des estimations : la barre basse mesure environ 79 pt sur iPhone 17 Pro, `bottomBarHeight` sur-réserve donc un peu, sans rien recouvrir.
- **Bandeau interne vu à l'écran.** L'écran « Mon univers » a été ouvert, connecté, sur iPhone et sur iPad dans les deux orientations. Deux défauts y ont été trouvés et corrigés (deuxième et troisième défauts iPad ci-dessus).
- **Écran de paramètres jamais vu à l'écran.** `ServerSettingsPanel` compile et ses règles d'adressage sont couvertes par `EndpointDraftTests`. Sa mise en page, son comportement clavier et le rendu du contrôle de connectivité n'ont été observés ni en simulateur ni sur appareil.

- **Écran de paramètres partiellement vu.** `ServerSettingsPanel` a été rendu au simulateur sur iPhone et sur iPad : l'en-tête, le sélecteur de mode et le sélecteur de schéma tiennent, et le panneau défile correctement dans le `ScrollView` de `HUDOverlayPanel`. **Son comportement clavier et le rendu du contrôle de connectivité n'ont toujours pas été observés** : le harnais n'a pas saisi d'adresse ni déclenché de test de joignabilité.
- **Disposition des portes prouvée, mais non observée.** `DoorLayoutTests` vérifie en points écran, sur cinq viewports réels (iPhone portrait et paysage, iPhone SE, iPad portrait et paysage) et jusqu'à cinquante catégories, qu'aucune porte ne sort du cadre, qu'aucune paire ne se recouvre, que la taille reste au-dessus de la cible tactile et que la pagination couvre bien toutes les catégories. Ces garanties sont géométriques, pas visuelles : la lisibilité réelle d'une page pleine, le confort de la pagination et le comportement en Dynamic Type agrandi demandent toujours un rendu. Les insets du champ des portes (84 en haut, 200 en bas, plafonnés en proportion sur écran court) sont, comme `HUDMetrics`, des estimations non calibrées.
- **Aucun document jamais rendu à l'écran.** `DocumentSheetView` compile et sa logique de présentation est couverte par 25 tests, mais **aucun document n'a été affiché**, ni en simulateur ni sur appareil. Ni la lisibilité d'une table qui défile latéralement dans un cadre étroit, ni le comportement en Dynamic Type agrandi, ni les annonces VoiceOver réelles n'ont été observés : ils sont écrits, pas vérifiés. La consultation n'a pas non plus été jouée contre un moteur réel — `POST /sessions/{id}/document-consultations` n'a été confronté qu'au contrat documenté, jamais à une réponse serveur.

  **Arbitrage assumé sur les sorties.** Le client Web place le document « à côté » des `exitChoices` ; en colonne étroite sur iPhone, elles sont rendues **sous** le document, dans le même groupe visuel. L'invariant qui compte — consulter n'est pas un passage obligé, les sorties restent atteignables sans avoir consulté — est tenu ; la disposition côte à côte ne l'est pas.
- **Aucun pack audio.** Aucun `audio-manifest.json` n'est livré et le dépôt ne contient aucun fichier son. Il n'existe **ni boucle d'ambiance, ni musique**. L'application est donc silencieuse ; le panneau de son l'annonce plutôt que de laisser croire à une panne. Le backend ne publie aucun contrat audio.
- **Aucun portrait de personnage.** Le catalogue d'assets ne contient que quatre illustrations : `FamiliarTierce` (le familier), `IntroGateway`, `TutorialKey` et `WorldMap`. Aucun portrait humain.
- **Deux illustrations sur quatre sont désormais des SVG produits pour Diapason.** `WorldMap` (`diapason-domains.svg`) est un plan de systèmes — six champs reliés par un réseau, désaturés pour laisser ressortir l'accent de chaque porte — et `FamiliarTierce` (`familiar-tierce.svg`) encode la forme `tuning-fork` et le ton `Warm` déclarés par la configuration. Les six `doorAnchors` sont les centres des champs dessinés : l'image et le code se modifient ensemble. `IntroGateway` et `TutorialKey` **restent des JPEG d'heroic fantasy** hérités d'une itération antérieure, et contredisent la configuration de référence.
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

La priorité reste de **regarder l'application tourner**, mais sur ce qui ne l'a pas encore été : l'écran de paramètres, la bibliothèque, le Studio et l'administration, et en Dynamic Type agrandi. La passe iPhone puis la passe iPad ont chacune trouvé trois défauts bloquants que build et tests laissaient passer ; il n'y a pas de raison de croire les écrans restants indemnes.

La priorité reste de **regarder l'application tourner**, mais sur ce qui ne l'a pas encore été : la bibliothèque, le Studio, et n'importe quel écran en Dynamic Type agrandi. La passe iPhone puis la passe iPad ont chacune trouvé trois défauts bloquants que build et tests laissaient passer ; il n'y a pas de raison de croire les écrans restants indemnes. `GenEngineScreens` rend maintenant ce regard reproductible — l'étendre à ces écrans est peu coûteux.

Le recouvrement des portes par les cartes de récit du `storyDock` est **corrigé**, mais par la suppression du dock plutôt que par un réglage de marges : les récits d'une porte vivent désormais dans un panneau superposé ouvert au clic sur la porte (`doorScenarioPanel`, bâti sur `HUDOverlayPanel`), et plus aucun calque permanent ne dispute le bas de la carte aux portes. `doorFieldBottomInset` retombe donc de 200 à 72, la place que réclame la seule pagination d'affichage. **Ce correctif n'a pas été observé à l'écran** : build et tests sont verts, ce qui ne dit rien du rendu. La limite de `DoorLayoutTests` reste entière — il prouve que les portes ne se recouvrent pas *entre elles*, pas qu'un autre calque les épargne.

`railWidth` est calibré ; `topBarHeight` et `bottomBarHeight` restent à mesurer.

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
