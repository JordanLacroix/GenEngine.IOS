# Instructions agents — GenEngine iOS

GenEngine est un moteur narratif entièrement paramétrable, vendu avec son interface de configuration aux écoles d'ingénieurs, aux entreprises et aux organismes de formation professionnelle. Ce dépôt porte le **client iOS** : il joue les projections calculées par le backend, il n'embarque pas le moteur.

« Le Diapason » est la configuration de référence, jouée à la première initialisation et industrialisable par instance client : 2026, notre monde, l'IA partout, le joueur apprenti en école d'ingénieurs. Six postures — **Lucidité, Discernement, Arbitrage, Courage, Transmission, Autonomie** — remplacent les catégories par matière, pour dix scénarios.

Ce fichier est la source de vérité unique des instructions agent de ce dépôt. [`CLAUDE.md`](CLAUDE.md) n'est qu'un pointeur vers lui et ne doit jamais dupliquer une instruction : deux fichiers substantiels finissent toujours par diverger.

## Ordre de lecture

Lis ce fichier avant toute modification, puis consulte dans cet ordre :

1. [`specs/handoff.md`](specs/handoff.md) pour l'état réellement vérifié et la prochaine tâche ;
2. [`specs/invariants.md`](specs/invariants.md) pour les règles non négociables ;
3. [`specs/architecture.md`](specs/architecture.md) pour les frontières du client ;
4. [`specs/roadmap.md`](specs/roadmap.md) pour les priorités ;
5. [`README.md`](README.md) et [`project.yml`](project.yml) pour l'usage et la configuration du projet.

