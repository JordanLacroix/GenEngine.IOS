<div align="center">

# GenEngine iOS

**Client SwiftUI natif pour jouer, découvrir et tester les récits interactifs GenEngine sur iPhone et iPad.**

[![iOS](https://github.com/JordanLacroix/GenEngine.IOS/actions/workflows/ios.yml/badge.svg)](https://github.com/JordanLacroix/GenEngine.IOS/actions/workflows/ios.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![Status](https://img.shields.io/badge/statut-client%20connecté-2EA44F)](#état-du-projet)
[![License](https://img.shields.io/badge/licence-non%20définie-lightgrey)](#licence)

[Le produit](#le-produit) · [Démarrage rapide](#démarrage-rapide) · [Architecture](#architecture) · [Roadmap](#roadmap) · [Documentation](#documentation) · [Contribuer](#contribuer)

</div>

---

## Le produit

**GenEngine est un moteur narratif entièrement paramétrable, livré avec son interface de configuration.** Il est vendu aux **écoles d’ingénieurs, aux entreprises et aux organismes de formation professionnelle**, qui l’exploitent comme un outil de mise en situation : le client achète un moteur et une configuration, pas une histoire figée.

**« Le Diapason »** est la configuration de référence, jouée à la première initialisation et industrialisable par instance client. Son cadre : 2026, notre monde, l’IA partout, le joueur apprenti en école d’ingénieurs. Six **postures** — Lucidité, Discernement, Arbitrage, Courage, Transmission, Autonomie — remplacent les catégories par matière, pour dix scénarios. La bible d’univers vit dans le dépôt backend (`specs/domain/diapason`).

Ce dépôt est le **client iOS**. Le serveur reste l’autorité sur les scénarios, les sessions, les transitions et les permissions ; le client présente les états reçus et transmet les intentions de l’utilisateur. Il n’embarque pas le moteur narratif.

Le dépôt conserve deux parcours explicitement séparés :

- un mode connecté couvrant Identity, Authoring, Play, Configuration, PlayerExperience et Organization ;
- une démonstration hors ligne, réservée au visiteur anonyme, destinée à la découverte commerciale et à la revue produit.

> **Rendu non vérifié.** La coque HUD plein écran et la démonstration Diapason n’ont jamais été observées sur simulateur ni sur appareil : elles ont été validées par build et tests uniquement. Les descriptions visuelles de ce README décrivent l’intention du code, pas un rendu constaté. Voir [`specs/handoff.md`](specs/handoff.md).

## État du projet

| Capacité | État |
|---|---|
| Accueil et bibliothèque éditoriale | ✅ Disponible |
| Démonstration hors ligne | ✅ Disponible |
| Authentification et stockage Keychain | ✅ Connecté |
| Catalogue public Authoring | ✅ Connecté — paginé, recherche serveur |
| Choix, quiz et texte libre confirmé | ✅ Connecté à Play |
| Pause, reprise et arbre explicable | ✅ Connecté à Play |
| Outils Authoring et journal brut | ✅ Disponibles en Debug uniquement |
| Paramètres serveur avant connexion | ✅ Disponible en Release |
| Confirmations avant action conséquente | ✅ Disponibles |
| Support universel iPhone/iPad | ✅ Configuré |
| Navigation pilotée par les permissions RBAC | ✅ Connectée |
| Familier personnalisable, portefeuille et magasin | ✅ Connectés |
| Studio de génération contextualisée | ✅ Connecté |
| Administration jeu, auth, IA, économie et rôles | ✅ Connectée |
| Microsoft Entra ID (Authorization Code + PKCE) | ✅ Connecté |
| Introduction publique versionnée et skippable | ✅ Pilotée par Configuration |
| Bootstrap et tutoriel persistant | ✅ Pilotés par PlayerExperience |
| Carte, recherche, journal et maîtrise | ✅ Connectés au moteur |
| Compagnon illustré, aide et fréquence | ✅ Personnalisables |
| Intro rejouable, prologue illustré et clé universelle | ✅ Pilotés par la configuration |
| Carte illustrée à portes et interactions d’écran | ✅ Matérialisées nativement |
| Packs visuels de familier importables | ✅ Assets locaux, sans propriété |
| Bilan de fin avec chemin et gains | ✅ Démo et sessions connectées |
| Graphe de fin de quête et mémoire cumulée | ✅ Projeté depuis `GET /sessions/{id}/tree` et les maîtrises |
| Carte d’un scénario consultable hors partie | ✅ Projetée depuis `GET /scenario-versions/{id}/tree` et les maîtrises |
| Journal francisé et sans projections dupliquées | ✅ Normalisé côté présentation |
| Portes ancrées aux repères de la carte | ✅ Adaptées à `scaledToFill` |
| Périodes métier et import CSV de memberships | ✅ Prévalidation, rapport d’erreurs et application idempotente |
| Affectations de parcours et catalogue filtré | ✅ Résolues côté serveur et reflétées nativement |
| Présentation plein écran pilotée par un HUD | ⚠️ Codée (barre basse iPhone, rail iPad), jamais vue à l’écran |
| Démonstration réservée à l’état anonyme | ✅ Fermée dans le modèle, pas seulement dans les vues |
| Démonstration « Le Diapason » (23 scènes) | ⚠️ Codée et testée, jamais vue à l’écran |
| Audio configurable et désactivable | ⚠️ Abstraction et réglages prêts, aucun pack d’assets livré |
| Ambiance, musique et portraits de personnage | ❌ Inexistants dans le pack d’assets |
| Game over de première classe | ❌ Absent du moteur ; l’échec est narratif uniquement |

## Démarrage rapide

### Prérequis

- Xcode 26 ou version ultérieure ;
- Swift 6 ;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44 ou version ultérieure.

### Générer et lancer

```bash
brew install xcodegen
xcodegen generate
open GenEngine.xcodeproj
```

Le projet Xcode généré est volontairement ignoré. [`project.yml`](project.yml) est la source de vérité.

Sélectionnez **Explorer la démo** pour parcourir l’application sans backend.

### Connecter le backend local

Depuis le dépôt backend :

```bash
docker compose up --build --detach --wait
```

Les adresses des six services se règlent depuis **Paramètres du serveur**, disponible en Release et **avant toute connexion** : depuis le menu de l’écran d’accueil, depuis **Compte**, ou depuis **Administration → Environnement & diagnostic**. Deux modes sont proposés :

- **groupé** — un hôte et un schéma communs, un port par service (5201 Authoring, 5202 Play, 5203 Identity, 5204 Configuration, 5205 Player Experience, 5206 Organization) ;
- **unitaire** — une URL complète par service, pour un déploiement réparti sur plusieurs machines.

Chaque service dispose d’un contrôle de connectivité. Une réponse HTTP prouve seulement que l’adresse répond : elle ne valide ni la version, ni les permissions, qui restent décidées par le service. Le réglage est local à l’appareil et ne contient aucun secret ; les journaux bruts et les outils Authoring restent, eux, réservés aux builds Debug.

Le simulateur utilise `localhost` ; un appareil physique exige des endpoints HTTPS joignables. App Transport Security n’est pas désactivé globalement.

| Service | URL locale |
|---|---|
| Authoring | `http://localhost:5201` |
| Play | `http://localhost:5202` |
| Identity | `http://localhost:5203` |
| Configuration | `http://localhost:5204` |
| Player Experience | `http://localhost:5205` |
| Organization | `http://localhost:5206` |

Pour Entra ID, déclarez l’application iOS comme client public et ajoutez `genengine://auth` à ses URI de redirection. Le client utilise Authorization Code avec PKCE puis échange le jeton Entra contre un jeton GenEngine.

Les jetons sont conservés dans Keychain. Les préférences d’endpoints et références opaques de sessions sont stockées dans `UserDefaults`. L’état narratif reste exclusivement autoritatif dans Play.

### Identité et charte de la configuration

Au démarrage, **avant toute authentification**, le client appelle `GET /client-bootstrap/{frontId}` sur le service Configuration. Cette route est anonyme : c'est elle qui donne à l'application son nom, son accroche, ses libellés et sa charte, exactement comme pour le client Web.

| Champ consommé | Effet dans le client | Défaut si absent |
| --- | --- | --- |
| `applicationName` | Nom affiché dans la barre haute, l'accueil et les messages | `game.name` publié, sinon `GenEngine` |
| `tagline` | Titre de l'écran de connexion | copie `welcome.title`, sinon un défaut compilé |
| `labels` | Dictionnaire de copies | copies publiées d'abord, puis ce dictionnaire, puis le défaut compilé |
| `branding.theme.colors` | Rôles de couleur (`accent`, `accentAlt`, `surface`, `ink`…) | `BrandPalette.fallback`, les couleurs historiques |
| `branding.accentPalette` | Jetons nommés (`or`, `azur`, `encre`, `sauge`, `cuivre`, `aube`) portés par catégories, parcours et familiers | correspondance connue vers un rôle local, sinon une couleur lisible |
| `demoEnabled` | Ouvre ou ferme l'entrée de démonstration anonyme | `true` — un moteur injoignable ne doit pas fermer la seule porte hors ligne |

Portée : un front (`frontId`), résolu côté service propriétaire. Validation : chaque couleur doit être un hexadécimal `#rrggbb`, `#rrggbbaa` ou `#rgb` ; une valeur illisible est ignorée et laisse le repli en place plutôt que d'inventer une couleur. Si la route entière est injoignable, le client démarre sur ses valeurs de repli et journalise l'échec — il ne le masque pas.

Le client conserve délibérément son **substrat sombre** même lorsque la configuration publie `colorScheme: "Light"`. Le moteur décrit là une surface destinée au client Web ; la coque iOS est une présentation immersive plein écran, où reprendre `surface` comme fond donnerait du texte crème sur crème. Sont repris du serveur les accents, les jetons nommés et la teinte d'encre, cette dernière assombrie pour servir de base au dégradé de fond.

### Packs visuels de familier

L’espace Compagnon importe un manifeste JSON de schéma `1` depuis l’app Fichiers. Il accepte un asset inclus dans l’application ou un portrait HTTPS, avec licence et attribution obligatoires. Le manifeste reste une préférence locale non sensible dans `UserDefaults` : il ne crée ni propriété, ni achat, ni progression. PlayerExperience demeure l’autorité sur la sélection du familier.

Le configurateur s’adapte en deux colonnes sur iPad et en pile sur les largeurs compactes. Les valeurs contractuelles restent inchangées à l’enregistrement tandis que leurs libellés sont présentés en français.

Un exemple est fourni dans [`GenEngine/Resources/tierce-familiar-pack.json`](GenEngine/Resources/tierce-familiar-pack.json).

### Présentation plein écran et HUD

L’application n’utilise plus ni `TabView`, ni `NavigationStack`, ni barre de navigation système. `GameShellView` affiche la destination courante bord à bord et superpose un HUD :

- barre haute permanente (nom du jeu, état de chargement, son) ;
- navigation en barre basse sur largeur compacte (iPhone), en rail vertical à gauche sur largeur régulière (iPad) ;
- menus rendus en panneaux superposés (`HUDOverlayPanel`) plutôt qu’en écrans empilés ;
- partie présentée en `fullScreenCover`, avec son propre HUD et sa carte en panneau.

Le HUD flotte : il ne réserve pas de place, mais le contenu défilant dégage sa zone via `safeAreaPadding`, de sorte qu’aucune commande ne reste sous la surcouche. Le HUD est un conteneur d’accessibilité voisin du contenu : il n’est jamais `accessibilityHidden`, ne piège pas le focus VoiceOver, et seuls les panneaux réellement modaux portent le trait `isModal`. Chaque cible tactile fait au moins 44 points et chaque état est porté par un symbole et un texte, jamais par la couleur seule.

`AppState.destinations` calcule les destinations exposées selon l’authentification puis les permissions, et `AppState.activeTab` ramène la sélection dans cette liste : un changement d’état ne laisse jamais le HUD sur une destination disparue. Masquer une destination reste une commodité d’interface et ne remplace pas l’autorisation côté serveur.

**Limites assumées de cette coque, à ne pas prendre pour des acquis :**

- elle n’a **jamais été lancée** en simulateur ni sur appareil ; tout ce qui précède décrit le code, pas un rendu observé ;
- les valeurs de `HUDMetrics` (`topBarHeight: 74`, `bottomBarHeight: 96`, `railWidth: 108`) sont des estimations non calibrées à l’écran ; seul `minimumTarget: 44` est une contrainte réelle ;
- `PlayerExperienceView` conserve **son propre HUD de sections** sous le HUD de la coque, à la même largeur maximale. Cette cohabitation n’a jamais été vue à l’écran et n’a pas été arbitrée.

### Ce que joue la démonstration

La démonstration hors ligne échantillonne la configuration de référence
« Le Diapason », décrite dans la bible d’univers du dépôt `GenEngine`
(`specs/domain/diapason`). Elle ne raconte pas une histoire mais **trois
situations**, pour montrer l’étendue des usages qu’une école ou une entreprise
achète. Un nœud d’accueil laisse le visiteur choisir :

| Situation | Posture | Usage démontré |
|---|---|---|
| La note de service | Lucidité | établir la provenance d’un document que personne ne revendique |
| La réunion où personne ne doute | Courage | conflit professionnel : objecter au bon moment, dans la bonne forme |
| La spécification avant le code | Transmission | apprentissage d’une matière — Spec Driven Development |

Chaque situation se termine en quelques minutes. Les douze fins reprennent la
convention de nommage du contenu canonique — `fin-accord-*`, `fin-partielle-*`,
`fin-rupture-*` — et chacune des trois situations mène à exactement deux
ruptures, soit six au total, qui obligent à recommencer.

Trois des six postures seulement sont exercées par les choix de la
démonstration. Discernement et Autonomie n’apparaissent que sur des entrées
« bientôt disponible », et **Arbitrage n’est encore employée nulle part** en
dehors de sa déclaration.

Le moteur ne connaissant que `isEnding`, la nature d’une fin est portée par
`DemoNode.outcome`, **local à la démonstration** et jamais présenté comme un
contrat serveur. Sur une rupture, le bilan fait de « Reprendre depuis le début »
l’action principale : l’obligation de recommencer est portée par le texte et par
l’interface, pas par un drapeau moteur qui n’existe pas.

### Démonstration réservée à l’état anonyme

La démonstration hors ligne est un argument de découverte, pas une fonctionnalité du produit connecté. Une fois le joueur authentifié :

- `AppState.isDemoAvailable` passe à faux et `DemoStory.library` quitte le catalogue ;
- la destination `Accueil`, qui met la démonstration en avant, disparaît du HUD ;
- `unlockDemo()`, `startDemo()` et `open(_:)` refusent la fixture, avec un message explicite dans le dernier cas ;
- une authentification en cours de démonstration referme immédiatement l’accès et la partie hors ligne.

La fermeture est portée par le modèle, pas par un masquage de vue. Deux limites connues : `AppState.demoQuestGraph` n’est référencé par aucune vue, donc la mémoire cumulée de démonstration n’apparaît **jamais** dans le journal, y compris pour un visiteur anonyme ; et `discardDemoAccess()` ne purge pas `demoDiscoveredNodeIDs` / `demoDiscoveredChoiceIDs`, qui survivent à la connexion.

Pour un visiteur anonyme, la démonstration reste intégralement jouable sans réseau : elle ne déclenche aucun appel HTTP.

### Son

Le son passe par `GameAudioDirector`, qui ne connaît que le protocole `GameAudioEngine`. Trois couches indépendantes existent — ambiance liée au lieu de l’application, musique et signaux — chacune avec son volume, et le tout est désactivable à tout instant depuis la barre haute du HUD.

**Aucun pack audio n’est livré à ce jour** : le dépôt ne contient ni fichier son, ni manifeste. Il n’existe **ni boucle d’ambiance, ni musique**. L’application est donc silencieuse par conception, et le panneau de son l’annonce plutôt que de laisser croire à une panne. Un pack pourra atterrir sans modifier une ligne de code.

Les assets ne sont pas codés en dur : ils sont déclarés par un manifeste `GenEngine/Resources/audio-manifest.json` de schéma `1`.

```json
{
  "version": 1,
  "attribution": "Kenney (CC0)",
  "license": "CC0-1.0",
  "ambiences": { "world": { "resource": "amb-world", "fileExtension": "m4a", "gain": 0.9, "loops": true } },
  "cues": { "choice": { "resource": "sfx-choice", "fileExtension": "m4a" } }
}
```

Clés d’ambiance : `welcome`, `home`, `library`, `world`, `studio`, `administration`, `account`, `session`. Clés de signature : `choice`, `error`, `reward`, `gameOver` — cette dernière étant jouée sur la couche musique et non bouclée. Malgré son nom, `gameOver` est déclenchée sur **toute** fin de partie, y compris un accord : c’est un nom de signal, pas un état d’échec (voir « Ce que joue la démonstration »).

Comportement par défaut et modes dégradés :

- **aucun manifeste livré** : cas nominal actuel, l’application reste silencieuse et le panneau de son l’annonce explicitement ;
- **fichier annoncé introuvable** : la piste est ignorée, jamais l’action ;
- **version de schéma inconnue** : refus explicite et diagnostic, jamais d’interprétation approximative ;
- **son coupé** : toutes les couches sont ramenées à zéro et l’ambiance est arrêtée.

La session audio utilise la catégorie `ambient` avec `mixWithOthers` : l’application ne coupe jamais la musique déjà écoutée par le joueur et respecte le commutateur silencieux. Aucun son n’est le seul porteur d’une information : chaque signature double un retour visuel déjà rendu à l’écran. Les réglages sont des préférences locales non sensibles dans `UserDefaults` ; le backend ne publie aucun contrat audio à ce jour et n’est donc pas sollicité.

## Architecture

```text
GenEngine/
├── App/                 # Entrée, coque HUD plein écran et état produit
├── Core/
│   ├── Audio/           # Ambiances, signatures et réglages sonores
│   ├── Configuration/   # Environnements et endpoints
│   ├── DesignSystem/    # Tokens et composants partagés
│   ├── Models/          # Modèles API et présentation
│   ├── Networking/      # Client HTTP typé
│   └── Security/        # Credentials protégés par Keychain
└── Features/
    ├── Authentication/
    ├── Administration/ # Control plane, providers, RBAC et diagnostics Debug
    ├── Settings/        # Adressage des six services, accessible avant connexion
    ├── Home/
    ├── Library/
    ├── Experience/     # Bootstrap, carte, journal, familier, magasin et aide
    ├── Studio/         # Génération de scénarios contextualisée
    └── Player/
```

Les vues dépendent de `AppState` et les I/O distantes passent par `GenEngineAPI`. Les fixtures vivent dans `DemoStory` et ne remplacent jamais silencieusement une réponse distante en erreur.

Le client appelle les six services directement ; un point d’entrée public unique reste recommandé avant distribution.

`DeveloperView`, ainsi que `keyStatus`, `header`, `sectionPicker` et `map` dans `PlayerExperienceView`, ont été supprimés. `AppState.importAndPublish` (Debug) reste compilée mais n’est plus atteignable depuis aucune interface : son appelant et sa fixture `forest-choice.json` ont disparu avec eux.

Les frontières et compromis sont détaillés dans [`specs/architecture.md`](specs/architecture.md).

## Qualité

```bash
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Ces trois commandes sont exactement celles qu’exécute le travail Xcode de la CI ([`.github/workflows/ios.yml`](.github/workflows/ios.yml)).

Swift Testing couvre la navigation déterministe de la démonstration, la fermeture de l’accès démo une fois authentifié, la projection du graphe de quête en partie (précédence des états, rangs, ordre stable, scènes inatteignables, entrées dégénérées), sa projection hors partie (mémoire seule, aucun état de monde, mise en page identique à la projection en partie), le pilotage audio et la compatibilité des enums API. GitHub Actions régénère le projet avant chaque build.

La CI applique par ailleurs des contrôles de gouvernance, tous sur runner Linux — les runners macOS restent réservés à ce qui exige Xcode :

| Contrôle | Workflow | Portée |
| --- | --- | --- |
| Qualité de la documentation | `docs.yml` | markdownlint et vérification des liens (badges décoratifs exclus) |
| Politique de pull request | `pr-policy.yml` | titre conforme à la convention de commit |
| Sécurité des workflows | `workflow-security.yml` | actionlint et zizmor (persona `pedantic`) |
| Revue de dépendances | `dependency-review.yml` | vulnérabilités et licences des dépendances ajoutées |
| OpenSSF Scorecard | `scorecard.yml` | posture de sécurité du dépôt, hebdomadaire |

La CI ne fait toujours **ni lint Swift, ni analyse statique du code applicatif, ni test de rendu**. Un build vert et des tests verts ne disent rien de l’apparence à l’écran.

## Roadmap

La plateforme configurable inclut le flux immersif complet et une administration native distincte du Studio. Sur iPhone et iPad, l’univers joueur occupe tout l’écran : la carte sert de scène, les portes y sont matérialisées et la navigation native disparaît au profit d’une HUD et de panneaux superposés. L’espace Structures gère désormais périodes, unités école/entreprise/formation, participants, encadrants, import CSV prévalidé et affectations de scénarios/catégories/parcours. La carte connectée filtre les catégories d’un membre selon ses affectations effectives. La fin de quête affiche le graphe complet du scénario — pas seulement le chemin emprunté — avec la mémoire de toutes les parties précédentes. Le Journal de l’espace joueur affiche désormais la même carte hors partie : Play publie la topologie d’une version publiée sans session, colorée par la seule mémoire cumulée.

**Aucune tranche suivante n’est cadrée.** Avant toute nouvelle fonctionnalité, la priorité est d’observer réellement l’application sur simulateur iPhone et iPad, puis de calibrer `HUDMetrics`, d’arbitrer les deux HUD superposés dans `PlayerExperienceView` et de retirer le code mort. Voir [`specs/roadmap.md`](specs/roadmap.md) et [`specs/handoff.md`](specs/handoff.md).

## Documentation

- [Instructions agents](AGENTS.md) — source de vérité unique pour les agents ; `CLAUDE.md` n’en est qu’un pointeur
- [Index des spécifications](specs/README.md)
- [Passage de relais](specs/handoff.md)
- [Invariants](specs/invariants.md)
- [Architecture](specs/architecture.md)
- [Roadmap](specs/roadmap.md)
- [Guide de contribution](CONTRIBUTING.md)
- [Politique de sécurité](SECURITY.md)

## Sécurité

Ne publiez aucune vulnérabilité exploitable dans une issue. Consultez [`SECURITY.md`](SECURITY.md) pour le canal de signalement privé et le périmètre pris en charge.

## Contribuer

Les contributions suivent des branches courtes, des commits conventionnels, une PR focalisée et les contrôles CI requis. Consultez [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Dépôts associés

- [GenEngine backend](https://github.com/JordanLacroix/GenEngine)
- [GenEngine Web](https://github.com/JordanLacroix/GenEngine.Web)

## Licence

Aucune licence n’est actuellement définie. Le dépôt est public, mais cela n’accorde pas automatiquement un droit de réutilisation, modification ou redistribution.
