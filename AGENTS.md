# Instructions agents — GenEngine iOS

Lis ce fichier avant toute modification, puis consulte dans cet ordre :

1. [`specs/handoff.md`](specs/handoff.md) pour l’état courant et la prochaine tâche ;
2. [`specs/invariants.md`](specs/invariants.md) pour les règles non négociables ;
3. [`specs/architecture.md`](specs/architecture.md) pour les frontières du client ;
4. [`specs/roadmap.md`](specs/roadmap.md) pour les priorités ;
5. [`README.md`](README.md) et [`project.yml`](project.yml) pour l’usage et la configuration du projet.

Les contrats du backend et les invariants narratifs de référence vivent dans le dépôt [`GenEngine`](https://github.com/JordanLacroix/GenEngine). Le client ne les redéfinit pas.

## Langue et communication

- Écris les échanges utilisateur et la documentation en français.
- Garde les noms de code, messages d’erreur techniques et commits en anglais.
- Annonce toute hypothèse qui modifie le périmètre.
- Ne déclare jamais une tâche terminée avant implémentation et vérification réelles.

## Règles non négociables

- Le backend reste autoritatif sur les histoires, sessions, transitions, permissions et états narratifs.
- N’implémente aucune règle de `GenEngine.Narrative` dans l’application.
- Conserve les fixtures dans la frontière de démonstration ; une erreur de production ne doit jamais être remplacée silencieusement par une fixture.
- Garde les imports Authoring, logs bruts et réglages d’endpoints derrière `#if DEBUG`.
- Traite [`project.yml`](project.yml) comme source de vérité ; ne modifie jamais `project.pbxproj` à la main.
- Préserve une application universelle iPhone/iPad, Dynamic Type, VoiceOver, les contrastes, Reduce Motion et les cibles tactiles minimales.
- Préfère SwiftUI, Observation, la concurrence structurée, les types valeur et les dépendances derrière protocoles.

## Sécurité et configuration

- Ne committe jamais credential, token, IP privée, équipe de signature ou donnée utilisateur générée.
- Stocke les jetons dans Keychain et uniquement les préférences non sensibles dans `UserDefaults`.
- Ne désactive jamais App Transport Security globalement.
- Une permission masquée dans l’interface n’est pas un contrôle d’accès ; le serveur doit toujours l’appliquer.
- Toute nouvelle configuration documente son défaut, sa portée, sa validation et son comportement désactivé.

## Méthode de travail

1. Pars de `main` à jour et crée une branche courte.
2. Implémente une seule préoccupation cohérente.
3. Mets à jour code, tests, README, specs et état de handoff dans la même PR.
4. Utilise des commits conventionnels et le modèle de pull request.
5. Ne fusionne qu’après réussite des contrôles GitHub requis.

## Vérifications minimales

```bash
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Après validation, vérifie que le projet généré et les données utilisateur Xcode ne sont pas suivis par Git.

## Pièges connus

- Le simulateur utilise `localhost`, mais un appareil physique exige des endpoints HTTPS joignables.
- Le projet Xcode est généré et volontairement ignoré.
- Le mode démonstration doit rester navigable sans backend, tout en étant visuellement explicite.
- L’application appelle actuellement les trois services directement ; un point d’entrée public unique reste recommandé avant distribution.

## Prochaine tâche

Le parcours client actuel couvre catalogue, authentification, Authoring et Play. La prochaine tranche fonctionnelle dépend des contrats du jalon 4 du backend. N’anticipe ni configuration, ni RBAC, ni organisation, ni assistant sans contrat publié et besoin produit validé.