Les contrats du backend et les invariants narratifs de référence vivent dans le dépôt [`GenEngine`](https://github.com/JordanLacroix/GenEngine), dont la bible d'univers Diapason (`specs/domain/diapason`). Le client ne les redéfinit pas.

## Langue et communication

- Écris les échanges utilisateur et la documentation en français.
- Garde les noms de code, messages d'erreur techniques et commits en anglais.
- Annonce toute hypothèse qui modifie le périmètre.
- Ne déclare jamais une tâche terminée avant implémentation et vérification réelles.
- N'écris jamais une intention comme un fait livré. Si une capacité est souhaitée mais absente, dis-le explicitement.

## Règles non négociables

- Le backend reste autoritatif sur les histoires, sessions, transitions, permissions et états narratifs.
- N'implémente aucune règle de `GenEngine.Narrative` dans l'application.
- Conserve les fixtures dans la frontière de démonstration ; une erreur de production ne doit jamais être remplacée silencieusement par une fixture.
- Garde les imports Authoring et les logs bruts derrière `#if DEBUG`. L’adressage des six services, lui, est un réglage utilisateur disponible en Release et avant connexion (`Features/Settings`) : ne le renvoie pas derrière `#if DEBUG`.
- Traite [`project.yml`](project.yml) comme source de vérité ; ne modifie jamais `project.pbxproj` à la main.
- Préserve une application universelle iPhone/iPad, Dynamic Type, VoiceOver, les contrastes, Reduce Motion et les cibles tactiles minimales.
- Préfère SwiftUI, Observation, la concurrence structurée, les types valeur et les dépendances derrière protocoles.
- La présentation reste plein écran et pilotée par le HUD ; ne réintroduis ni `TabView`, ni `NavigationStack` racine, ni barre de navigation système.

## Configuration et autorisation obligatoires

Ces obligations sont l'adaptation au client des règles du dépôt backend. Le client en est le consommateur, jamais l'autorité.

- **Une permission masquée dans l'interface n'est pas un contrôle d'accès.** Retirer une destination du HUD est une commodité de présentation ; le serveur doit toujours appliquer la règle, et le client doit rester correct lorsque le serveur refuse.
- Le code client teste des permissions et des scopes, jamais un nom de rôle : les rôles sont personnalisables côté produit.
- Toute nouvelle fonctionnalité documente dans la même PR ses paramètres, leur défaut, leur portée, leur validation et leur comportement lorsqu'elle est désactivée.
- Un refus serveur (401, 403, 422 `content_not_assigned`) produit un message explicite et une action de reprise, jamais un repli silencieux sur la démonstration.
- Les libellés visibles restent configurables par le serveur via le dictionnaire de copies ; ne code en dur qu'un défaut de repli, et documente-le.
- L'isolation par organisation et par front est appliquée côté service propriétaire ; le client ne la simule pas.
- Le fonctionnement hors ligne reste possible : la démonstration anonyme ne déclenche aucun appel réseau.

## Sécurité et configuration

- Ne committe jamais credential, token, IP privée, équipe de signature ou donnée utilisateur générée.
- Stocke les jetons dans Keychain et uniquement les préférences non sensibles dans `UserDefaults`.
- Ne désactive jamais App Transport Security globalement.
- `GenEngine/Core/Configuration/ServiceEndpoints.swift` porte régulièrement une modification locale non committée (adresse privée pour un test sur appareil). Ne la committe pas et ne la révoque pas.

## Méthode de travail

1. Pars de `main` à jour et crée une branche courte.
2. Implémente une seule préoccupation cohérente.
3. Mets à jour code, tests, README, specs et état de handoff dans la même PR.
4. Utilise des commits conventionnels et le modèle de pull request.
5. Ne fusionne qu'après réussite des contrôles GitHub requis.

## Vérifications minimales

Ces trois commandes sont exactement celles qu'exécute le travail Xcode de la CI ([`.github/workflows/ios.yml`](.github/workflows/ios.yml)) :

```bash
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Après validation, vérifie que le projet généré et les données utilisateur Xcode ne sont pas suivis par Git.

La CI applique en plus des contrôles de gouvernance, tous sur runner Linux — les runners macOS sont facturés plusieurs fois le tarif Linux et restent réservés à ce qui exige Xcode. Si tu touches à la documentation ou aux workflows, reproduis-les localement :

```bash
# Documentation (.github/workflows/docs.yml)
npx markdownlint-cli2 "README.md" "AGENTS.md" "CLAUDE.md" "CONTRIBUTING.md" \
  "SECURITY.md" "specs/**/*.md" ".github/**/*.md"
lychee --config lychee.toml '**/*.md'

# Workflows (.github/workflows/workflow-security.yml)
actionlint .github/workflows/*.yml
zizmor --persona pedantic --min-severity low --min-confidence medium .github/workflows/
```

Les autres contrôles ne se rejouent pas utilement en local : le titre de pull request (convention de commit), la revue de dépendances et OpenSSF Scorecard s'exécutent côté GitHub.

Toute action tierce ajoutée à un workflow doit être épinglée par empreinte de commit complète, suivie d'un commentaire de version. Chaque travail déclare le `permissions:` minimal dont il a besoin.

La CI ne fait toujours ni lint Swift, ni analyse statique du code applicatif, ni test de rendu. Un build vert et des tests verts ne disent rien de l'apparence à l'écran.

## Pièges connus

- Le simulateur utilise `localhost`, mais un appareil physique exige des endpoints HTTPS joignables.
- Le projet Xcode est généré et volontairement ignoré.
- Le mode démonstration doit rester navigable sans backend, tout en étant visuellement explicite.
- L'application appelle les six services directement ; un point d'entrée public unique reste recommandé avant distribution.
- La coque HUD et la carte du joueur **ont été observées** en simulateur, connectées à la pile locale : iPhone 17 Pro, et iPad Pro 13 pouces en portrait et en paysage. L'écran de paramètres, la bibliothèque, le Studio et l'administration ne l'ont toujours pas été, ni aucun rendu sur appareil physique ou en Dynamic Type agrandi. Ne présente comme vérifié que ce qui a été regardé.
- Une vue qui impose sa taille intrinsèque en frère de `ZStack` — `Image` `scaledToFill`, halo décoratif à taille fixe — élargit toute la pile, qui recentre alors la coque entière hors de l'écran. Les géométries rapportées par SwiftUI restent justes pendant ce temps : mesure l'**ancêtre**, pas la vue qui paraît fautive. Les décors passent par `sceneBackdrop` ; `frame` + `clipped` ne suffit pas.
- Les valeurs de `HUDMetrics` (`GenEngine/Core/DesignSystem/HUD.swift`) restent des estimations, sauf `railWidth: 140`, calibré à l'écran sur iPad, et `minimumTarget: 44`.
- La seconde barre d'onglets de `PlayerExperienceView` a été retirée : les quatre panneaux (Journal, Compagnon, Magasin, Aide) sont devenus des actions du bandeau haut, la carte reste l'état de repos. Une seule barre d'onglets subsiste, celle de la coque.
- `DeveloperView` et les vues mortes `keyStatus`, `header`, `sectionPicker` et `map` de `PlayerExperienceView` ont été supprimées.
- Les réglages d'endpoints se modifient depuis **Paramètres du serveur** (`Features/Settings`), atteignable depuis le menu de l'accueil anonyme, depuis **Compte** et depuis **Administration → Environnement & diagnostic**.
- Aucun pack audio n'est livré : l'application est silencieuse par conception, ce n'est pas une panne.
- Le dépôt est public mais ne possède pas encore de licence ; n'affirme aucune permission de réutilisation.

## Prochaine tâche

Rien n'est cadré. Le client couvre catalogue, Identity, Play, Configuration, PlayerExperience, Organization, la coque HUD plein écran, le graphe de quête avec mémoire cumulée, la carte hors partie, la démonstration Diapason, les paramètres serveur avant connexion et les confirmations d'actions conséquentes. Les manques honnêtes sont listés dans [`specs/handoff.md`](specs/handoff.md).

La priorité raisonnable, avant toute nouvelle fonctionnalité, est de **regarder l'application tourner** : la coque HUD, l'écran de paramètres et la démonstration Diapason n'ont jamais été observés sur simulateur ni sur appareil. Calibrer `HUDMetrics` en découle directement.

N'anticipe aucune tranche dépendant d'un contrat backend non publié — à commencer par l'audio, pour lequel le serveur ne publie rien.
