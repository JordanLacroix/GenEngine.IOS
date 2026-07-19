# Passage de relais

Dernière mise à jour : 19 juillet 2026.

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
- La fin de quête affiche le graphe complet du scénario et la mémoire cumulée des parties précédentes, en démonstration comme en session connectée.
- La carte d’un scénario serveur se consulte aussi hors partie, depuis la topologie publiée par Play et colorée par la seule mémoire cumulée.
- La passe de stabilisation de l’univers joueur localise les valeurs moteur, déduplique journal et maîtrises, rend le configurateur du compagnon adaptatif et projette les portes sur les repères réels de l’illustration sur iPhone comme sur iPad.

## Démarrage rapide de reprise

```bash
git status --short --branch
git pull --ff-only
xcodegen generate
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

## Prochaine unité de travail

La hiérarchie école/classes ou entreprise/équipes, les rôles scoped et le service Organization sont raccordés. L’Administration native gère périodes métier, unités, participants, encadrants, import CSV depuis Fichiers et affectations avec suppression. Play résout les parcours et reste l’autorité qui refuse un scénario non affecté ; la carte native filtre les catégories d'un membre selon ses affectations.

Sur `feat/product-operations-ui`, l'onglet Developer a été supprimé et ses diagnostics intégrés à Administration. Cette dernière gère aussi utilisateurs, rôles custom, parcours, catégories, rattachements et assets licenciés du familier. Le Studio recherche et ouvre les brouillons, affiche leur arborescence, édite le texte/statut de fin d'une scène avec contrôle de révision et archive un scénario. La bibliothèque affiche la progression des catégories et la démo native vise environ quinze minutes.

Validation de la tranche immersive : génération XcodeGen, build Swift 6 et tests sur iPhone 17 Pro Simulator réussis sans signature le 18 juillet 2026.

Validation de la tranche Organization : génération XcodeGen et build Swift 6 générique iOS Simulator réussis sans signature le 18 juillet 2026.

Validation du seuil narratif : génération XcodeGen, build Swift 6 et 9 tests sur iPhone 17 Pro Simulator réussis sans signature le 18 juillet 2026.

Validation de la stabilisation joueur : projection de carte et localisation couvertes par Swift Testing, avec build universel iPhone/iPad le 18 juillet 2026.

Correction de l'introduction publique : le décor de scène est passé en arrière-plan clippé afin qu'une image `scaledToFill` ne dicte plus la hauteur du conteneur, et les commandes sont sorties du défilement pour rester atteignables. Génération XcodeGen, build Swift 6 et 11 tests sur iPhone 17 Pro Simulator réussis sans signature le 19 juillet 2026.

Graphe de fin de quête : `QuestGraphPresentation` projette `NarrativeTree` et les `ScenarioMasteryView` en graphe orienté (rangs BFS, ordre stable, convergences et cycles préservés) ; `QuestGraphView` le dessine avec un `Canvas` doublé d'une liste textuelle pour VoiceOver. `DemoStory.narrativeTree(path:)` projette la fixture hors ligne dans la même forme de contrat, de sorte qu'une seule vue serve les deux modes. `refreshTree()` remonte désormais un échec réel via `AppState.treeError` au lieu de l'avaler dans `developerLog`. Génération XcodeGen, build Swift 6 générique iOS Simulator et 23 tests sur iPhone 17 Pro Simulator réussis sans signature le 19 juillet 2026.

Carte hors partie : la limite précédente est levée. Play publie désormais `GET /scenario-versions/{id}/tree`, la topologie d'une version publiée sans session. Le client la consomme via `GenEngineAPI.scenarioStructure(scenarioVersionId:)` et la modélise par `ScenarioStructure`, type distinct de `NarrativeTree` : ce contrat ne porte volontairement ni état de scène ni évaluation de condition, tous deux dépendants d'un état de monde inexistant hors session. `QuestGraphPresentation` expose donc deux adaptateurs — `build(tree:…)` en partie, `build(structure:…)` hors partie — qui convergent vers une seule mise en page : mêmes rangs BFS, même ordre dans le rang, mêmes coordonnées, de sorte que les deux cartes se superposent. Hors partie, chaque scène est `discoveredBefore` si la mémoire cumulée la contient, sinon `unseen` ; aucune n'est `current`, `takenThisRun` ni `locked`, et `QuestGraphView(showsCurrentRun: false)` retire ces états de la légende et du résumé. Espace joueur → Journal affiche cette carte réelle à la place des simples compteurs. Un refus reste visible : 401, 403 et 422 `content_not_assigned` produisent un message explicite et un bouton « Réessayer », jamais un repli sur la fixture de démonstration. La démonstration reste inchangée et sans appel réseau. Génération XcodeGen, build Swift 6 générique iOS Simulator et 27 tests sur iPhone 17 Pro Simulator réussis sans signature le 19 juillet 2026.

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux.
- Outils sensibles limités à Debug.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l’historique de conversation.
