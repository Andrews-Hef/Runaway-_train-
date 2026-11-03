# Runaway Train

Jeu en pixel art pour **Android et PC** : survie et gestion à bord d'un train qui traverse un monde ravagé par une peste qui transforme les gens en membres d'une ruche.

Le design (vision, systèmes, MVP, décisions) est tenu dans le vault Obsidian, dossier `Jeu du train/`.

## Prérequis

- **Godot 4.7 stable**
- Pour Android : les modèles d'export Godot 4.7 (Éditeur → Gérer les modèles d'export) et le SDK Android (Éditeur → Paramètres de l'éditeur → Export → Android)

## Lancer le jeu

Ouvrir `project.godot` dans Godot puis **F5**. La scène principale est pour l'instant la zone de test (`levels/test_zone/`).

## Contrôles

| Action | Clavier | Manette | Tactile |
|---|---|---|---|
| Se déplacer | ZQSD en AZERTY (WASD en QWERTY) ou flèches | Stick gauche, croix directionnelle | Joystick : toucher la moitié gauche de l'écran |
| Coup | Espace | X (Xbox) / Carré (PlayStation) | Bouton « Coup » |
| Agir | E | A (Xbox) / Croix (PlayStation) | Bouton « Agir » |
| Pause *(pas encore utilisée)* | Échap | Start | — |

Les touches sont définies par **position physique** : ZQSD fonctionne directement en AZERTY, sans réglage.

### Tester les contrôles tactiles sur PC

Ils n'apparaissent que sur un écran tactile. Pour les forcer sur PC (la souris simule alors le doigt), au choix :

- **Paramètres du projet** → cocher *Paramètres avancés* → `game/debug/force_touch_controls` = activé
- **Ligne de commande** : `godot --path . -- --touch`

Le forçage est ignoré dans un build release.

## Architecture

**Toutes les entrées convergent vers l'InputMap.** Clavier, manette et tactile déclenchent les mêmes actions (`move_*`, `attack`, `interact`). Le gameplay ne lit que ces actions : il ne sait pas quel périphérique est utilisé. Ajouter un périphérique = ajouter un évènement à une action, sans toucher au gameplay.

- Le joystick tactile est le nœud natif `VirtualJoystick` de Godot 4.7, branché sur les actions `move_*`.
- Les boutons tactiles (`ui/touch/touch_action_button.gd`) envoient un vrai `InputEventAction`, identique à un appui clavier.
- Le jeu suit le dernier périphérique utilisé : toucher l'écran affiche les contrôles tactiles, utiliser un clavier ou une manette les masque.

```
assets/      sprites et tuiles (temporaires pour l'instant)
entities/    personnages (player/…)
props/       objets du décor (rochers…)
levels/      zones jouables (test_zone/…)
ui/touch/    contrôles tactiles
tests/       tests automatiques headless
tools/       scripts hors Godot (ignoré par Godot via .gdignore)
```

## Rendu

- Résolution de base **480×270**, mise à l'échelle entière (×4 en 1080p).
- Aspect `expand` : sur un téléphone 20:9, on voit un peu plus de monde en largeur (600×270), sans bandes noires.
- Rendu *Compatibility* (meilleure couverture Android), filtre *Nearest* pour des pixels nets.
- **Le violet est réservé à l'infection** : aucune autre chose du jeu ne doit l'utiliser.

## Tests

```
godot --headless --path . --script res://tests/run_tests.gd
```

Sous Windows, utiliser l'exécutable console : `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`.

Code de sortie 0 = tout est vert. Une erreur de script pendant un test le fait échouer. Pour ajouter une suite : créer `tests/test_xxx.gd` qui `extends TestCase`, puis l'ajouter à `SUITES` dans `tests/run_tests.gd`.

## Conventions

- GDScript **typé** (le projet avertit sur les déclarations non typées), indentation par tabulations.
- Fichiers et dossiers en `snake_case`, un dossier par élément de jeu (script + scène ensemble).
- Commits en français, style *conventional commits* : `feat:`, `fix:`, `chore:`, `test:`, `docs:`.

## Assets temporaires

Les sprites actuels sont générés par `python tools/gen_placeholders.py` (Pillow requis). Ils seront remplacés par les vrais assets.

## Licence

**Tous droits réservés.** Aucune utilisation, copie, modification ou distribution du contenu de ce dépôt n'est autorisée sans l'accord écrit de l'auteur. Voir [LICENSE](LICENSE).
