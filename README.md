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

## Architecture

```text
GenEngine/
├── App/                 # Entrée, navigation et état produit
├── Core/
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

Swift Testing couvre la navigation déterministe de la démonstration et la compatibilité des enums API. GitHub Actions régénère le projet avant chaque build.

## Roadmap

La plateforme configurable inclut le flux immersif complet et une administration native distincte du Studio. L’espace Structures gère désormais unités école/entreprise/formation, participants, encadrants et affectations de scénarios/catégories/parcours. Voir [`specs/roadmap.md`](specs/roadmap.md).

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
