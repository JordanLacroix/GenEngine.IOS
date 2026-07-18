# Roadmap

## Jalon 0 — fondation native

Application SwiftUI universelle, design system, navigation, démonstration hors ligne et génération XcodeGen.

**Statut : terminé.**

## Jalon 1 — catalogue connecté

Chargement du catalogue public Authoring dans l’accueil et la bibliothèque, avec état d’indisponibilité explicite.

**Statut : terminé.**

## Jalon 2 — parcours narratif complet

Identity, outils Authoring Debug, session Play, interactions typées, pause/reprise et arbre explicable.

**Statut : terminé.**

## Jalon 3 — première expérience produit

Configuration publique, navigation pilotée par les permissions, familier personnalisable, portefeuille, magasin, Studio contextualisé et console d’administration séparée.

**Statut : terminé.**

## Jalon 3.1 — vocabulaire du jeu

Dictionnaire extensible de copies publié par le moteur, éditeur natif de libellés et consommation dans l’accueil, les onglets, la bibliothèque, le Studio et l’espace joueur.

**Statut : terminé.**

## Jalon 4 — structures et exploitation avancées

Les périodes métier, membres, encadrants, unités, import CSV prévalidé et affectations scénario/catégorie/parcours sont raccordés. Le catalogue natif d'un membre est filtré selon ces affectations. Restent l'export et les autres opérations en masse, le reporting collectif, l'édition économique avancée et le cycle éditorial collaboratif.

**Statut : en cours.** Les règles restent autoritatives dans les services backend.

## Jalon 3.3 — expérience joueur immersive

Introduction publique versionnée, bootstrap moteur, tutoriel persistant, carte et recherche, journal personnel, maîtrise cross-session, compagnon illustré/personnalisable, magasin et centre d'aide. L'écran Compte reste accessible pour la connexion et la déconnexion.

**Statut : implémenté sur `feat/immersive-player-experience`.** Build Swift 6 et tests simulateur iPhone 17 Pro validés.

## Jalon 3.4 — seuil narratif et monde illustré

Introduction rejouable depuis la connexion, démo sous l’authentification, création finalisable du familier, packs visuels sans propriété, tutoriel présenté comme un scénario, interactions natives, clé universelle, carte à portes et bilan de fin sans boucle automatique.

**Statut : implémenté sur `codex/immersive-onboarding-ux`.** Les projections et transitions restent fournies par les services GenEngine.

La passe corrective `codex/fix-player-experience-polish` remplace le retour textuel par une fermeture compacte, rend l’édition du compagnon adaptative, francise les valeurs techniques, déduplique les projections du journal et ancre les portes aux lieux dessinés avec le même calcul que `scaledToFill`.

## Jalon 3.2 — opérations produit et Studio visuel

Console utilisateurs recherchable avec activation/suppression, parcours et catégories, assets du familier, progression par catégorie, fusion des outils Developer dans Administration, bibliothèque de brouillons et édition visuelle de scène avec archivage. La démo native compte treize scènes pour une cible d'environ quinze minutes.

**Statut : terminé sur `feat/product-operations-ui`, en attente de revue.**
