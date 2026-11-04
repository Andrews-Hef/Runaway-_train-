# Runaway Train

Jeu en pixel art pour **Android et PC** : survie et gestion à bord d'un train qui traverse un monde ravagé par une peste qui transforme les gens en membres d'une ruche.

Le design (vision, systèmes, MVP, décisions) est tenu dans le vault Obsidian, dossier `Jeu du train/`.

## Ce qui est jouable

Un **voyage** d'arrêt en arrêt :

- **Trajet** : le train roule, le décor défile. On voit le stock du train et le prochain arrêt.
- **Dans le train** (vue en coupe) : tu marches de wagon en wagon. **Coffre** du stock, **établi** de l'atelier (fabriquer de l'équipement), **casier** (s'équiper), **couchettes** du dortoir (l'équipage), et le **levier** de la cabine pour descendre au prochain arrêt. Le paysage défile aux fenêtres.
- **Arrêt** : chaque zone est **générée au hasard** à partir d'un type de zone (plaine, forêt morte, casse automobile, terres contaminées). Le premier arrêt est toujours une plaine.
- **Points d'intérêt** dans les zones : **village abandonné** (maisons en ruine, caisses à fouiller), **refuge** avec un survivant à **recruter**, **marchand ambulant** pour **échanger**, et petites rencontres (sac abandonné, armoire à forcer).
- **Retour à bord** : le butin et les recrues rejoignent le train et on repart vers l'arrêt suivant. **Train raté** : la partie est finie, recrues comprises.

**Équipement** : tenue, masque, sac, outil, arme. Il se fabrique à l'atelier avec les matériaux du stock, ou se trouve et s'achète en sortie.

| Emplacement | Effet |
|---|---|
| Tenue, masque | Protection : l'exposition monte moins vite (plafonnée à 80 %) |
| Sac | Capacité : nombre de ressources rapportées par sortie (« Sac plein ! ») |
| Outil | Récolte plus rapide d'un type d'objet (pied-de-biche, hachette, sécateur) |
| Arme | Dégâts, pour le futur combat |

Pendant un arrêt :

1. Le train s'arrête. Tu as **60 à 110 secondes** selon la zone avant le départ.
2. Tu récoltes en **maintenant Agir** près d'un objet : **ferraille** (épaves), **bois** (arbres morts), **plantes**, et **plantes infectées** dans les zones violettes.
3. Marcher sur le sol violet ou cueillir une plante infectée fait monter ta **jauge d'exposition**.
4. À 15 secondes du départ, **le train siffle**. Remonte à bord en maintenant Agir devant la porte du wagon.
5. **Bilan** : butin, exposition et risque d'infection. Si tu rates le train, il part sans toi et la partie est perdue.

## Prérequis

- **Godot 4.7 stable**
- Pour Android : les modèles d'export Godot 4.7 (Éditeur → Gérer les modèles d'export) et le SDK Android (Éditeur → Paramètres de l'éditeur → Export → Android)

## Lancer le jeu

Ouvrir `project.godot` dans Godot puis **F5**. Le jeu démarre sur le trajet (`levels/journey/`), entre dans le train (`levels/train_interior/`), puis descend au premier arrêt (`levels/stop_zone/`) par le levier de la cabine. Pour aller directement à une scène, l'ouvrir et la lancer avec **F6**.

## Contrôles

| Action | Clavier | Manette | Tactile |
|---|---|---|---|
| Se déplacer | ZQSD en AZERTY (WASD en QWERTY) ou flèches | Stick gauche, croix directionnelle | Joystick : toucher la moitié gauche de l'écran |
| Agir (maintenir) : récolter, monter à bord | E | A (Xbox) / Croix (PlayStation) | Bouton « Agir » |
| Coup de barre de fer *(pas encore d'ennemi)* | Espace | X (Xbox) / Carré (PlayStation) | Bouton « Coup » |
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

**Le hasard est reproductible.** Chaque arrêt a une graine tirée par `GameState`. Le générateur est une fonction pure (profil + graine → plan), donc une zone qui pose problème peut être rejouée à l'identique. Pour figer le hasard : `game/debug/fixed_seed` dans les Paramètres du projet (0 = aléatoire), ou `seed_override` / `zone_override` sur la scène `stop_zone` pour tester une zone précise.

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
| `GameState` (autoload) | `core/game_state.gd` | Partie en cours : numéro d'arrêt, prochaine zone et graine, stock du train |
| `ZoneProfile` | `core/zone_profile.gd` | Type de zone : fourchettes d'objets, d'infection, de durée (`data/zones/*.tres`) |
| `ZoneGenerator` | `levels/zone_generator.gd` | Génération pure d'un plan de zone : même profil + même graine = même zone |
| `EncounterData` / `EncounterChoice` | `core/` | Une rencontre et ses choix (coût, gain, recrutement, exposition), en `.tres` dans `data/encounters/` |
| `EncounterResolver` | `core/encounter_resolver.gd` | Applique un choix au butin de la sortie (pur, testable) |
| `EncounterSpot` | `entities/interaction/encounter_spot.gd` | PNJ ou objet qui ouvre une rencontre (maintenir Agir) |
| `CrewMember` | `core/crew_member.gd` | Une recrue : prénom, rôle, infection cachée |
| `ItemData` / `ItemCatalog` | `core/` | Un équipement (`data/items/*.tres`) et le catalogue complet |
| `Loadout` | `core/loadout.gd` | Ce que le joueur porte et les effets cumulés (protection, sac, récolte, dégâts) |
| `Crafting` | `core/crafting.gd` | Fabrication avec les matériaux du stock (pur, testable) |

**Ajouter une rencontre** : créer un `EncounterData` dans `data/encounters/` (titre, texte, choix réglés dans l'inspecteur), puis l'ajouter à `BY_ID` et à un pool dans `core/encounter_library.gd`. Chaque rencontre doit proposer un choix « Partir » (vérifié par les tests).

**Ajouter un équipement** : créer un `ItemData` dans `data/items/` (emplacement, effets, recette), puis l'ajouter à `ALL` dans `core/item_catalog.gd`. Il apparaît tout seul à l'atelier.

**Ajouter un wagon** : ajouter une entrée à `WAGONS` dans `levels/train_interior/train_interior.gd` (nom et meubles).

**Ajouter un type de zone** : dupliquer un fichier de `data/zones/`, régler ses fourchettes dans l'inspecteur, puis l'ajouter à `ZONES` dans `core/game_state.gd`. Aucun autre code à toucher.

```
art/         définitions des sprites td2d (JSON), voir art/README.md
assets/      sprites, tuiles, police
core/        données et services partagés (LootData, ExpeditionResult, InputMode…)
data/        ressources de jeu (.tres) : matériaux, équipements, types de zones, rencontres
entities/    joueur, train, PNJ, interactions
props/       objets du décor : épave, arbre mort, plantes, rocher, maison, abri, charrette, caisse…
levels/      trajet, intérieur du train, zone d'arrêt, générateur de zones, règles d'un arrêt
ui/          HUD, menu du train, fenêtre de rencontre, écran de bilan, contrôles tactiles, thème
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
