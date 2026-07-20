# Pack audio — provenance et licences

L'intégralité de ce pack est sous **CC0 1.0 Universal** (domaine public). Aucune
attribution n'est juridiquement exigée ; elle est fournie par courtoisie et pour
garantir la traçabilité d'un produit distribué commercialement.

Les douze clés du contrat audio sont couvertes : huit ambiances et quatre signatures.

## Signatures

| Fichier | Clé | Source | Auteur |
|---|---|---|---|
| `choice.caf` | `cues.choice` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) (`click_001`) | Kenney |
| `error.caf` | `cues.error` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) (`error_001`) | Kenney |
| `reward.caf` | `cues.reward` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) (`confirmation_001`) | Kenney |
| `gameover.m4a` | `cues.gameOver` | [Regret — Short Emotional Piano](https://opengameart.org/content/regret-short-emotional-piano) | Wolfgang_ |

## Ambiances

| Fichier | Clé | Source | Auteur |
|---|---|---|---|
| `welcome.m4a` | `ambiences.welcome` | [Calm Ambient 2 (Synthwave 15k)](https://opengameart.org/content/calm-ambient-2-synthwave-15k) | cynicmusic |
| `home.m4a` | `ambiences.home` | [Calm Ambient 3 (Lifewave 2k)](https://opengameart.org/content/calm-ambient-3-lifewave-2k) | cynicmusic |
| `library.m4a` | `ambiences.library` | [Calm Piano 1 (Vaporware)](https://opengameart.org/content/calm-piano-1-vaporware) | cynicmusic |
| `world.m4a` | `ambiences.world` | [Calm Ambient 1 (Synthwave 4k)](https://opengameart.org/content/calm-ambient-1-synthwave-4k) | cynicmusic |
| `studio.m4a` | `ambiences.studio` | [Hypnotic Chill](https://opengameart.org/content/hypnotic-chill-extended-4-minute-mix) | cynicmusic |
| `administration.m4a` | `ambiences.administration` | [Calm Relax 1 (Synthwave 421k)](https://opengameart.org/content/calm-relax-1-synthwave-421k) | cynicmusic |
| `account.m4a` | `ambiences.account` | [A New Start — Short Solo Piano](https://opengameart.org/content/a-new-start-short-solo-piano) | Wolfgang_ |
| `session.m4a` | `ambiences.session` | [Scifi City — Ambient Loop](https://opengameart.org/content/scifi-city-ambient-loop) | TinyWorlds |

Attribution demandée par cynicmusic, reproduite ici bien que non obligatoire en CC0 :
« The Cynic Project / cynicmusic.com / pixelsphere.org ».

## Transformations appliquées

Les sources Kenney sont distribuées en Ogg Vorbis, que `AVAudioPlayer` ne lit pas.
Les signatures proviennent donc du portage WAV de
[Calinou/kenney-interface-sounds](https://github.com/Calinou/kenney-interface-sounds)
(CC0 également), converties en CAF PCM mono :

```bash
afconvert -f caff -d LEI16 -c 1 click_001.wav choice.caf
```

Les ambiances sont livrées en MP3 stéréo de deux à huit minutes, soit près de
60 Mo bruts. Elles sont **tronquées à 90 secondes** et réencodées en AAC mono
48 kbit/s, ce qui ramène le pack complet à environ 4 Mo :

```bash
ffmpeg -i 002_Synthwave_15k.mp3 -t 90 -ac 1 -c:a aac -b:a 48k \
  -af "afade=t=in:st=0:d=2,afade=t=out:st=87:d=3" welcome.m4a
```

Deux pistes échappent à la troncature parce qu'elles sont déjà courtes :
`account.m4a` (22 s) et `session.m4a`, cette dernière étant une véritable boucle
fournie comme telle par son auteur. `gameover.m4a` est conservé entier (49 s) en
64 kbit/s : il est joué une fois, sur la couche musique, et n'est jamais bouclé.

## Limite connue du bouclage

Sauf `session.m4a`, aucune de ces pistes n'a été composée pour boucler. La
troncature à 90 secondes tombe donc au milieu d'une phrase musicale. Le fondu de
sortie de trois secondes évite la coupure sèche, mais le rebouclage reste
audible comme une respiration plutôt que comme une continuité. C'est un compromis
assumé face à des sources gratuites ; y remédier suppose de choisir des points de
boucle réels, ce qui demande une écoute musicale.

**Aucune de ces pistes n'a été écoutée en contexte.** Les niveaux (`gain`) sont
posés à l'estime, plus bas sur `studio` et `administration` dont les sources sont
les plus rythmées. Ils méritent un passage à l'oreille.
