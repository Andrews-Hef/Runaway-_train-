# Architecture

Comment le code est rangé, les principes qui le tiennent, et comment ajouter du contenu sans toucher au moteur.

## Principes

**Toutes les entrées convergent vers l'InputMap.** Clavier, manette et tactile déclenchent les mêmes actions (`move_*`, `attack`, `interact`). Le gameplay ne lit que ces actions.

**Les données sont dans des fichiers, pas dans le code.** Un type de ressource est un `LootData` (`data/loot/*.tres`) ; l'infection d'une tuile est une donnée du TileSet (`infection`, de 0 à 1) ; chaque objet récoltable est une scène réglable dans l'inspecteur.

**Le hasard est reproductible.** Chaque arrêt a une graine tirée par `GameState`. Le générateur est une fonction pure (profil + graine → plan), donc une zone qui pose problème peut être rejouée à l'identique. Pour figer le hasard : `game/debug/fixed_seed` dans les Paramètres du projet (0 = aléatoire), ou `seed_override` / `zone_override` sur la scène `stop_zone` pour tester une zone précise. Pour couper l'énergie et les pannes (déboguer le reste) : `game/debug/engine_trouble` à faux ; les tests le font pour toutes les suites sauf `test_engine.gd`. La panne moteur a son propre hasard : une panne ne change pas les arrêts tirés ensuite.

**Les systèmes sont indépendants et branchés par la zone.** `stop_zone.gd` assemble la carte et relie les systèmes entre eux ; chaque système porte ses propres règles et se teste seul.

## Les systèmes

