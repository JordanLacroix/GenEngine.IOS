# Politique de sécurité

## Versions prises en charge

GenEngine iOS est en phase préliminaire. Seule la branche `main` reçoit des correctifs de sécurité jusqu’à la première version stable.

| Version | Prise en charge |
|---|---|
| `main` | Oui |
| Anciennes révisions | Non |

## Signaler une vulnérabilité

N’ouvrez pas d’issue publique et ne publiez pas de preuve d’exploitation.

Utilisez le [signalement privé GitHub](https://github.com/JordanLacroix/GenEngine.IOS/security/advisories/new) avec le composant et la révision concernés, l’impact, les préconditions, des étapes minimales et une preuve nettoyée de toute donnée sensible.

Un accusé de réception est visé sous 7 jours. Après validation, la correction est préparée de façon privée et la divulgation coordonnée. Aucun programme de prime n’est proposé actuellement.

## Périmètre

Sont notamment concernés : exposition de jetons Keychain, contournement des frontières Debug/Release, transport non sécurisé, injection dans les échanges API, accès non autorisé à des données locales et vulnérabilités de dépendances.

Les problèmes de sécurité du backend doivent être signalés dans le [dépôt GenEngine](https://github.com/JordanLacroix/GenEngine/security/advisories/new).
