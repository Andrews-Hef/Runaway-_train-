# Runaway Train

Jeu en pixel art pour **Android et PC** : survie et gestion à bord d'un train qui traverse un monde ravagé par une peste qui transforme les gens en membres d'une ruche.

Le design (vision, systèmes, MVP, décisions) est tenu dans le vault Obsidian, dossier `Jeu du train/`.

## Ce qui est jouable

Un **arrêt complet** du train :

1. Le train s'arrête. Tu as **90 secondes** avant le départ.
2. Tu récoltes en **maintenant Agir** près d'un objet : **ferraille** (épaves), **bois** (arbres morts), **plantes**, et **plantes infectées** dans les zones violettes.
3. Marcher sur le sol violet ou cueillir une plante infectée fait monter ta **jauge d'exposition**.
4. À 15 secondes du départ, **le train siffle**. Remonte à bord en maintenant Agir devant la porte du wagon.
5. **Bilan** : butin, exposition et risque d'infection. Si tu rates le train, il part sans toi et la sortie est perdue.

## Prérequis

- **Godot 4.7 stable**
- Pour Android : les modèles d'export Godot 4.7 (Éditeur → Gérer les modèles d'export) et le SDK Android (Éditeur → Paramètres de l'éditeur → Export → Android)

## Lancer le jeu

Ouvrir `project.godot` dans Godot puis **F5**. La scène principale est la zone d'arrêt (`levels/stop_zone/`).

## Contrôles

| Action | Clavier | Manette | Tactile |
|---|---|---|---|
| Se déplacer | ZQSD en AZERTY (WASD en QWERTY) ou flèches | Stick gauche, croix directionnelle | Joystick : toucher la moitié gauche de l'écran |
| Agir (maintenir) : récolter, monter à bord | E | A (Xbox) / Croix (PlayStation) | Bouton « Agir » |
| Coup *(pas encore de combat)* | Espace | X (Xbox) / Carré (PlayStation) | Bouton « Coup » |
| Pause *(pas encore utilisée)* | Échap | Start | — |

Les touches sont définies par **position physique** : ZQSD fonctionne directement en AZERTY, sans réglage. Les consignes à l'écran s'adaptent au dernier périphérique utilisé (« Maintenir E », « Maintenir A » ou « Maintenir Agir »).

### Tester les contrôles tactiles sur PC

Ils n'apparaissent que si le dernier périphérique utilisé est le tactile. Pour les forcer sur PC (la souris simule alors le doigt), au choix :

- **Paramètres du projet** → cocher *Paramètres avancés* → `game/debug/force_touch_controls` = activé
- **Ligne de commande** : `godot --path . -- --touch`

Le forçage est ignoré dans un build release.

## Architecture

**Toutes les entrées convergent vers l'InputMap.** Clavier, manette et tactile déclenchent les mêmes actions (`move_*`, `attack`, `interact`). Le gameplay ne lit que ces actions.

**Les données sont dans des fichiers, pas dans le code.** Un type de ressource est un `LootData` (`data/loot/*.tres`) ; l'infection d'une tuile est une donnée du TileSet (`infection`, de 0 à 1) ; chaque objet récoltable est une scène réglable dans l'inspecteur.

**Les systèmes sont indépendants et branchés par la zone.** `stop_zone.gd` assemble la carte et relie les systèmes entre eux ; chaque système porte ses propres règles et se teste seul.

| Système | Fichier | Rôle |
|---|---|---|
| `StopSession` | `levels/stop_session.gd` | Compte à rebours, sifflet, butin, fin de la sortie |
| `ExpeditionResult` | `core/expedition_result.gd` | Résultat d'une sortie (butin, exposition, à bord ou non) |
| `ExposureComponent` | `entities/player/exposure_component.gd` | Jauge d'exposition à l'infection |
| `InfectionGround` | `levels/infection_ground.gd` | Sol qui connaît son niveau d'infection |
| `Interactable` / `Harvestable` | `entities/interaction/` | Objets à « maintenir Agir », objets récoltables |
| `Interactor` | `entities/interaction/interactor.gd` | Cible l'objet le plus proche, gère l'appui maintenu |
| `Train` | `entities/train/` | Sifflet, départ, porte du wagon |
| `InputMode` (autoload) | `core/input_mode.gd` | Dernier périphérique utilisé (clavier, manette, tactile) |

```
art/         définitions des sprites td2d (JSON), voir art/README.md
assets/      sprites, tuiles, police
core/        données et services partagés (LootData, ExpeditionResult, InputMode…)
data/        ressources de jeu (.tres) : types de butin…
entities/    joueur, train, interactions
props/       objets du décor : épave, arbre mort, plantes, rocher
levels/      zones jouables et règles d'un arrêt
ui/          HUD, écran de bilan, contrôles tactiles, thème
tests/       tests automatiques headless
tools/       scripts hors Godot (ignorés par Godot via .gdignore)
```

## Rendu et graphismes

- Résolution de base **480×270**, mise à l'échelle entière (×4 en 1080p). Sur un téléphone 20:9, on voit un peu plus de monde en largeur (600×270).
- Rendu *Compatibility* (meilleure couverture Android), filtre *Nearest* pour des pixels nets.
- **Le violet est réservé à l'infection** : aucune autre chose du jeu ne doit l'utiliser.
- **Sprites temporaires** générés par [td2d](https://github.com/brphillis/threedee-twodee) à partir de modèles 3D décrits en JSON : voir `art/README.md`. Les tuiles du sol viennent de `python tools/gen_placeholders.py`.
- **Police** : [Tiny5](https://github.com/Gissio/font_tiny5), une police pixel de 5 px, nette à 8 px (texte) et 16 px (titres).

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

## Licence

**Tous droits réservés.** Aucune utilisation, copie, modification ou distribution du contenu de ce dépôt n'est autorisée sans l'accord écrit de l'auteur. Voir [LICENSE](LICENSE).

Exception : la police Tiny5 (`assets/fonts/tiny5/`) reste sous sa propre licence, la SIL Open Font License 1.1 (`OFL.txt`).