| Système | Fichier | Rôle |
|---|---|---|
| `StopSession` | `levels/stop_session.gd` | Compte à rebours, sifflet, butin, fin de la sortie |
| `ExpeditionResult` | `core/expedition_result.gd` | Résultat d'une sortie (butin, exposition, à bord ou non) |
| `ExposureComponent` | `entities/player/exposure_component.gd` | Jauge d'exposition à l'infection |
| `InfectionGround` | `levels/infection_ground.gd` | Sol qui connaît son niveau d'infection |
| `Interactable` / `Harvestable` | `entities/interaction/` | Objets à « maintenir Agir », objets récoltables |
| `Interactor` | `entities/interaction/interactor.gd` | Cible l'objet le plus proche, gère l'appui maintenu |
| `Train` | `entities/train/` | Train vu de dehors : sifflet, départ, porte, nombre de wagons |
| `Audio` (autoload) | `core/audio.gd` | Bruitages (partout ou placés dans le monde), musique en fondu enchaîné, ambiances, clic des boutons, volumes |
| `InputMode` (autoload) | `core/input_mode.gd` | Dernier périphérique utilisé (clavier, manette, tactile) |
| `GameState` (autoload) | `core/game_state.gd` | Partie en cours : numéro d'arrêt, prochaine zone et graine, stock du train |
| `ZoneProfile` | `core/zone_profile.gd` | Type d'arrêt : biome, spécialité, fourchettes d'objets, d'infection, de sol piégeux, de durée (`data/zones/*.tres`) |
| `BiomeData` | `core/biome_data.gd` | Biome d'une région : sol, lumière, météo, règle, décors propres (`data/biomes/*.tres`) |
| `BiomeRules` | `levels/stop_zone/biome_rules.gd` | Règle du biome pendant un arrêt : eau, froid, glace, flaques toxiques, alarmes |
| `EventData` | `core/event_data.gd` | Événement d'arrêt (`data/events/*.tres`) : chance par biome, déroulé, effets ; tiré pour chaque voie de l'aiguillage |
| `InfectedRain` | `levels/stop_zone/infected_rain.gd` | Déroulé de la pluie infectée : alerte, pluie, fin, exposition à découvert |
| `CrewLife` | `core/crew_life.gd` | Vie de l'équipage pendant un trajet : travail, fatigue, infection, contagion, ruche, mort, confiance, départs |
| `CrewRequests` | `core/crew_requests.gd` | Demandes personnelles de l'équipage (donner, éliminer, rapporter) et confiance gagnée |
| `CaptainDecisions` | `core/captain_decisions.gd` | Ce que décide le capitaine quand ton grade ne suffit pas : voie la plus sûre, soins de l'équipage, construction, dépôt |
| `MissionSim` | `core/mission_sim.gd` | Mission d'équipage simulée (Capitaine) : butin, blessures, infection, fatigue, mort |
| `DayClock` | `core/day_clock.gd` | Heure du jeu (minutes depuis le jour 1) : jour, lumière du jour, nuit, teinte du ciel |
| `Horde` | `levels/stop_zone/horde.gd` | Horde surprise : délai, composition, pertes ; ses membres (`Enemy.join_siege`) frappent le train |
| `ZoneGenerator` | `levels/zone_generator.gd` | Génération pure d'un plan de zone : même profil + même graine = même zone |
| `EncounterData` / `EncounterChoice` | `core/` | Une rencontre et ses choix (coût, gain, recrutement, exposition), en `.tres` dans `data/encounters/` |
| `EncounterResolver` | `core/encounter_resolver.gd` | Applique un choix au butin de la sortie (pur, testable) |
| `EncounterSpot` | `entities/interaction/encounter_spot.gd` | PNJ ou objet qui ouvre une rencontre (maintenir Agir) |
| `CrewMember` | `core/crew_member.gd` | Un équipier : prénom et nom, apparence, stats, équipement, jauges, infection cachée |
| `CrewFactory` | `core/crew_factory.gd` | Fabrique les recrues : nom, apparence, stats, équipement de départ (pur, reproductible) |
| `CrewLooks` / `CrewNames` | `core/` | Les 20 apparences (sprites et portraits chargés à la demande), les prénoms et noms |
| `ItemData` / `ItemCatalog` | `core/` | Un équipement (`data/items/*.tres`) et le catalogue complet |
| `Loadout` | `core/loadout.gd` | Ce que le joueur porte et les effets cumulés (protection, sac, récolte, dégâts) |
| `BagSlots` | `core/bag_slots.gd` | Le sac en cases : piles de 5, place pour une ressource, rangement des piles |
| `Crafting` | `core/crafting.gd` | Fabrication avec les matériaux du stock (pur, testable) |
| `WagonData` / `LocomotiveLevel` | `core/` | Un type de voiture (`data/wagons/*.tres`) et un niveau de locomotive (`data/locomotive/*.tres`) |
| `TrainRules` | `core/train_rules.gd` | Règles du train : traction, construction, couchettes, places (pur, testable) |
| `EngineRules` | `core/engine_rules.gd` | Énergie de la chaudière et pannes : coût d'un trajet, combustible, risque de panne, réparation (pur, testable) |
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
| `MenuKit` | `ui/common/menu_kit.gd` | Morceaux d'interface partagés par les menus (pastilles, coûts en cases, barre de détail, couleurs) |
| `SlotCell` | `ui/common/slot_cell.gd` | Une case façon inventaire (icône, nombre, liseré doré quand choisie) : inventaire, menu du train |
| `BlueprintPaper` | `ui/common/blueprint_paper.gd` | Feuille de plan quadrillée de l'onglet Plans |

## Les scènes

Ouvrir `project.godot` dans Godot puis **F5**. Le jeu démarre sur l'écran titre (`levels/title/`) : **Continuer** ou **Nouvelle partie**. Ensuite : trajet (`levels/journey/`), intérieur du train (`levels/train_interior/`), puis arrêt (`levels/stop_zone/`) ou gare refuge (`levels/refuge/`) par le levier de la cabine. Pour aller directement à une scène, l'ouvrir et la lancer avec **F6**.

## Ajouter du contenu

