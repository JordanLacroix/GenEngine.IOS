# Spécifications GenEngine iOS

Ce dossier décrit les intentions, invariants et décisions propres au client iOS de GenEngine — moteur narratif paramétrable vendu aux écoles d'ingénieurs, aux entreprises et aux organismes de formation.

## Autorité

- Le code Swift et les tests font autorité sur le comportement exécutable.
- `project.yml` fait autorité sur la génération du projet Xcode.
- Les contrats HTTP du backend GenEngine font autorité sur les échanges réseau.
- Les specs backend font autorité sur les règles narratives, la configuration et l'autorisation, dont la bible d'univers Diapason (`specs/domain/diapason` du dépôt [`GenEngine`](https://github.com/JordanLacroix/GenEngine)).
- [`AGENTS.md`](../AGENTS.md) fait autorité sur les instructions agent ; `CLAUDE.md` n'en est qu'un pointeur.

## Index

- [Passage de relais](handoff.md) — ce qui est livré, ce qui est cassé, ce qui est délibérément absent. **À lire en premier.**
- [Invariants](invariants.md) — les règles non négociables.
- [Architecture](architecture.md) — frontières du client et contrats consommés.
- [Roadmap](roadmap.md) — jalons livrés et suite non cadrée.
