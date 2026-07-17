# Invariants

1. Le backend est l’autorité sur les histoires, sessions, transitions et permissions.
2. Le client ne réimplémente aucune règle de `GenEngine.Narrative`.
3. Une référence locale de session reste opaque ; aucun état narratif serveur n’est dupliqué comme source de vérité.
4. Une erreur distante n’active jamais silencieusement une fixture de démonstration.
5. Les outils Authoring, logs bruts et réglages d’endpoints restent absents des builds Release.
6. Les jetons sont stockés dans Keychain et jamais dans `UserDefaults` ou les logs.
7. App Transport Security n’est jamais désactivé globalement.
8. Masquer une action dans l’interface ne remplace jamais l’autorisation côté serveur.
9. L’application reste utilisable avec Dynamic Type, VoiceOver et Reduce Motion.
10. `project.yml` reste l’unique source de vérité du projet Xcode généré.
11. Le mode démonstration reste navigable sans backend et clairement identifiable.
12. Les contrats inconnus ou incompatibles échouent explicitement au lieu d’être interprétés silencieusement.