**Ajouter une rencontre** : créer un `EncounterData` dans `data/encounters/` (titre, texte, choix réglés dans l'inspecteur), puis l'ajouter à `BY_ID` et à un pool dans `core/encounter_library.gd`. Chaque rencontre doit proposer un choix « Partir » (vérifié par les tests). Un choix qui échange des ressources contre des ressources, un objet ou un plan s'affiche tout seul en cases ; les autres gardent leur phrase.

**Ajouter un équipement** : créer un `ItemData` dans `data/items/` (emplacement, effets, recette), puis l'ajouter à `ALL` dans `core/item_catalog.gd`. Il apparaît tout seul à l'atelier.

**Ajouter un type de voiture** : créer un `WagonData` dans `data/wagons/` (effets, coût, icône de `assets/ui/icons/`), l'ajouter à `BUILDABLE_WAGONS` dans `core/game_state.gd`, puis placer ses meubles dans `LAYOUTS` (`levels/train_interior/train_interior.gd`), sous le même id.

**Régler la traction** : `max_cars` et le coût de chaque niveau dans `data/locomotive/level_*.tres`.

**Ajouter un type d'ennemi** : créer un `EnemyData` dans `data/enemies/` (faction, profil, vie, vitesses, portée, dégâts, exposition, vol, butin, premier arrêt), l'ajouter à `ALL` dans `core/enemy_catalog.gd`, puis régler son nombre dans `enemies` des types de zones.

**Ajouter un plan** : créer un `BlueprintData` dans `data/plans/` (coût, prérequis), l'ajouter à `ALL` dans `core/blueprint_catalog.gd`, puis mettre son id dans le champ `plan` de ce qu'il débloque (équipement, recette ou voiture).

**Ajouter une recette ou un médicament** : créer un `RecipeData` dans `data/recipes/` (poste, coût, produit, plan) et l'ajouter à `core/recipe_catalog.gd`. Un médicament est une ressource (`data/loot/`) avec un champ `cure`.

**Ajouter un ordre du capitaine** : créer un `OrderData` dans `data/orders/` (texte avec `{n}`, type, cible, fourchette, mérite, premier arrêt) et l'ajouter à `ORDERS` dans `core/captain_orders.gd`. Il n'est tiré que s'il est faisable dans la zone.

**Ajouter une gare refuge** : créer un `RefugeData` dans `data/refuges/` (nom, texte, échanges, recrues), puis l'ajouter à `REFUGES` dans `core/game_state.gd`. Les gares se succèdent dans l'ordre de la liste, puis on recommence. Le rythme (une gare tous les 5 arrêts) est `REFUGE_EVERY`.

**Ajouter un type d'arrêt** : dupliquer un fichier de `data/zones/`, choisir son biome, écrire sa spécialité, régler ses fourchettes (objets, nappes de sol piégeux, `extras` comme les fûts), puis l'ajouter à `ZONES` dans `core/game_state.gd`. Aucun autre code à toucher.

**Ajouter un biome** : créer un `BiomeData` dans `data/biomes/` (sol généré par `tools/gen_placeholders.py`, lumière, météo, règle, décors qui remplacent ceux de la campagne), l'ajouter à `REGIONS` dans `core/game_state.gd`, puis lui donner au moins 3 types d'arrêt.

## Dossiers

```
art/         définitions des sprites td2d (JSON), voir art/README.md
assets/      sprites, tuiles, police, sons et musiques (assets/audio/)
core/        données et services partagés (LootData, ExpeditionResult, InputMode…)
docs/        documentation (gameplay, architecture, graphismes et son, builds)
data/        ressources de jeu (.tres) : matériaux, équipements, types de zones, rencontres, voitures, locomotive, gares refuges
entities/    joueur, train, PNJ, interactions
props/       objets du décor : épave, arbre mort, plantes, rocher, maison, abri, charrette, caisse…
levels/      trajet, intérieur du train, zone d'arrêt, gare refuge, générateur de zones, règles d'un arrêt
ui/          HUD, menu du train, menu de la gare, fenêtre de rencontre, écran de bilan, contrôles tactiles, thème
tests/       tests automatiques headless
tools/       scripts hors Godot (ignorés par Godot via .gdignore)
```

## Déboguer

- **Figer le hasard** : `game/debug/fixed_seed` dans les Paramètres du projet (0 = aléatoire), ou `seed_override` / `zone_override` sur la scène `stop_zone`.
- **Couper l'énergie et les pannes** : `game/debug/engine_trouble` à faux.
- **Aller directement à une scène** : l'ouvrir dans l'éditeur et la lancer avec **F6**.

### Tester les contrôles tactiles sur PC

Ils n'apparaissent que si le dernier périphérique utilisé est le tactile. Pour les forcer sur PC (la souris simule alors le doigt), au choix :

- **Paramètres du projet** → cocher *Paramètres avancés* → `game/debug/force_touch_controls` = activé
- **Ligne de commande** : `godot --path . -- --touch`

Le forçage est ignoré dans un build release.

## Conventions

- GDScript **typé** (le projet avertit sur les déclarations non typées), indentation par tabulations.
- Fichiers et dossiers en `snake_case`, un dossier par élément de jeu (script + scène ensemble).
- Commits en français, style *conventional commits* : `feat:`, `fix:`, `chore:`, `test:`, `docs:`.
