# Pack audio — provenance et licences

L'intégralité de ce pack est sous **CC0 1.0 Universal** (domaine public). Aucune
attribution n'est juridiquement exigée ; elle est fournie par courtoisie et pour
garantir la traçabilité d'un produit distribué commercialement.

| Fichier | Clé du manifeste | Source | Auteur | Licence |
|---|---|---|---|---|
| `choice.caf` | `cues.choice` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) (`click_001`) | Kenney — kenney.nl | CC0 1.0 |
| `error.caf` | `cues.error` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) (`error_001`) | Kenney — kenney.nl | CC0 1.0 |
| `reward.caf` | `cues.reward` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) (`confirmation_001`) | Kenney — kenney.nl | CC0 1.0 |
| `world.m4a` | `ambiences.world` | [Calm Ambient 1 (Synthwave 4k)](https://opengameart.org/content/calm-ambient-1-synthwave-4k) | cynicmusic — The Cynic Project | CC0 1.0 |
| `session.m4a` | `ambiences.session` | [Scifi City — Ambient Loop](https://opengameart.org/content/scifi-city-ambient-loop) | TinyWorlds | CC0 1.0 |

## Transformations appliquées

Les sources Kenney sont distribuées en Ogg Vorbis, que `AVAudioPlayer` ne lit pas.
Les signatures proviennent donc du portage WAV de
[Calinou/kenney-interface-sounds](https://github.com/Calinou/kenney-interface-sounds)
(CC0 également), puis converties en CAF PCM mono :

```bash
afconvert -f caff -d LEI16 -c 1 click_001.wav choice.caf
```

Les ambiances, livrées en MP3 stéréo, sont réencodées en AAC mono 64 kbit/s pour
réduire le poids embarqué de 6,3 Mo à 1,2 Mo :

```bash
afconvert -f m4af -d aac -b 64000 --mix 001_Synthwave_4k.mp3 world.m4a
```

## Clés délibérément absentes

Le manifeste ne couvre pas les huit ambiances ni les quatre signatures possibles :

- `gameOver` n'est pas fourni parce que le moteur n'expose pas de fin de partie de
  première classe ; l'échec y est narratif. Livrer la musique avant le mécanisme
  serait prématuré.
- Les ambiances `welcome`, `home`, `library`, `studio`, `administration` et `account`
  sont volontairement omises : chaque piste bouclée pèse dans le binaire, et une
  ambiance dédiée à un écran d'administration apporte peu.

Toute clé absente reste silencieuse sans dégrader une fonctionnalité, par construction
(`BundledGameAudioEngine`). Ajouter une piste consiste à déposer le fichier ici et à
déclarer sa clé dans `audio-manifest.json`.
