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
- L'introduction publique respecte sa version de configuration et peut être passée.
- L'espace joueur consomme le bootstrap serveur et expose tutoriel, carte, recherche, journal, progression, familier illustré, magasin et aide.
- L’introduction est rejouable depuis la connexion, qui propose la démo sous le formulaire sans afficher de profil avant authentification.
- Le prologue est illustré, matérialise les interactions configurées, remet une clé et ouvre une carte à portes.
- Les packs visuels de familier sont importables depuis Fichiers avec licence et attribution, sans notion de propriété.
- La démo s’arrête sur un bilan du chemin et des gains au lieu de boucler.

## Démarrage rapide de reprise

```bash
git status --short --branch
git pull --ff-only
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

## Prochaine unité de travail

La hiérarchie école/classes ou entreprise/équipes, les rôles scoped et le service Organization sont raccordés. L’Administration native gère unités, participants, encadrants et affectations avec suppression ; Play reste l’autorité qui refuse un scénario non affecté. Les contrats backend doivent rester la source de vérité.

Sur `feat/product-operations-ui`, l'onglet Developer a été supprimé et ses diagnostics intégrés à Administration. Cette dernière gère aussi utilisateurs, rôles custom, parcours, catégories, rattachements et assets licenciés du familier. Le Studio recherche et ouvre les brouillons, affiche leur arborescence, édite le texte/statut de fin d'une scène avec contrôle de révision et archive un scénario. La bibliothèque affiche la progression des catégories et la démo native vise environ quinze minutes.

Validation de la tranche immersive : génération XcodeGen, build Swift 6 et tests sur iPhone 17 Pro Simulator réussis sans signature le 18 juillet 2026.

Validation de la tranche Organization : génération XcodeGen et build Swift 6 générique iOS Simulator réussis sans signature le 18 juillet 2026.

Validation du seuil narratif : génération XcodeGen, build Swift 6 et 9 tests sur iPhone 17 Pro Simulator réussis sans signature le 18 juillet 2026.

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux.
- Outils sensibles limités à Debug.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l’historique de conversation.
