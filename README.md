# Runaway Train

Jeu en pixel art pour **Android et PC** : survie et gestion à bord d'un train qui traverse un monde ravagé par une peste qui transforme les gens en membres d'une ruche.

Le design (vision, systèmes, MVP, décisions) est tenu dans le vault Obsidian, dossier `Jeu du train/`.

## Ce qui est jouable

Un **voyage** d'arrêt en arrêt :

- **Intro** : une nouvelle partie commence par le contexte, en quelques pages par-dessus le premier trajet (la peste et la ruche, les gares fortifiées, le train qui ne s'arrête jamais longtemps, toi la recrue), puis le premier ordre du capitaine. Un appui affiche la page en entier, le suivant passe à la suite ; Échap, le bouton retour ou « Passer » sautent tout. Une partie reprise ne la rejoue pas. Le texte est dans `ui/intro/intro_overlay.gd`.
- **Trajet** : le train roule, le décor défile. On voit le stock du train et le prochain arrêt.
- **Dans le train** (vue de dessus, toit retiré) : tu marches de wagon en wagon par les passerelles. **Coffre** du stock, **établi** de l'atelier (fabriquer de l'équipement), **casier** (ouvre l'inventaire pour s'équiper), **couchettes** du dortoir (l'équipage), **table du capitaine** (construire des voitures, renforcer la locomotive) et le **levier** de la cabine pour descendre au prochain arrêt. La voie défile sous le train : on la voit entre les wagons, aux deux bouts et au bas de l'écran.
- **Régions** : la ligne traverse 5 biomes, un par tronçon entre deux gares refuges : **Campagne** (arrêts 1 à 5) → **Marais infecté** → **Ville en ruine** → **Zone industrielle** → **Toundra gelée**, puis la ligne repart. Chaque biome a son sol, ses décors, son ambiance et **une règle** :
  - Marais : l'eau stagnante **ralentit**.
  - Toundra : le **froid** fait perdre 1 PV toutes les 15 s sans tenue chaude (veste rembourrée), et la **glace** fait glisser.
  - Ville : fouiller une voiture peut déclencher une **alarme** qui attire les ennemis.
  - Zone industrielle : les **flaques toxiques** brûlent, sauf avec la combinaison étanche.
- **Aiguillage** : avant chaque arrêt (sauf le premier et les gares), le levier de la cabine propose **2 voies**. Chacune montre son type d'arrêt, sa **spécialité** (ce qu'on y trouve), son danger et l'ordre du capitaine. Chaque région a 3 types d'arrêt (ex. en ville : Boulevard, Quartier résidentiel, Hôpital abandonné).
- **Arrêt** : chaque zone est **générée au hasard** à partir de son type d'arrêt. Le premier arrêt est toujours une plaine.
- **Pluie infectée** (événement) : prévue sur la carte de sa voie à l'aiguillage (« Météo : pluie infectée annoncée »), surtout au marais, jamais en toundra ni avant l'arrêt n°3. En zone : le ciel se couvre, alerte 8 s avant, puis 30 à 45 s de pluie violette. **À découvert, l'infection monte** (moins avec masque et tenue) ; contre une maison, un immeuble, un abri, la charrette, un conteneur ou le train, on est **à l'abri**. La pluie fait sortir des infectés et **pousser des plantes infectées**.
- **Horde** (surprise, jamais annoncée) : à partir de l'arrêt n°4, surtout en ville. Quelques secondes après l'arrivée, un groupe d'infectés sort du bas de la carte et **fonce sur le train** pour le frapper ; s'il te voit, il te poursuit, puis retourne au train. Plus grosse au fil des arrêts. Toute la horde éliminée : **+15 mérite**.
- **Équipage vivant** : chaque équipier a 4 jauges, **vie, infection, fatigue, confiance**. Pendant les trajets, chacun travaille selon son rôle : le **mécanicien** répare le train, le **soigneur** soigne le plus blessé et repère les infectés, l'**éclaireur** repère les hordes (« horde repérée » sur la carte de la voie, à l'aiguillage). Travailler fatigue ; épuisé, on ne travaille plus. L'**infection** est cachée au début (« ? »), se voit aux symptômes vers 40 % ou tout de suite avec un soigneur, monte à chaque trajet, contamine les autres ; à 100 %, l'équipier **rejoint la ruche** (une voiture saccagée). La vie baisse avec la maladie, l'épuisement et les attaques de horde sur le train ; à 0, il meurt. **Confiance** : elle monte quand il va bien et quand tu remplis ses **demandes** (« trouve-moi 2 pièces mécaniques », « élimine 2 pilleurs », « rapporte 3 plantes infectées » : +20), baisse avec l'épuisement, les pertes et les demandes ignorées. Fidèle (≥ 70), il travaille mieux ; méfiant (< 25), il peut quitter le train en gare refuge. Onglet **Équipage** : jauges, demande, et **panser** (1 tissu), **médicament**, **repos**, **quarantaine** (infirmerie), **renvoyer**. Le trajet raconte ce qui s'est passé.
- **Jour et nuit** : la partie commence le jour 1 à 6h. En zone, 1 seconde = 1 minute de jeu ; un trajet dure 3 h, une gare refuge 1 h (environ 5 arrêts par jour). La lumière suit l'heure (aube 5h-7h, crépuscule 19h-21h) et change pendant l'arrêt. **La nuit** (21h-5h) : monde sombre et bleuté, **lanterne** autour du joueur, train éclairé, plantes infectées qui luisent ; **les infectés voient plus loin et courent plus vite, les pilleurs somnolent** (ils voient moins loin) ; hordes 1,5 fois plus fréquentes. L'heure est dans le HUD (soleil ou lune), l'heure d'arrivée au trajet, à l'aiguillage et dans le train.
- **État du train** (0 à 100 %, il reste d'un arrêt à l'autre) : **abîmé** sous 60 % (serre et labo à l'arrêt), **critique** sous 25 % (arrêts écourtés de 20 %). À 0 % pendant une horde, le train démarre en catastrophe. **Réparer** : à la cabine (+25 % pour 3 ferrailles et 2 bois), par les **mécaniciens** de l'équipage (+10 % chacun par trajet, 2 au plus), ou à fond au **dépôt** des gares refuges (5 ferrailles).
- **Énergie de la locomotive** : la chaudière a une **réserve** (30 au départ, +6 par renfort de la locomotive) et chaque trajet en brûle **2 + 1 par voiture** (6 avec le train de départ : 4 trajets). On la charge à la **soute à charbon de la cabine** (onglet **Chaudière**) avec du **bois** (2 d'énergie) ou du **charbon** (6). Le charbon se ramasse en **tas** dans les zones industrielles (gare de triage, entrepôts, usine chimique, camp militaire…) et s'achète aux comptoirs des gares refuges. Le bois sert aussi à construire : brûler ou bâtir, à toi de voir.
- **Pannes** : si la réserve ne suffit pas, **panne sèche** ; à chaque trajet (dès l'arrêt n°3), une **panne moteur** peut aussi survenir : **4 %** sur un train neuf, jusqu'à **34 %** sur un train à 0 %, **−2 %** par mécanicien au travail. Dans les deux cas, le train s'arrête **en pleine voie** : un arrêt forcé, sans ordre ni compte à rebours, où **une horde arrive vite**. On ne monte pas à bord tant que la locomotive n'est pas remise en route : on lui rapporte (maintenir Agir à la locomotive) du **combustible** (panne sèche) ou **2 pièces mécaniques** (3 si le train est critique) ; ce qui manque dans le sac est pris dans le **stock du train**. Ensuite la pression remonte (20 s) ou les mécaniciens réparent (40 s, −8 s par mécanicien), le train **siffle** et repart **30 secondes** plus tard. La zone d'une panne a toujours de quoi s'en sortir (arbres et tas de charbon, ou épaves qui cachent plus souvent des pièces).
- **Points d'intérêt** dans les zones : **village abandonné** (maisons en ruine, caisses à fouiller), **refuge** avec un survivant à **recruter**, **marchand ambulant** pour **échanger**, et petites rencontres (sac abandonné, armoire à forcer).
- **Gare refuge** (arrêts n°5, 10, 15…) : une ville fortifiée sur la ligne, **zone sûre** sans infection ni chrono. **Comptoir** pour échanger le surplus du stock, **bureau de quarantaine** pour recruter des survivants sains, **dépôt** pour réparer le train et renforcer la locomotive. Chaque offre est une carte en cases, « ce que tu donnes → ce que tu reçois », avec son bouton (la phrase du marchand est en infobulle). On repart en remontant à bord.
- **Retour à bord** : le butin et les recrues rejoignent le train et on repart vers l'arrêt suivant.
- **Sac en cases, façon Minecraft** : chaque case contient une **pile de 5** d'une seule ressource ; mélanger les ressources remplit vite les cases. **Petit sac 4 cases, sac de randonnée 6, sac militaire 8** ; talents Glaneur +1 case, Intendant +2 (sans sac : 2 cases). Les cases s'affichent en bas au centre du HUD, avec « Sac plein » en rouge.
- **Inventaire** (I, ou le bouton Sac) : ton personnage et ses **5 cases d'équipement**, le **sac** (les cases grisées montrent ce qu'un sac plus grand ajouterait) et le **casier**. On touche une case : l'objet s'affiche en bas avec ce qu'on peut en faire. Pendant un arrêt : **Jeter 1** ou **Jeter la pile** (ce qu'on jette tombe en **tas** à ses pieds ; on le ramasse en maintenant Agir, dans la limite du sac). **Dans le train seulement** : toucher un objet du casier puis **Équiper** (il remplace celui qu'on porte, qui revient au casier). Le casier de l'atelier ouvre directement l'inventaire.
- **Menus du train en cases** : chaque onglet montre des **cases** (ressources, recettes, voitures, plans, équipiers) et, en haut, des **pastilles chiffrées** (voitures, couchettes, stock, état du train). On touche une case : elle s'explique dans la **barre du bas**, avec son coût en petites cases (nombre en rouge s'il en manque) et son bouton (Fabriquer, Construire, Agrandir, Réparer, Étudier, Prendre, Donner à…). Les détails sont en infobulle. Onglet **Machines** : ce que la serre et le laboratoire consomment → produisent, s'ils tournent, et les **5 derniers trajets** (produit, consommé, pourquoi une machine s'est arrêtée). Onglet **Plans** : une feuille de plan d'atelier, chaque plan montre ce qu'il débloque (coche : étudié, « ! » : à étudier, cadenas : à trouver).
- **Campagne continue et sauvegarde** : chaque gare refuge est un **point de reprise**. **Train raté** : on reprend à la dernière gare (ou au départ du train), tout ce qui s'est passé depuis est perdu. La session est aussi sauvegardée à chaque trajet (`user://saves/`), pour reprendre après avoir fermé le jeu.

