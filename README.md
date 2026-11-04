# Runaway Train

Jeu en pixel art pour **Android et PC** : survie et gestion à bord d'un train qui traverse un monde ravagé par une peste qui transforme les gens en membres d'une ruche.

Le design (vision, systèmes, MVP, décisions) est tenu dans le vault Obsidian, dossier `Jeu du train/`.

## Ce qui est jouable

Un **voyage** d'arrêt en arrêt :

- **Trajet** : le train roule, le décor défile. On voit le stock du train et le prochain arrêt.
- **Dans le train** (vue de dessus, toit retiré) : tu marches de wagon en wagon par les passerelles. **Coffre** du stock, **établi** de l'atelier (fabriquer de l'équipement), **casier** (s'équiper), **couchettes** du dortoir (l'équipage), **table du capitaine** (construire des voitures, renforcer la locomotive) et le **levier** de la cabine pour descendre au prochain arrêt. La voie défile sous le train : on la voit entre les wagons, aux deux bouts et au bas de l'écran.
- **Arrêt** : chaque zone est **générée au hasard** à partir d'un type de zone (plaine, forêt morte, casse automobile, terres contaminées). Le premier arrêt est toujours une plaine.
- **Points d'intérêt** dans les zones : **village abandonné** (maisons en ruine, caisses à fouiller), **refuge** avec un survivant à **recruter**, **marchand ambulant** pour **échanger**, et petites rencontres (sac abandonné, armoire à forcer).
- **Gare refuge** (arrêts n°5, 10, 15…) : une ville fortifiée sur la ligne, **zone sûre** sans infection ni chrono. **Comptoir** pour échanger le surplus du stock, **bureau de quarantaine** pour recruter des survivants sains, **dépôt** pour renforcer la locomotive. On repart en remontant à bord.
- **Retour à bord** : le butin et les recrues rejoignent le train et on repart vers l'arrêt suivant.
- **Campagne continue et sauvegarde** : chaque gare refuge est un **point de reprise**. **Train raté** : on reprend à la dernière gare (ou au départ du train), tout ce qui s'est passé depuis est perdu. La session est aussi sauvegardée à chaque trajet (`user://saves/`), pour reprendre après avoir fermé le jeu.

**Médicaments et infirmerie** : antiseptique (−10 %) et antibiotiques (−20 %) se trouvent dans les caisses et les armoires, et s'achètent chez les marchands et en gare. Le **sérum de sève** (−35 %) et le **vaccin expérimental** (−60 %) se préparent à l'**infirmerie**, une voiture à construire, avec les plans Pharmacie et Vaccin. On prend ses médicaments dans l'onglet **Infirmerie** du menu du train.

**Plans et recherche** : les recettes avancées sont dans des **plans**. On les trouve en fouillant (caisses, armoires, sacs), on les achète aux marchands et en gare, puis on les **étudie** à l'atelier (table des plans) en payant des ressources. Les plans ont des prérequis : c'est un arbre.

| Plan | Prérequis | Débloque |
|---|---|---|
| Métallurgie | — | Plaques de métal (3 ferrailles → 1 plaque), plastron en tôle |
| Chimie de base | — | Produits chimiques (3 plantes infectées → 1), kit de chimie, masque à cartouches |
| Horticulture | — | Voiture **Serre** (2 plantes saines à chaque trajet) |
| Chalumeau | Métallurgie | Chalumeau (découpe les **épaves de camion** : plaques et pièces) |
| Armurerie | Métallurgie | Masse de chantier (dégâts 4) |
| Pharmacie | Chimie | Antibiotiques et sérum de sève (infirmerie) |
| Distillerie | Chimie, Métallurgie | Voiture **Laboratoire** (2 plantes infectées → 1 produit chimique à chaque trajet) |
| Aménagement des voitures | Métallurgie | Niveau 3 du dortoir, du stock, de l'infirmerie et de la serre |
| Vaccin expérimental | Pharmacie | Vaccin (infirmerie) |

**Extraction** : des outils ouvrent de nouvelles ressources (chalumeau sur les épaves de camion, kit de chimie qui tire des produits chimiques des plantes infectées), l'atelier transforme (ferraille → plaques), et les machines du train (serre, laboratoire) produisent pendant les trajets.

