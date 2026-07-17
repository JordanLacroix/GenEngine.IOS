## Résumé

<!-- Que change cette PR ? -->

## Pourquoi

<!-- Besoin résolu et valeur apportée. -->

## Périmètre

### Inclus

-

### Hors périmètre

-

## Contexte de revue

- **Invariants à préserver :**
- **Fichiers critiques :**
- **Risques connus :**
- **Points à challenger :**

## Backend, sécurité et accessibilité

- **Contrats API concernés :** aucun / préciser
- **Configuration et défauts :** aucun / préciser
- **Permissions :** aucune / préciser la vérification serveur
- **Mode démonstration :** inchangé / préciser
- **Keychain, ATS et données sensibles :** inchangés / préciser
- **VoiceOver, Dynamic Type et Reduce Motion :** vérifiés / non applicable

## Validation

```text
xcodegen generate
xcodebuild build ...
xcodebuild test ...
```

## Checklist

- [ ] La PR est focalisée et son besoin est explicite.
- [ ] Le projet généré compile et les tests pertinents passent.
- [ ] Les invariants et la séparation démo/production sont préservés.
- [ ] L’accessibilité a été vérifiée pour toute modification visuelle.
- [ ] Les changements d’API ou de configuration sont documentés.
- [ ] README, specs et handoff reflètent l’état réel.
- [ ] Aucun secret, identifiant de signature ou artefact généré n’est présent.
- [ ] Tous les contrôles GitHub requis sont verts.