**Médicaments et infirmerie** : antiseptique (−10 %) et antibiotiques (−20 %) se trouvent dans les caisses et les armoires, et s'achètent chez les marchands et en gare. Le **sérum de sève** (−35 %) et le **vaccin expérimental** (−60 %) se préparent à l'**infirmerie**, une voiture à construire, avec les plans Pharmacie et Vaccin. Dans l'onglet **Infirmerie** du menu du train, on choisit le **patient** (toi ou un équipier) puis le médicament : **Prendre** ou **Donner à…**. Les lits de quarantaine y sont aussi.

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

**Grades et ordres du capitaine** : à chaque arrêt (sauf en gare), le capitaine donne un **ordre** adapté à la zone : « Ramène 6 ferrailles », « Élimine 2 pilleurs », « Reviens avec moins de 25 % d'exposition »… Il est suivi en haut de l'écran. Ordre rempli et ennemis éliminés rapportent du **mérite**. Au fil du mérite, tu montes en grade : **Recrue → Soldat → Caporal → Sergent → Lieutenant → Capitaine**. À chaque promotion, tu choisis **un talent parmi deux** (+2 PV, sac +1 case, dégâts +1, se dégager plus vite, récolte plus rapide, armure…). Onglet **Grade** de l'inventaire : **barre de progression** vers le grade suivant, échelle des grades avec ce que chacun débloque, ordre en cours, talents.

