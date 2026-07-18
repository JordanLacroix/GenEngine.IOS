# Passage de relais

Dernière mise à jour : 18 juillet 2026.

## État vérifié

- `main` contient une application SwiftUI universelle générée avec XcodeGen.
- La démonstration hors ligne reste isolée et navigable sans backend.
- Le client consomme le catalogue Authoring, Identity et le parcours Play complet.
- Les onglets sont affichés selon les permissions et séparent jeu, Studio et Administration.
- Configuration, Azure AI Foundry, modes d’authentification, Entra ID, familier, monnaie, magasin et rôles sont raccordés aux contrats backend.
- Les jetons sont stockés dans Keychain et les références de session restent opaques.
- Les outils d’import et de publication Authoring sont limités aux builds Debug.
- La CI régénère, compile et teste l’application sur un simulateur iOS.

## Démarrage rapide de reprise

```bash
git status --short --branch
git pull --ff-only
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

## Prochaine unité de travail

La hiérarchie école/classes ou entreprise/équipes et l’affectation scoped des rôles sont disponibles. La prochaine tranche reliera membres et encadrants à ces unités et appliquera les scopes aux données. Les contrats backend doivent rester la source de vérité.

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux.
- Outils sensibles limités à Debug.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l’historique de conversation.
