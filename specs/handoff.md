# Passage de relais

Dernière mise à jour : 19 juillet 2026.

## État vérifié

- `main` contient une application SwiftUI universelle générée avec XcodeGen.
- La démonstration hors ligne reste isolée, navigable sans backend, et joue le contenu « Le Diapason ».
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
- La présentation est plein écran : plus aucune chrome de navigation système, toute la navigation passe par un HUD superposé.
- La démonstration hors ligne n’existe plus que dans l’état anonyme.
- La couche sonore est abstraite derrière un protocole, configurable et désactivable, sans pack d’assets livré.
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
Généralisation du décor immersif : le modificateur `sceneBackdrop` du design system porte désormais ce cadrage pour la création du familier, le prologue et la remise de la clé, qui souffraient du même débordement. `immersiveWorld` conserve volontairement son `ZStack`, ses portes étant calibrées sur la géométrie produite par `scaledToFill`. Génération XcodeGen, build Swift 6 et 11 tests sur iPhone 17 Pro Simulator réussis sans signature le 19 juillet 2026.

Présentation immersive et HUD : `GameShellView` remplace le `TabView` et le `NavigationStack` racine. La destination courante est rendue bord à bord ; la navigation devient une barre basse en largeur compacte et un rail vertical gauche en largeur régulière, conformément à la grammaire de référence. Les menus sont des `HUDOverlayPanel` superposés et la partie est présentée en `fullScreenCover` avec sa carte en panneau. Le HUD flotte sans réserver de place ; le contenu défilant dégage sa zone par `safeAreaPadding`. Côté accessibilité, le HUD est un conteneur voisin du contenu — jamais masqué aux technologies d’assistance, sans piège de focus, `isModal` réservé aux panneaux réellement modaux, cibles d’au moins 44 points, états portés par symbole et texte en plus de la couleur. `AppState.destinations` et `AppState.activeTab` garantissent qu’un changement d’état ne laisse jamais le HUD sur une destination disparue.

Démonstration réservée à l’anonyme : une fois le joueur authentifié, `isDemoAvailable` passe à faux, `DemoStory.library` quitte le catalogue, la destination `Accueil` disparaît du HUD, `unlockDemo()`, `startDemo()` et `open(_:)` refusent la fixture, et la mémoire cumulée de démonstration disparaît du journal. S’authentifier pendant une démonstration referme immédiatement l’accès et la partie hors ligne. Pour un visiteur anonyme, la démonstration reste jouable intégralement sans réseau.

Son configurable : `GameAudioDirector` pilote trois couches indépendantes — ambiance liée au lieu, musique, signaux — derrière le protocole `GameAudioEngine`. `BundledGameAudioEngine` lit un manifeste `audio-manifest.json` de schéma `1` ; `SilentGameAudioEngine` sert les tests. Aucun nom de fichier n’est codé en dur : le pack d’assets peut atterrir sans changer une ligne de code. Aucun manifeste n’est livré à ce jour, donc l’application est silencieuse et le panneau de son l’annonce plutôt que de laisser croire à une panne. Une version de schéma inconnue est refusée explicitement. Le backend ne publiant aucun contrat audio, rien n’a été raccordé côté serveur et `ExperienceDocument` n’a pas été modifié. Le son est désactivable en permanence depuis la barre haute et n’est jamais le seul porteur d’une information.

Validation de la tranche immersive HUD : génération XcodeGen, build Swift 6 générique iOS Simulator et 43 tests sur iPhone 17 Pro Simulator réussis sans signature le 19 juillet 2026. Le rendu visuel n’a pas été vérifié en simulateur : il doit l’être sur iPad.

## Démonstration « Le Diapason »

La démonstration native jouait encore l'histoire que Diapason remplace : une
fixture de treize nœuds ouvrant sur `shore` et finissant sur `dawn`/`watch`,
avec le familier « Lueur » et le sceau du « Dernier Phare » au bilan.

`DemoStory` porte désormais les 23 mêmes scènes que le client web, tirées de la
bible d'univers (`specs/domain/diapason` dans le dépôt `GenEngine`). La
démonstration n'est plus une histoire mais un échantillon d'usages, parce que
c'est l'étendue qui se vend : un nœud d'accueil ouvre sur **La note de service**
(Lucidité), **La réunion où personne ne doute** (Courage, conflit professionnel)
et **La spécification avant le code** (Transmission, Spec Driven Development).

Trois évolutions de modèle, toutes cantonnées à la frontière de démonstration :

- `DemoNode.title` — le bilan affichait `node.id.capitalized` et la carte de
  quête projetait des paragraphes entiers ; les deux montrent maintenant un
  titre de scène ;
- `DemoNode.outcome` — `accord`, `partielle` ou `rupture`, cohérent avec le
  préfixe de l'identifiant, sur le modèle du contenu canonique ;
- `DemoChoice.posture` — la posture exercée, reprise dans l'explication d'arête
  du graphe.

Le moteur n'exposant aucun drapeau d'échec, une rupture est portée par le texte
et par l'interface : le bilan bascule ses actions et « Reprendre depuis le
début » devient l'action principale. Les six ruptures sont réparties sur les
trois situations.

Les tests n'ont pas été affaiblis mais réécrits sur le nouveau contenu : la
joignabilité couvre 23 nœuds au lieu de 13, `QuestGraphPresentationTests` projette
le nouveau chemin, et de nouveaux cas vérifient le hub, la convention de nommage
des fins, la présence d'une rupture par situation, l'emploi exclusif du
vocabulaire des six postures et l'absence de toute formulation de l'ancienne
histoire.

Corrigé au passage : le libellé de repli de la monnaie affichait « Braises » ;
il suit maintenant le défaut Diapason (« Accords », `♪`).

## Décisions à préserver

- Backend autoritatif et aucune règle Narrative dans le client.
- Démonstration isolée, jamais utilisée comme fallback silencieux.
- Outils sensibles limités à Debug.
- Secrets dans Keychain, endpoints non sensibles dans `UserDefaults`.
- Accessibilité et universalité iPhone/iPad.
- `project.yml` comme source de vérité.
- Présentation plein écran : aucune chrome de navigation système ne revient.
- Démonstration réservée à l’état anonyme.
- Son toujours désactivable et jamais seul porteur d’une information.

## Critère de passage de relais réussi

Un nouvel agent doit pouvoir lire `AGENTS.md`, générer le projet, compiler le client et identifier la prochaine tranche sans dépendre de l’historique de conversation.