**Responsabilités par grade** : tu commences recrue, et le capitaine (PNJ) décide de ce qui dépasse ton grade. Tu vois tout, mais c'est lui qui agit, et le trajet le raconte (« Le capitaine a choisi la voie… », « Le capitaine met Malik au repos »).

| Grade (mérite) | Ce que tu débloques | Avant, le capitaine… |
|---|---|---|
| Recrue (0) | Sorties, fabrication de ton équipement, étude des plans | — |
| Soldat (25) | Recruter les survivants rencontrés | … ne t'autorise pas à recruter |
| Caporal (70) | Choisir la voie à l'aiguillage | … prend la voie la plus sûre |
| Sergent (130) | Diriger l'équipage : panser, médicament, repos, quarantaine, renvoi | … met au repos les épuisés et isole les infectés |
| Lieutenant (210) | Construire et agrandir les voitures, dépôt de la gare | … construit un dortoir ou un stock quand il en manque |
| Capitaine (320) | **Envoyer un équipier en mission** à ta place | — |

**Missions d'équipage** (Capitaine) : au levier, « Envoyer un équipier » sur une voie. Il descend seul pendant que tu restes à bord : l'arrêt est simulé. Il rapporte une part de ce que la zone offre (plus s'il est éclaireur ou fidèle, moins s'il est blessé ou fatigué, 10 objets au plus), se blesse selon le danger, peut revenir infecté sans le savoir, se fatigue beaucoup et gagne un peu de confiance. S'il meurt, l'équipage perd confiance. Une horde sur cette voie abîme le train sans défenseur (−10 %). Le récit s'affiche au trajet suivant.

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
| Sac | Nombre de cases (piles de 5) : petit sac 4, randonnée 6, militaire 8 (« Sac plein ! ») |
| Outil | Récolte plus rapide d'un type d'objet (pied-de-biche, hachette, sécateur) |
| Arme | Dégâts, pour le futur combat |

