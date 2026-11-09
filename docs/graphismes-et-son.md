# Graphismes et son

## Rendu et graphismes

- Résolution de base **480×270**, mise à l'échelle entière (×4 en 1080p). Sur un téléphone 20:9, on voit un peu plus de monde en largeur (600×270).
- Rendu *Compatibility* (meilleure couverture Android), filtre *Nearest* pour des pixels nets.
- **Le violet est réservé à l'infection** : aucune autre chose du jeu ne doit l'utiliser.
- **Sprites temporaires** générés par [td2d](https://github.com/brphillis/threedee-twodee) à partir de modèles 3D décrits en JSON : voir `art/README.md`. Les tuiles du sol viennent de `python tools/gen_placeholders.py`.
- **Police** : [Barlow](https://github.com/jpt/barlow) (SemiBold pour les textes, Bold pour les chiffres du HUD), une police lisse et lisible sur téléphone. Le jeu est rendu en mode `canvas_items` : le pixel art est agrandi par paliers entiers (net), le texte est dessiné à la vraie résolution de l'écran.
- **Icônes** : pixel art 12 px, générées par `tools/gen_icons.py`.
- **Interface** : plaques de fer, boutons, onglets et télégramme en pixel art, dessinés par `python tools/gen_ui.py`, puis assemblés en thème Godot par `godot --headless --path . --script tools/build_theme.gd` (écrit `ui/theme/game_theme.tres`).

## Son et musique

Des sons **libres**, trouvés sur [OpenGameArt](https://opengameart.org) : presque tout en **CC0** (domaine public), un pack de coups de feu en **CC-BY 3.0** (crédit obligatoire). La liste complète, avec auteurs, licences et liens, est dans [`assets/audio/CREDITS.md`](../assets/audio/CREDITS.md) et dans l'écran **Crédits** du jeu (écran titre et menu pause).

- **Musiques** (`assets/audio/music/<moment>/*.ogg`, 39 morceaux) : synthwave pour l'écran titre, le train et la horde ; lofi (et un peu de synthwave) pour l'exploration.
- **Bruitages** (`assets/audio/sfx/*.wav`, 37 sons, 58 fichiers) : extraits de packs CC0 (Kenney, rubberduck, bart, qubodup, artisticdude…), parfois mixés entre eux. Un son peut avoir plusieurs **variantes** (`hit_1.wav` … `hit_4.wav`) : le jeu en prend une au hasard, jamais deux fois la même de suite.
- **Ambiances en boucle** (`assets/audio/sfx/*.ogg`) : pluie, roulement du train.

**Les playlists.** Chaque moment du jeu a sa liste de morceaux, jouée dans un ordre au hasard sans répéter celui qui vient de passer. Un moment qui n'a qu'un morceau le joue en boucle.

| Moment | Playlist | Morceaux | Ambiance |
|---|---|---|---|
| Écran titre | `title` | 3 (synthwave) | |
| À bord, trajet, gare refuge | `train` | 3 (synthwave) | roulement (à bord et en trajet) |
| Arrêt de jour | `explore_day` | 19 (lofi, ~45 min) | pluie infectée quand elle tombe |
| Arrêt de nuit | `explore_night` | 10 (lofi 8-bit, darksynth, ~40 min) | idem |
| Horde | `danger` | 3, jusqu'à ce qu'elle soit repoussée | |
| Train raté (bilan) | `defeat` | 1, en boucle | |

**Refaire les fichiers.** Les sources téléchargées ne sont pas dans le repo (elles pèsent 400 Mo). On les range dans un dossier (`music/`, `sfx/` avec les archives décompressées), puis `python3 tools/build_audio.py <dossier>` : volume des musiques égalisé (-18 LUFS) et OGG compact, bruitages découpés, mixés et égalisés, ambiances en boucle sans couture, et `core/audio_catalog.gd` (playlists, variantes, crédits) et `assets/audio/CREDITS.md` réécrits. Pour changer un bruitage : modifier sa recette dans le script et relancer.

**Le code.** L'autoload `Audio` joue tout :

- `Audio.play(&"hit")` : un bruitage, hauteur légèrement variée (sauf les petites mélodies, toujours justes). Un même son relancé trop vite est ignoré : dix ennemis touchés font un seul « paf ».
- `Audio.play_at(&"growl", position)` : un son d'ennemi, qui s'atténue au loin et passe à gauche ou à droite.
- `Audio.play_music(&"explore_day")` : fondu enchaîné vers la playlist de ce moment.
- Tous les boutons font « clic » ; un bouton d'action peut avoir son propre son (`MenuKit.action(..., &"craft")`).
- Bus `Music` et `SFX` (`default_bus_layout.tres`), limiteur sur le bus principal. Volumes dans `user://settings.cfg`.
- Les tests coupent le son (`Audio.enabled = false`), sauf `test_audio.gd`. Un test vérifie que chaque son demandé dans le code existe, un autre que chaque œuvre a son crédit.