**Grades et ordres du capitaine** : à chaque arrêt (sauf en gare), le capitaine donne un **ordre** adapté à la zone : « Ramène 6 ferrailles », « Élimine 2 pilleurs », « Reviens avec moins de 25 % d'exposition »… Il est suivi en haut de l'écran. Ordre rempli et ennemis éliminés rapportent du **mérite**. Au fil du mérite, tu montes en grade : **Recrue → Soldat → Caporal → Sergent → Lieutenant → Capitaine**. À chaque promotion, tu choisis **un talent parmi deux** (+2 PV, sac +4, dégâts +1, se dégager plus vite, récolte plus rapide, armure…). Onglet **Grade** du menu du train : grade, mérite, ordre en cours, talents.

**Le train** : la locomotive tire un nombre limité de voitures, cabine comprise. On part avec 4 voitures (dortoir, atelier, stock, cabine) et une locomotive qui en tire 5 ; chaque renfort, fait au **dépôt d'une gare refuge**, en ajoute une, **jusqu'à 8**. Les voitures se construisent à bord avec le stock et s'attellent en queue.

| Voiture | Effet | Coût |
|---|---|---|
| Dortoir | +4 couchettes : sans couchette libre, on ne peut plus recruter | 8 bois, 4 tissu, 4 ferraille |
| Stock | +60 places : ce qui ne rentre pas reste sur le quai au retour | 10 bois, 6 ferraille |
| Cabine, atelier | Uniques, présentes dès le départ | — |

**Agrandir les voitures** (table du capitaine, onglet Train) : chaque type de voiture monte de niveau, et toutes ses voitures avec (le coût est multiplié par leur nombre). Le niveau 3 demande le plan **Aménagement des voitures**.

| Voiture | Niv. 2 | Niv. 3 (plan Aménagement) |
|---|---|---|
| Dortoir | +2 couchettes | +2 couchettes |
| Stock | +30 places | +30 places |
| Infirmerie | médicaments +5 points | médicaments +5 points |
| Serre | +1 plante par trajet | +1 plante par trajet |
| Laboratoire | +1 produit chimique par trajet | — |

**Équipement** : tenue, masque, sac, outil, arme. Il se fabrique à l'atelier avec les matériaux du stock, ou se trouve et s'achète en sortie.

| Emplacement | Effet |
|---|---|
| Tenue, masque | **Protection** : l'exposition monte moins vite (plafonnée à 80 %). **Armure** : dégâts en moins par coup (il en reste toujours 1) — gilet en kevlar (armure 2, acheté au ferrailleur), plastron en tôle (armure 1, fabriqué). Tenue anti-infection ou anti-coups : à choisir selon la zone. |
| Sac | Capacité : nombre de ressources rapportées par sortie (« Sac plein ! ») |
| Outil | Récolte plus rapide d'un type d'objet (pied-de-biche, hachette, sécateur) |
| Arme | Dégâts, pour le futur combat |

Pendant un arrêt :