Pendant un arrêt :

1. Le train s'arrête. Tu as **60 à 110 secondes** selon la zone avant le départ.
2. Tu récoltes en **maintenant Agir** près d'un objet : **ferraille** (épaves), **bois** (arbres morts), **plantes**, et **plantes infectées** dans les zones violettes.
3. Marcher sur le sol violet, cueillir une plante infectée ou prendre un coup d'infecté fait monter ton **infection**. Elle **reste d'un arrêt à l'autre** (ni le train ni les gares ne la font baisser) : seuls les **médicaments** la soignent. Paliers : **Fièvre** (30 %, −2 PV), **Contaminé** (60 %, −4 PV, plus lent), **Critique** (90 %, −6 PV, encore plus lent) ; à **100 %**, tu rejoins la ruche (reprise à la dernière gare).
4. **Combat** : des **infectés** rôdent dans les zones violettes, des **pilleurs** dans les zones saines. Frappe avec **Coup** (dégâts de l'arme portée). Tu as **10 points de vie**, rendus à chaque arrêt. Plaqué au sol par un rampant : **martèle Coup** pour te dégager.
5. À 15 secondes du départ, **le train siffle**. Remonte à bord en maintenant Agir devant la porte du wagon.
6. **Bilan** : le butin en cases (ressources, recrues, objets, plans), l'infection et ce que la sortie a coûté, le stock, l'ordre du capitaine, le grade avec sa barre. Si tu rates le train ou si tu tombes, tu reprends à la dernière gare refuge.

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
- Pour exporter en local : les modèles d'export Godot 4.7 (Éditeur → Gérer les modèles d'export) ; pour Android, en plus, Java 17 et le SDK Android (Éditeur → Paramètres de l'éditeur → Export → Android). Sinon, la CI fabrique les builds (voir *Builds et CI*).

## Lancer le jeu

Ouvrir `project.godot` dans Godot puis **F5**. Le jeu démarre sur l'écran titre (`levels/title/`) : **Continuer** ou **Nouvelle partie**. Ensuite : trajet (`levels/journey/`), intérieur du train (`levels/train_interior/`), puis arrêt (`levels/stop_zone/`) ou gare refuge (`levels/refuge/`) par le levier de la cabine. Pour aller directement à une scène, l'ouvrir et la lancer avec **F6**.

## Contrôles

| Action | Clavier | Manette | Tactile |
|---|---|---|---|
| Se déplacer | ZQSD en AZERTY (WASD en QWERTY) ou flèches | Stick gauche, croix directionnelle | Joystick : toucher la moitié gauche de l'écran |
| Agir (maintenir) : récolter, monter à bord | E | A (Xbox) / Croix (PlayStation) | Bouton « Agir » |
| Frapper | Espace ou clic gauche | X (Xbox) / Carré (PlayStation) | Bouton « Coup » |
| Inventaire | I ou Tab | Y (Xbox) / Triangle (PlayStation) | Bouton « Sac », en haut à droite |
| Pause, retour | Échap | Start (pause), B (retour) | Bouton « II », en haut à droite, ou bouton retour du téléphone |

**Android** : le bouton retour fait comme Échap (il ferme le menu ouvert, sinon il ouvre la pause) et ne quitte le jeu que depuis l'écran titre. Quand l'app passe en arrière-plan (appel, notification, bouton accueil), le jeu se met en pause et se sauvegarde s'il est dans le train ou en trajet : Android peut fermer une app en arrière-plan. Sur PC, quitter la fenêtre met aussi en pause. La version du jeu s'affiche sur l'écran titre et dans le menu pause.

Les touches sont définies par **position physique** : ZQSD fonctionne directement en AZERTY, sans réglage. Les consignes à l'écran s'adaptent au dernier périphérique utilisé (« Maintenir E », « Maintenir A » ou « Maintenir Agir »).

### Tester les contrôles tactiles sur PC

Ils n'apparaissent que si le dernier périphérique utilisé est le tactile. Pour les forcer sur PC (la souris simule alors le doigt), au choix :

- **Paramètres du projet** → cocher *Paramètres avancés* → `game/debug/force_touch_controls` = activé
- **Ligne de commande** : `godot --path . -- --touch`

Le forçage est ignoré dans un build release.

## Architecture

**Toutes les entrées convergent vers l'InputMap.** Clavier, manette et tactile déclenchent les mêmes actions (`move_*`, `attack`, `interact`). Le gameplay ne lit que ces actions.

**Les données sont dans des fichiers, pas dans le code.** Un type de ressource est un `LootData` (`data/loot/*.tres`) ; l'infection d'une tuile est une donnée du TileSet (`infection`, de 0 à 1) ; chaque objet récoltable est une scène réglable dans l'inspecteur.

**Le hasard est reproductible.** Chaque arrêt a une graine tirée par `GameState`. Le générateur est une fonction pure (profil + graine → plan), donc une zone qui pose problème peut être rejouée à l'identique. Pour figer le hasard : `game/debug/fixed_seed` dans les Paramètres du projet (0 = aléatoire), ou `seed_override` / `zone_override` sur la scène `stop_zone` pour tester une zone précise. Pour couper l'énergie et les pannes (déboguer le reste) : `game/debug/engine_trouble` à faux ; les tests le font pour toutes les suites sauf `test_engine.gd`. La panne moteur a son propre hasard : une panne ne change pas les arrêts tirés ensuite.

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
| `CrewMember` | `core/crew_member.gd` | Une recrue : prénom, rôle, infection cachée |
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
- **Police** : [Barlow](https://github.com/jpt/barlow) (SemiBold pour les textes, Bold pour les chiffres du HUD), une police lisse et lisible sur téléphone. Le jeu est rendu en mode `canvas_items` : le pixel art est agrandi par paliers entiers (net), le texte est dessiné à la vraie résolution de l'écran.
- **Icônes** : pixel art 12 px, générées par `tools/gen_icons.py`.
- **Interface** : plaques de fer, boutons, onglets et télégramme en pixel art, dessinés par `python tools/gen_ui.py`, puis assemblés en thème Godot par `godot --headless --path . --script tools/build_theme.gd` (écrit `ui/theme/game_theme.tres`).

## Tests

```
godot --headless --path . --script res://tests/run_tests.gd
```

Sous Windows, utiliser l'exécutable console : `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`.

Code de sortie 0 = tout est vert. Une erreur de script pendant un test le fait échouer. Pour ajouter une suite : créer `tests/test_xxx.gd` qui `extends TestCase`, puis l'ajouter à `SUITES` dans `tests/run_tests.gd`.

## Builds et CI

La CI GitHub Actions (`.github/workflows/ci.yml`) lance les tests à chaque push et pull request. Elle fabrique aussi les builds **Android (APK)**, **Windows** et **Linux** :

- **À la demande** : onglet *Actions* → *CI* → *Run workflow*. Les fichiers sont dans les artefacts du run (14 jours), avec un nom de version `<version>-dev.<n° du run>`.
- **À chaque tag** poussé (ex. `0.0.2-rc1`) : les fichiers sont ajoutés à la Release du tag. Si elle n'existe pas encore, elle est créée **en brouillon** (pré-version pour `rc`, `alpha`, `beta`) : tu la relis et la publies toi-même. Le tag `0.0.1-rc1` est antérieur à la CI : la CI ne peut pas le construire, elle prendra le suivant.

Le code de version Android est le n° du run : il ne fait que monter, donc chaque APK s'installe par-dessus le précédent. Le résumé du run donne la version, la signature utilisée et l'**empreinte du certificat**, qui doit rester la même d'une version à l'autre.

### Signer l'APK Android

Android n'installe que des APK signés, et une mise à jour doit être signée avec **la même clé** que l'app déjà installée. Crée ta clé une fois, sur ta machine (`keytool` est fourni avec Java). Mets le **même mot de passe** pour le keystore et la clé, Godot n'en gère qu'un :

```
keytool -genkeypair -v -keystore runaway-train.keystore -alias runawaytrain -keyalg RSA -keysize 2048 -validity 10000
```

Puis dans GitHub : *Settings* → *Secrets and variables* → *Actions* → *New repository secret* :

| Secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Le keystore encodé en base64. PowerShell : `[Convert]::ToBase64String([IO.File]::ReadAllBytes("runaway-train.keystore")) \| Set-Clipboard` ; Linux : `base64 -w0 runaway-train.keystore` |
| `ANDROID_KEYSTORE_ALIAS` | `runawaytrain` |
| `ANDROID_KEYSTORE_PASSWORD` | Le mot de passe |

Sans ces secrets, la CI signe avec une **clé temporaire** créée pour le run (avertissement dans le run) : l'APK s'installe, mais le suivant ne pourra pas le mettre à jour sans désinstaller (et perdre la sauvegarde).

- **Ne versionne jamais le keystore** (`*.keystore` et `*.jks` sont ignorés par git) et garde-en une copie avec son mot de passe, par exemple dans un gestionnaire de mots de passe. Perdu, plus aucune mise à jour ne s'installera par-dessus l'app.
- Le nom du paquet, `com.andrewshef.runawaytrain` (preset Android), est définitif une fois l'app installée ou publiée.
- Pour le Play Store plus tard : il faudra un AAB (build Gradle) au lieu d'un APK, avec la signature gérée par Google ; cette clé servira de clé d'envoi.

### Exporter en local

Les presets sont dans `export_presets.cfg` (versionné, sans secret : Godot range les mots de passe dans `.godot/export_credentials.cfg`, ignoré). Dans l'éditeur : *Projet* → *Exporter*. Pour signer en local, renseigne le keystore de release dans le preset Android, ou passe-le par les variables d'environnement `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` et `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.

## Conventions

- GDScript **typé** (le projet avertit sur les déclarations non typées), indentation par tabulations.
- Fichiers et dossiers en `snake_case`, un dossier par élément de jeu (script + scène ensemble).
- Commits en français, style *conventional commits* : `feat:`, `fix:`, `chore:`, `test:`, `docs:`.

## Licence

**Tous droits réservés.** Aucune utilisation, copie, modification ou distribution du contenu de ce dépôt n'est autorisée sans l'accord écrit de l'auteur. Voir [LICENSE](LICENSE).

Exception : la police Barlow (`assets/fonts/barlow/`) reste sous sa propre licence, la SIL Open Font License 1.1 (`OFL.txt`).
