# Passage de relais

Dernière mise à jour : 18 juillet 2026.

## État vérifié

- `main` contient une application SwiftUI universelle générée avec XcodeGen.
- La démonstration hors ligne reste isolée et navigable sans backend.
- Le client consomme le catalogue Authoring, Identity et le parcours Play complet.
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

La prochaine tranche fonctionnelle dépend des contrats publiés du jalon 4 du backend. Avant toute implémentation, confirmer le besoin produit, le contrat HTTP, les permissions et le comportement hors ligne. Ne pas créer de modèle local anticipé pour Configuration, Organization, Assistant ou Economy.

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux.
- Outils sensibles limités à Debug.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l’historique de conversation.
