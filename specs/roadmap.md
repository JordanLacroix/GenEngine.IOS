# Roadmap

Les jalons ci-dessous sont classés par ordre chronologique de livraison. Toutes les tranches marquées **fusionné** sont sur `main` : aucune ne vit plus sur une branche de travail. Un jalon n'est « fusionné » que si le code correspondant est sur `main`, ce qui ne veut pas dire que son rendu a été observé à l'écran — voir [`handoff.md`](handoff.md).

## Jalon 0 — fondation native

Application SwiftUI universelle, design system, navigation, démonstration hors ligne et génération XcodeGen.

**Statut : fusionné.**

## Jalon 1 — catalogue connecté

Chargement du catalogue public Authoring dans l'accueil et la bibliothèque, avec état d'indisponibilité explicite.

**Statut : fusionné.**

## Jalon 2 — parcours narratif complet

Identity, outils Authoring Debug, session Play, interactions typées, pause/reprise et arbre explicable.

**Statut : fusionné.**

## Jalon 3 — première expérience produit

Configuration publique, navigation pilotée par les permissions, familier personnalisable, portefeuille, magasin, Studio contextualisé et console d'administration séparée.

**Statut : fusionné.**

## Jalon 3.1 — vocabulaire du jeu

Dictionnaire extensible de copies publié par le moteur, éditeur natif de libellés et consommation dans l'accueil, les destinations, la bibliothèque, le Studio et l'espace joueur.

**Statut : fusionné.**

## Jalon 3.2 — opérations produit et Studio visuel

Console utilisateurs recherchable avec activation/suppression, parcours et catégories, assets du familier, progression par catégorie, bibliothèque de brouillons et édition visuelle de scène avec archivage.

**Statut : fusionné** (#7, #10). L'onglet Developer a été supprimé du HUD ; `DeveloperView` subsiste comme code mort et ses diagnostics ont été réimplémentés dans `AdministrationView`.

## Jalon 3.3 — expérience joueur immersive

Introduction publique versionnée, bootstrap moteur, tutoriel persistant, carte et recherche, journal personnel, maîtrise cross-session, compagnon illustré/personnalisable, magasin et centre d'aide. L'écran Compte reste accessible pour la connexion et la déconnexion.

**Statut : fusionné** (#9).

## Jalon 3.4 — seuil narratif et monde illustré

Introduction rejouable depuis la connexion, démo sous l'authentification, création finalisable du familier, packs visuels sans propriété, tutoriel présenté comme un scénario, interactions natives, clé universelle, carte à portes et bilan de fin sans boucle automatique.

**Statut : fusionné** (#11, #12, #14, #16). Les projections et transitions restent fournies par les services GenEngine.

## Jalon 3.5 — graphe de quête et mémoire cumulée

Le bilan de fin de quête montre le scénario entier, pas seulement le chemin emprunté : position actuelle, scènes parcourues pendant la partie, scènes découvertes lors des parties précédentes, scènes verrouillées et scènes jamais atteintes. La projection est pure et déterministe ; le serveur reste l'autorité sur les états et les conditions.

**Statut : fusionné** (#15, #17). La carte d'un scénario se consulte aussi hors partie, depuis `GET /scenario-versions/{id}/tree`, colorée par la seule mémoire cumulée.

## Jalon 4 — structures et exploitation avancées

Périodes métier, membres, encadrants, unités, import CSV prévalidé et affectations scénario/catégorie/parcours sont raccordés. Le catalogue natif d'un membre est filtré selon ces affectations.

**Statut : partiellement fusionné** (#13). Restent l'export et les autres opérations en masse, le reporting collectif, l'édition économique avancée et le cycle éditorial collaboratif. Les règles restent autoritatives dans les services backend.

## Jalon 5 — présentation plein écran et HUD

`GameShellView` remplace le `TabView` et le `NavigationStack` racine : barre basse en largeur compacte, rail vertical gauche en largeur régulière, menus en panneaux superposés, partie en `fullScreenCover`. La démonstration hors ligne est fermée dès l'authentification, dans le modèle. La couche sonore est abstraite derrière `GameAudioEngine` et pilotée par manifeste.

**Statut : fusionné** (#18). **Jamais observé à l'écran** : build et tests uniquement. `HUDMetrics` n'est pas calibré et `PlayerExperienceView` conserve un second HUD sous celui de la coque.

## Jalon 6 — démonstration Diapason

La démonstration hors ligne échantillonne la configuration de référence : 23 scènes, un nœud d'accueil ouvrant sur trois situations (Lucidité, Courage, Transmission), douze fins dont six ruptures réparties deux par situation. La démonstration ne raconte plus une histoire, elle montre l'étendue des usages.

**Statut : fusionné** (#19). **Jamais observé à l'écran.**

## Suite

Aucune tranche n'est cadrée. Avant toute nouvelle fonctionnalité, la priorité est d'observer réellement l'application sur simulateur iPhone et iPad, puis de traiter les manques listés dans [`handoff.md`](handoff.md) : calibrage du HUD, arbitrage des deux HUD superposés, suppression du code mort.

L'audio ne peut pas avancer côté serveur : aucun contrat n'est publié. Un pack d'assets peut en revanche être livré sans changement de code, via le manifeste.
