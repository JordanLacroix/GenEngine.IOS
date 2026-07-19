<div align="center">

# GenEngine iOS

**Client SwiftUI natif pour jouer, découvrir et tester les récits interactifs GenEngine sur iPhone et iPad.**

[![iOS](https://github.com/JordanLacroix/GenEngine.IOS/actions/workflows/ios.yml/badge.svg)](https://github.com/JordanLacroix/GenEngine.IOS/actions/workflows/ios.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![Status](https://img.shields.io/badge/statut-client%20connecté-2EA44F)](#état-du-projet)
[![License](https://img.shields.io/badge/licence-non%20définie-lightgrey)](#licence)

[Vision](#vision) · [Démarrage rapide](#démarrage-rapide) · [Architecture](#architecture) · [Roadmap](#roadmap) · [Documentation](#documentation) · [Contribuer](#contribuer)

</div>

---

## Vision

GenEngine iOS fournit une expérience narrative native, accessible et adaptée à l’iPhone comme à l’iPad. Le serveur reste l’autorité sur les scénarios, les sessions et les transitions ; le client présente les états reçus et transmet les intentions de l’utilisateur.

Le dépôt conserve deux parcours explicitement séparés :

- un mode connecté couvrant Identity, le catalogue Authoring et le parcours Play complet ;
- une démonstration hors ligne stable, destinée à la revue produit et aux tests d’interface.

## État du projet

| Capacité | État |
|---|---|
| Accueil et bibliothèque éditoriale | ✅ Disponible |
| Démonstration hors ligne | ✅ Disponible |
| Authentification et stockage Keychain | ✅ Connecté |
| Catalogue public Authoring | ✅ Connecté |
| Choix, quiz et texte libre confirmé | ✅ Connecté à Play |
| Pause, reprise et arbre explicable | ✅ Connecté à Play |
| Outils Authoring | ✅ Disponibles en Debug uniquement |
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
| Présentation plein écran pilotée par un HUD | ✅ Barre basse iPhone, rail iPad, aucune chrome système |
| Démonstration réservée à l’état anonyme | ✅ Retirée de tous les points d’entrée connectés |
| Audio configurable et désactivable | ⚠️ Abstraction et réglages prêts, aucun pack d’assets livré |

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

Dans une compilation Debug, ouvrez **Developer** pour modifier les endpoints. Le simulateur utilise `localhost` ; un appareil physique exige des endpoints HTTPS joignables. App Transport Security n’est pas désactivé globalement.

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

### Packs visuels de familier

L’espace Compagnon importe un manifeste JSON de schéma `1` depuis l’app Fichiers. Il accepte un asset inclus dans l’application ou un portrait HTTPS, avec licence et attribution obligatoires. Le manifeste reste une préférence locale non sensible dans `UserDefaults` : il ne crée ni propriété, ni achat, ni progression. PlayerExperience demeure l’autorité sur la sélection du familier.

Le configurateur s’adapte en deux colonnes sur iPad et en pile sur les largeurs compactes. Les valeurs contractuelles restent inchangées à l’enregistrement tandis que leurs libellés sont présentés en français.

Un exemple est fourni dans [`GenEngine/Resources/aster-familiar-pack.json`](GenEngine/Resources/aster-familiar-pack.json).

### Présentation plein écran et HUD

L’application n’utilise plus ni `TabView`, ni `NavigationStack`, ni barre de navigation système. `GameShellView` affiche la destination courante bord à bord et superpose un HUD :

- barre haute permanente (nom du jeu, état de chargement, son) ;
- navigation en barre basse sur largeur compacte (iPhone), en rail vertical à gauche sur largeur régulière (iPad) ;
- menus rendus en panneaux superposés (`HUDOverlayPanel`) plutôt qu’en écrans empilés ;
- partie présentée en `fullScreenCover`, avec son propre HUD et sa carte en panneau.

Le HUD flotte : il ne réserve pas de place, mais le contenu défilant dégage sa zone via `safeAreaPadding`, de sorte qu’aucune commande ne reste sous la surcouche. Le HUD est un conteneur d’accessibilité voisin du contenu : il n’est jamais `accessibilityHidden`, ne piège pas le focus VoiceOver, et seuls les panneaux réellement modaux portent le trait `isModal`. Chaque cible tactile fait au moins 44 points et chaque état est porté par un symbole et un texte, jamais par la couleur seule.

`AppState.destinations` calcule les destinations exposées selon l’authentification puis les permissions, et `AppState.activeTab` ramène la sélection dans cette liste : un changement d’état ne laisse jamais le HUD sur une destination disparue. Masquer une destination reste une commodité d’interface et ne remplace pas l’autorisation côté serveur.

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
`fin-rupture-*` — et chacune des trois situations mène à au moins une rupture.

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
- la mémoire cumulée de démonstration n’apparaît plus dans le journal ;
- une authentification en cours de démonstration referme immédiatement l’accès et la partie hors ligne.

Pour un visiteur anonyme, la démonstration reste intégralement jouable sans réseau : elle ne déclenche aucun appel HTTP.

### Son

Le son passe par `GameAudioDirector`, qui ne connaît que le protocole `GameAudioEngine`. Trois couches indépendantes existent — ambiance liée au lieu de l’application, musique et signaux — chacune avec son volume, et le tout est désactivable à tout instant depuis la barre haute du HUD.

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

Clés d’ambiance : `welcome`, `home`, `library`, `world`, `studio`, `administration`, `account`, `session`. Clés de signature : `choice`, `error`, `reward`, `gameOver` — cette dernière étant jouée sur la couche musique et non bouclée.

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
    ├── Administration/ # Control plane, providers et RBAC
    ├── Developer/       # Debug uniquement
    ├── Home/
    ├── Library/
    ├── Experience/     # Bootstrap, carte, journal, familier, magasin et aide
    ├── Studio/         # Génération de scénarios contextualisée
    └── Player/
```

Les vues dépendent de `AppState` et les I/O distantes passent par `GenEngineAPI`. Les fixtures vivent dans `DemoStory` et ne remplacent jamais silencieusement une réponse distante en erreur.

Les frontières et compromis sont détaillés dans [`specs/architecture.md`](specs/architecture.md).

## Qualité

```bash
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Swift Testing couvre la navigation déterministe de la démonstration, la projection du graphe de quête en partie (précédence des états, rangs, ordre stable, scènes inatteignables, entrées dégénérées), sa projection hors partie (mémoire seule, aucun état de monde, mise en page identique à la projection en partie) et la compatibilité des enums API. GitHub Actions régénère le projet avant chaque build.

## Roadmap

La plateforme configurable inclut le flux immersif complet et une administration native distincte du Studio. Sur iPhone et iPad, l’univers joueur occupe tout l’écran : la carte sert de scène, les portes y sont matérialisées et la navigation native disparaît au profit d’une HUD et de panneaux superposés. L’espace Structures gère désormais périodes, unités école/entreprise/formation, participants, encadrants, import CSV prévalidé et affectations de scénarios/catégories/parcours. La carte connectée filtre les catégories d’un membre selon ses affectations effectives. La fin de quête affiche le graphe complet du scénario — pas seulement le chemin emprunté — avec la mémoire de toutes les parties précédentes. Le Journal de l’espace joueur affiche désormais la même carte hors partie : Play publie la topologie d’une version publiée sans session, colorée par la seule mémoire cumulée. Voir [`specs/roadmap.md`](specs/roadmap.md).

## Documentation

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