1. Le train s'arrête. Tu as **60 à 110 secondes** selon la zone avant le départ.
2. Tu récoltes en **maintenant Agir** près d'un objet : **ferraille** (épaves), **bois** (arbres morts), **plantes**, et **plantes infectées** dans les zones violettes.
3. Marcher sur le sol violet, cueillir une plante infectée ou prendre un coup d'infecté fait monter ton **infection**. Elle **reste d'un arrêt à l'autre** (ni le train ni les gares ne la font baisser) : seuls les **médicaments** la soignent. Paliers : **Fièvre** (30 %, −2 PV), **Contaminé** (60 %, −4 PV, plus lent), **Critique** (90 %, −6 PV, encore plus lent) ; à **100 %**, tu rejoins la ruche (reprise à la dernière gare).
4. **Combat** : des **infectés** rôdent dans les zones violettes, des **pilleurs** dans les zones saines. Frappe avec **Coup** (dégâts de l'arme portée). Tu as **10 points de vie**, rendus à chaque arrêt. Plaqué au sol par un rampant : **martèle Coup** pour te dégager.
5. À 15 secondes du départ, **le train siffle**. Remonte à bord en maintenant Agir devant la porte du wagon.
6. **Bilan** : butin, exposition et risque d'infection. Si tu rates le train ou si tu tombes, tu reprends à la dernière gare refuge.

Chaque faction a quatre profils :

| Profil | Infectés (exposition) | Pilleurs (vol dans le sac) | Comportement |
|---|---|---|---|
| Infanterie | **Infecté** — 3 PV, 1 dégât + 8 % | **Pilleur** — 4 PV, 2 dégâts + vole 1 | Poursuit et frappe |
| Rampant | **Rampant** — 2 PV, 1 dégât + 5 % par morsure | **Embusqué** — 3 PV, 1 dégât + vole 1 par seconde | Plaque au sol : martèle Coup pour te dégager |
| Tireur | **Cracheur** — 2 PV, crachat lent 1 dégât + 12 % | **Tireur** — 2 PV, balle 3 dégâts (ligne de visée) | Garde ses distances, fuit si on approche |
| Lourd | **Boursouflé** — 8 PV, 3 dégâts + 15 % | **Brute** — 9 PV, 4 dégâts | Lent, ne recule pas, coup large (zone rouge) |

- Tous prennent leur élan avant d'agir : s'éloigner à temps esquive le coup. La ligne du Tireur se fige juste avant le tir : c'est le moment de bouger.
- Les plus dangereux arrivent plus tard : rampants dès l'arrêt 2, tireurs dès le 3, lourds dès le 4. Au premier arrêt, seulement des infectés.
- Les pilleurs rendent ce qu'ils ont volé quand ils tombent, avec un peu de butin. Les ennemis ne bougent pas pendant un dialogue.

## Prérequis

- **Godot 4.7 stable**
- Pour Android : les modèles d'export Godot 4.7 (Éditeur → Gérer les modèles d'export) et le SDK Android (Éditeur → Paramètres de l'éditeur → Export → Android)

## Lancer le jeu

Ouvrir `project.godot` dans Godot puis **F5**. Le jeu démarre sur l'écran titre (`levels/title/`) : **Continuer** ou **Nouvelle partie**. Ensuite : trajet (`levels/journey/`), intérieur du train (`levels/train_interior/`), puis arrêt (`levels/stop_zone/`) ou gare refuge (`levels/refuge/`) par le levier de la cabine. Pour aller directement à une scène, l'ouvrir et la lancer avec **F6**.

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
| `Train` | `entities/train/` | Train vu de dehors : sifflet, départ, porte, nombre de wagons |
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
| `WagonData` / `LocomotiveLevel` | `core/` | Un type de voiture (`data/wagons/*.tres`) et un niveau de locomotive (`data/locomotive/*.tres`) |
| `TrainRules` | `core/train_rules.gd` | Règles du train : traction, construction, couchettes, places (pur, testable) |
| `RefugeData` / `RefugeOffer` | `core/` | Une gare refuge et ses offres (échanges, recrues), en `.tres` dans `data/refuges/` |
| `RefugeRules` | `core/refuge_rules.gd` | Règles des offres d'une gare, payées avec le stock (pur, testable) |
| `SaveStore` | `core/save_store.gd` | Sauvegardes JSON sur le disque (`user://saves/`), une par emplacement |
| `Campaign` | `levels/campaign.gd` | Le fil de la campagne : nouvelle partie, continuer, quand sauvegarder, où reprendre |
| `HealthComponent` | `entities/combat/health_component.gd` | Points de vie (joueur et ennemis), invincibilité après un coup |
| `Enemy` / `EnemyData` / `EnemyCatalog` | `entities/enemy/`, `core/` | Ennemi à états (errance, poursuite, élan, tir, prise, recul) réglé par un `.tres` de `data/enemies/` (faction + profil) |
| `Projectile` | `entities/enemy/projectile.gd` | Balle ou crachat : file tout droit, arrêté par le décor |
| `Career` / `GradeData` / `PerkData` | `core/` | Grades (`data/grades/*.tres`, avec leurs deux talents), mérite, bonus des talents |
| `CaptainOrders` / `OrderData` | `core/` | Ordres du capitaine (`data/orders/*.tres`) : tirage adapté à la zone, suivi, évaluation au retour |
| `Infection` | `core/infection.gd` | Paliers de l'infection (PV, vitesse), 100 % = la ruche |
| `BlueprintData` / `BlueprintCatalog` | `core/` | Plans (`data/plans/*.tres`) : prérequis, coût d'étude, ce qu'ils débloquent |
| `RecipeData` / `RecipeCatalog` | `core/` | Transformations et médicaments (`data/recipes/*.tres`), à l'atelier ou à l'infirmerie |
| `MenuKit` | `ui/common/menu_kit.gd` | Morceaux d'interface partagés par les menus (lignes, coûts, couleurs) |

**Ajouter une rencontre** : créer un `EncounterData` dans `data/encounters/` (titre, texte, choix réglés dans l'inspecteur), puis l'ajouter à `BY_ID` et à un pool dans `core/encounter_library.gd`. Chaque rencontre doit proposer un choix « Partir » (vérifié par les tests).

**Ajouter un équipement** : créer un `ItemData` dans `data/items/` (emplacement, effets, recette), puis l'ajouter à `ALL` dans `core/item_catalog.gd`. Il apparaît tout seul à l'atelier.

**Ajouter un type de voiture** : créer un `WagonData` dans `data/wagons/` (effets, coût), l'ajouter à `BUILDABLE_WAGONS` dans `core/game_state.gd`, puis placer ses meubles dans `LAYOUTS` (`levels/train_interior/train_interior.gd`), sous le même id.

**Régler la traction** : `max_cars` et le coût de chaque niveau dans `data/locomotive/level_*.tres`.

**Ajouter un type d'ennemi** : créer un `EnemyData` dans `data/enemies/` (faction, profil, vie, vitesses, portée, dégâts, exposition, vol, butin, premier arrêt), l'ajouter à `ALL` dans `core/enemy_catalog.gd`, puis régler son nombre dans `enemies` des types de zones.

**Ajouter un plan** : créer un `BlueprintData` dans `data/plans/` (coût, prérequis), l'ajouter à `ALL` dans `core/blueprint_catalog.gd`, puis mettre son id dans le champ `plan` de ce qu'il débloque (équipement, recette ou voiture).

**Ajouter une recette ou un médicament** : créer un `RecipeData` dans `data/recipes/` (poste, coût, produit, plan) et l'ajouter à `core/recipe_catalog.gd`. Un médicament est une ressource (`data/loot/`) avec un champ `cure`.

**Ajouter un ordre du capitaine** : créer un `OrderData` dans `data/orders/` (texte avec `{n}`, type, cible, fourchette, mérite, premier arrêt) et l'ajouter à `ORDERS` dans `core/captain_orders.gd`. Il n'est tiré que s'il est faisable dans la zone.

**Ajouter une gare refuge** : créer un `RefugeData` dans `data/refuges/` (nom, texte, échanges, recrues), puis l'ajouter à `REFUGES` dans `core/game_state.gd`. Les gares se succèdent dans l'ordre de la liste, puis on recommence. Le rythme (une gare tous les 5 arrêts) est `REFUGE_EVERY`.

**Ajouter un type de zone** : dupliquer un fichier de `data/zones/`, régler ses fourchettes dans l'inspecteur, puis l'ajouter à `ZONES` dans `core/game_state.gd`. Aucun autre code à toucher.

```
art/         définitions des sprites td2d (JSON), voir art/README.md
assets/      sprites, tuiles, police
core/        données et services partagés (LootData, ExpeditionResult, InputMode…)
data/        ressources de jeu (.tres) : matériaux, équipements, types de zones, rencontres, voitures, locomotive, gares refuges
entities/    joueur, train, PNJ, interactions
props/       objets du décor : épave, arbre mort, plantes, rocher, maison, abri, charrette, caisse…
levels/      trajet, intérieur du train, zone d'arrêt, gare refuge, générateur de zones, règles d'un arrêt
ui/          HUD, menu du train, menu de la gare, fenêtre de rencontre, écran de bilan, contrôles tactiles, thème
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
