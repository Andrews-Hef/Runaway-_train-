# Ce qui est jouable

Ce document décrit le jeu tel qu'il est dans le code aujourd'hui. Le design (vision, idées, décisions) est tenu dans le vault Obsidian, dossier `Jeu du train/`.

**La boucle** : trajet → intérieur du train → aiguillage → arrêt (ou gare refuge) → bilan → trajet suivant.

- [Le voyage](#le-voyage)
- [Le monde](#le-monde)
- [Pendant un arrêt](#pendant-un-arrêt)
- [Combat et ennemis](#combat-et-ennemis)
- [Le train](#le-train)
- [L'équipage](#léquipage)
- [Progression](#progression)
- [Gares refuges et sauvegarde](#gares-refuges-et-sauvegarde)
- [Plateformes](#plateformes)

## Le voyage

- **Intro** : une nouvelle partie commence par le contexte, en quelques pages par-dessus le premier trajet (la peste et la ruche, les gares fortifiées, le train qui ne s'arrête jamais longtemps, toi la recrue), puis le premier ordre du capitaine. Un appui affiche la page en entier, le suivant passe à la suite ; Échap, le bouton retour ou « Passer » sautent tout. Une partie reprise ne la rejoue pas. Le texte est dans `ui/intro/intro_overlay.gd`.
- **Trajet** : le train roule, le décor défile. On voit le stock du train et le prochain arrêt.
- **Dans le train** (vue de dessus, toit retiré) : tu marches de wagon en wagon par les passerelles. **Coffre** du stock, **établi** de l'atelier (fabriquer de l'équipement), **casier** (ouvre l'inventaire pour s'équiper), **couchettes** du dortoir (l'équipage), **table du capitaine** (construire des voitures, renforcer la locomotive) et le **levier** de la cabine pour descendre au prochain arrêt. La voie défile sous le train : on la voit entre les wagons, aux deux bouts et au bas de l'écran.
- **Aiguillage** : avant chaque arrêt (sauf le premier et les gares), le levier de la cabine propose **2 voies**. Chacune montre son type d'arrêt, sa **spécialité** (ce qu'on y trouve), son danger et l'ordre du capitaine. Chaque région a 3 types d'arrêt (ex. en ville : Boulevard, Quartier résidentiel, Hôpital abandonné).
- **Arrêt** : chaque zone est **générée au hasard** à partir de son type d'arrêt. Le premier arrêt est toujours une plaine.
- **Retour à bord** : le butin et les recrues rejoignent le train et on repart vers l'arrêt suivant.

## Le monde

- **Régions** : la ligne traverse 5 biomes, un par tronçon entre deux gares refuges : **Campagne** (arrêts 1 à 5) → **Marais infecté** → **Ville en ruine** → **Zone industrielle** → **Toundra gelée**, puis la ligne repart. Chaque biome a son sol, ses décors, son ambiance et **une règle** :
  - Marais : l'eau stagnante **ralentit**.
  - Toundra : le **froid** fait perdre 1 PV toutes les 15 s sans tenue chaude (veste rembourrée), et la **glace** fait glisser.
  - Ville : fouiller une voiture peut déclencher une **alarme** qui attire les ennemis.
  - Zone industrielle : les **flaques toxiques** brûlent, sauf avec la combinaison étanche.
- **Jour et nuit** : la partie commence le jour 1 à 6h. En zone, 1 seconde = 1 minute de jeu ; un trajet dure 3 h, une gare refuge 1 h (environ 5 arrêts par jour). La lumière suit l'heure (aube 5h-7h, crépuscule 19h-21h) et change pendant l'arrêt. **La nuit** (21h-5h) : monde sombre et bleuté, **lanterne** autour du joueur, train éclairé, plantes infectées qui luisent ; **les infectés voient plus loin et courent plus vite, les pilleurs somnolent** (ils voient moins loin) ; hordes 1,5 fois plus fréquentes. L'heure est dans le HUD (soleil ou lune), l'heure d'arrivée au trajet, à l'aiguillage et dans le train.
- **Pluie infectée** (événement) : prévue sur la carte de sa voie à l'aiguillage (« Météo : pluie infectée annoncée »), surtout au marais, jamais en toundra ni avant l'arrêt n°3. En zone : le ciel se couvre, alerte 8 s avant, puis 30 à 45 s de pluie violette. **À découvert, l'infection monte** (moins avec masque et tenue) ; contre une maison, un immeuble, un abri, la charrette, un conteneur ou le train, on est **à l'abri**. La pluie fait sortir des infectés et **pousser des plantes infectées**.
- **Horde** (surprise, jamais annoncée) : à partir de l'arrêt n°4, surtout en ville. Quelques secondes après l'arrivée, un groupe d'infectés sort du bas de la carte et **fonce sur le train** pour le frapper ; s'il te voit, il te poursuit, puis retourne au train. Plus grosse au fil des arrêts. Toute la horde éliminée : **+15 mérite**.
- **Points d'intérêt** dans les zones : **village abandonné** (maisons en ruine, caisses à fouiller), **refuge** avec un survivant à **recruter**, **marchand ambulant** pour **échanger**, et petites rencontres (sac abandonné, armoire à forcer).

## Pendant un arrêt

1. Le train s'arrête. Tu as **60 à 110 secondes** selon la zone avant le départ.
2. Tu récoltes en **maintenant Agir** près d'un objet : **ferraille** (épaves), **bois** (arbres morts), **plantes**, et **plantes infectées** dans les zones violettes.
3. Marcher sur le sol violet, cueillir une plante infectée ou prendre un coup d'infecté fait monter ton **infection**. Elle **reste d'un arrêt à l'autre** (ni le train ni les gares ne la font baisser) : seuls les **médicaments** la soignent. Paliers : **Fièvre** (30 %, −2 PV), **Contaminé** (60 %, −4 PV, plus lent), **Critique** (90 %, −6 PV, encore plus lent) ; à **100 %**, tu rejoins la ruche (reprise à la dernière gare).
4. **Combat** : des **infectés** rôdent dans les zones violettes, des **pilleurs** dans les zones saines. Frappe avec **Coup** (dégâts de l'arme portée). Tu as **10 points de vie**, rendus à chaque arrêt. Plaqué au sol par un rampant : **martèle Coup** pour te dégager.
5. À 15 secondes du départ, **le train siffle**. Remonte à bord en maintenant Agir devant la porte du wagon.
6. **Bilan** : le butin en cases (ressources, recrues, objets, plans), l'infection et ce que la sortie a coûté, le stock, l'ordre du capitaine, le grade avec sa barre. Si tu rates le train ou si tu tombes, tu reprends à la dernière gare refuge.

- **Sac en cases, façon Minecraft** : chaque case contient une **pile de 5** d'une seule ressource ; mélanger les ressources remplit vite les cases. **Petit sac 4 cases, sac de randonnée 6, sac militaire 8** ; talents Glaneur +1 case, Intendant +2 (sans sac : 2 cases). Les cases s'affichent en bas au centre du HUD, avec « Sac plein » en rouge.
- **Inventaire** (I, ou le bouton Sac) : ton personnage et ses **5 cases d'équipement**, le **sac** (les cases grisées montrent ce qu'un sac plus grand ajouterait) et le **casier**. On touche une case : l'objet s'affiche en bas avec ce qu'on peut en faire. Pendant un arrêt : **Jeter 1** ou **Jeter la pile** (ce qu'on jette tombe en **tas** à ses pieds ; on le ramasse en maintenant Agir, dans la limite du sac). **Dans le train seulement** : toucher un objet du casier puis **Équiper** (il remplace celui qu'on porte, qui revient au casier). Le casier de l'atelier ouvre directement l'inventaire.

**Équipement** : tenue, masque, sac, outil, arme. Il se fabrique à l'atelier avec les matériaux du stock, ou se trouve et s'achète en sortie.

| Emplacement | Effet |
|---|---|
| Tenue, masque | **Protection** : l'exposition monte moins vite (plafonnée à 80 %). **Armure** : dégâts en moins par coup (il en reste toujours 1) — gilet en kevlar (armure 2, acheté au ferrailleur), plastron en tôle (armure 1, fabriqué). Tenue anti-infection ou anti-coups : à choisir selon la zone. |
| Sac | Nombre de cases (piles de 5) : petit sac 4, randonnée 6, militaire 8 (« Sac plein ! ») |
| Outil | Récolte plus rapide d'un type d'objet (pied-de-biche, hachette, sécateur) |
| Arme | Dégâts, pour le futur combat |

## Combat et ennemis

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

## Le train

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

- **État du train** (0 à 100 %, il reste d'un arrêt à l'autre) : **abîmé** sous 60 % (serre et labo à l'arrêt), **critique** sous 25 % (arrêts écourtés de 20 %). À 0 % pendant une horde, le train démarre en catastrophe. **Réparer** : à la cabine (+25 % pour 3 ferrailles et 2 bois), par les **mécaniciens** de l'équipage (+10 % chacun par trajet, 2 au plus), ou à fond au **dépôt** des gares refuges (5 ferrailles).
- **Énergie de la locomotive** : la chaudière a une **réserve** (30 au départ, +6 par renfort de la locomotive) et chaque trajet en brûle **2 + 1 par voiture** (6 avec le train de départ : 4 trajets). On la charge à la **soute à charbon de la cabine** (onglet **Chaudière**) avec du **bois** (2 d'énergie) ou du **charbon** (6). Le charbon se ramasse en **tas** dans les zones industrielles (gare de triage, entrepôts, usine chimique, camp militaire…) et s'achète aux comptoirs des gares refuges. Le bois sert aussi à construire : brûler ou bâtir, à toi de voir.
- **Pannes** : si la réserve ne suffit pas, **panne sèche** ; à chaque trajet (dès l'arrêt n°3), une **panne moteur** peut aussi survenir : **4 %** sur un train neuf, jusqu'à **34 %** sur un train à 0 %, **−2 %** par mécanicien au travail. Dans les deux cas, le train s'arrête **en pleine voie** : un arrêt forcé, sans ordre ni compte à rebours, où **une horde arrive vite**. On ne monte pas à bord tant que la locomotive n'est pas remise en route : on lui rapporte (maintenir Agir à la locomotive) du **combustible** (panne sèche) ou **2 pièces mécaniques** (3 si le train est critique) ; ce qui manque dans le sac est pris dans le **stock du train**. Ensuite la pression remonte (20 s) ou les mécaniciens réparent (40 s, −8 s par mécanicien), le train **siffle** et repart **30 secondes** plus tard. La zone d'une panne a toujours de quoi s'en sortir (arbres et tas de charbon, ou épaves qui cachent plus souvent des pièces).
- **Menus du train en cases** : chaque onglet montre des **cases** (ressources, recettes, voitures, plans, équipiers) et, en haut, des **pastilles chiffrées** (voitures, couchettes, stock, état du train). On touche une case : elle s'explique dans la **barre du bas**, avec son coût en petites cases (nombre en rouge s'il en manque) et son bouton (Fabriquer, Construire, Agrandir, Réparer, Étudier, Prendre, Donner à…). Les détails sont en infobulle. Onglet **Machines** : ce que la serre et le laboratoire consomment → produisent, s'ils tournent, et les **5 derniers trajets** (produit, consommé, pourquoi une machine s'est arrêtée). Onglet **Plans** : une feuille de plan d'atelier, chaque plan montre ce qu'il débloque (coche : étudié, « ! » : à étudier, cadenas : à trouver).

## L'équipage

- **Qui sont tes équipiers** : chaque recrue a un **prénom et un nom** (40 prénoms, 32 noms, jamais deux fois le même prénom à bord), une des **20 apparences** (sprite et portrait, pas deux fois la même à bord tant qu'il en reste), **4 stats** de 1 à 5 tirées à son arrivée (la plupart entre 2 et 4, +1 dans celle de son métier) et un **équipement de départ** au hasard (tenue, arme, parfois masque, outil ou sac), du courant au début de la ligne, du rare plus loin (`ItemData.tier`, une rareté de plus tous les 6 arrêts). **Force** : moins de blessures au combat. **Endurance** : se fatigue moins, résiste mieux à l'infection. **Adresse** : rapporte plus en mission, un mécanicien adroit répare mieux (±15 % par point). **Sang-froid** : décroche à temps quand ça tourne mal (il ne perd jamais plus de 100 − 10 × sang-froid PV en une mission, mais rapporte moins).
- **Équiper l'équipage** : à bord, l'inventaire montre en haut **ton portrait et ceux de l'équipage** ; on touche un équipier, puis un objet du casier, « **Donner à…** » (ce qu'il portait revient au casier) ; sur ce qu'il porte, « **Reprendre** ». Raccourci : « Équiper » dans l'onglet Équipage. En mission, ça compte : arme, armure et force réduisent les blessures, outil et adresse font rapporter plus, un sac plus de place, masque et endurance limitent l'infection. Renvoyé ou mort à bord, il rend son équipement ; parti de lui-même, passé à la ruche ou tombé en mission, il est perdu. Un objet repris en double (ta barre de fer et la sienne) compte pour deux au casier.
- **Équipage vivant** : chaque équipier a 4 jauges, **vie, infection, fatigue, confiance**. Pendant les trajets, chacun travaille selon son rôle : le **mécanicien** répare le train, le **soigneur** soigne le plus blessé et repère les infectés, l'**éclaireur** repère les hordes (« horde repérée » sur la carte de la voie, à l'aiguillage). Travailler fatigue ; épuisé, on ne travaille plus. L'**infection** est cachée au début (« ? »), se voit aux symptômes vers 40 % ou tout de suite avec un soigneur, monte à chaque trajet, contamine les autres ; à 100 %, l'équipier **rejoint la ruche** (une voiture saccagée). La vie baisse avec la maladie, l'épuisement et les attaques de horde sur le train ; à 0, il meurt. **Confiance** : elle monte quand il va bien et quand tu remplis ses **demandes** (« trouve-moi 2 pièces mécaniques », « élimine 2 pilleurs », « rapporte 3 plantes infectées » : +20), baisse avec l'épuisement, les pertes et les demandes ignorées. Fidèle (≥ 70), il travaille mieux ; méfiant (< 25), il peut quitter le train en gare refuge. Onglet **Équipage** : les portraits, la fiche de l'équipier choisi (jauges, stats, équipement), sa demande, et **équiper**, **panser** (1 tissu), **médicament**, **repos**, **quarantaine** (infirmerie), **renvoyer**. Le trajet raconte ce qui s'est passé.
- **Équipier de sortie** (à partir de **Caporal**) : dans l'onglet Équipage, « **Emmener en sortie** » sur un équipier (son nom passe en doré, « Sortie : Adam » en haut de l'onglet, et le levier dit « avec Adam »). À chaque arrêt, il descend avec toi et **part fouiller de son côté : on ne le voit pas**. Quand tu remontes à bord, il te rejoint avec **sa part du butin**, rangée au stock après la tienne et montrée dans le bilan (« Adam rapporte » + cases). Sa part : la moitié d'une mission, au prorata du temps que tu es resté dehors, plafonnée par **son sac** (10 objets sans sac : lui en donner un change tout) ; ses stats et son équipement comptent comme en mission. Il prend deux fois moins de coups qu'en mission (tu attires les ennemis), se fatigue (20), et peut ne pas revenir s'il sort déjà très blessé. Épuisé, blessé grave, au repos ou isolé, il reste à bord (on te le dit en arrivant). Pas de sortie en gare refuge.

**Missions d'équipage** (Capitaine) : au levier, « Envoyer un équipier » sur une voie. Il descend seul pendant que tu restes à bord : l'arrêt est simulé. Il rapporte une part de ce que la zone offre (plus s'il est éclaireur ou fidèle, moins s'il est blessé ou fatigué, 10 objets au plus), se blesse selon le danger, peut revenir infecté sans le savoir, se fatigue beaucoup et gagne un peu de confiance. S'il meurt, l'équipage perd confiance. Une horde sur cette voie abîme le train sans défenseur (−10 %). Le récit s'affiche au trajet suivant.

## Progression

**Grades et ordres du capitaine** : à chaque arrêt (sauf en gare), le capitaine donne un **ordre** adapté à la zone : « Ramène 6 ferrailles », « Élimine 2 pilleurs », « Reviens avec moins de 25 % d'exposition »… Il est suivi en haut de l'écran. Ordre rempli et ennemis éliminés rapportent du **mérite**. Au fil du mérite, tu montes en grade : **Recrue → Soldat → Caporal → Sergent → Lieutenant → Capitaine**. À chaque promotion, tu choisis **un talent parmi deux** (+2 PV, sac +1 case, dégâts +1, se dégager plus vite, récolte plus rapide, armure…). Onglet **Grade** de l'inventaire : **barre de progression** vers le grade suivant, échelle des grades avec ce que chacun débloque, ordre en cours, talents.

**Responsabilités par grade** : tu commences recrue, et le capitaine (PNJ) décide de ce qui dépasse ton grade. Tu vois tout, mais c'est lui qui agit, et le trajet le raconte (« Le capitaine a choisi la voie… », « Le capitaine met Malik au repos »).

| Grade (mérite) | Ce que tu débloques | Avant, le capitaine… |
|---|---|---|
| Recrue (0) | Sorties, fabrication de ton équipement, étude des plans | — |
| Soldat (25) | Recruter les survivants rencontrés | … ne t'autorise pas à recruter |
| Caporal (70) | Choisir la voie à l'aiguillage, emmener un équipier en sortie | … prend la voie la plus sûre ; tu sors seul |
| Sergent (130) | Diriger l'équipage : panser, médicament, repos, quarantaine, renvoi | … met au repos les épuisés et isole les infectés |
| Lieutenant (210) | Construire et agrandir les voitures, dépôt de la gare | … construit un dortoir ou un stock quand il en manque |
| Capitaine (320) | **Envoyer un équipier en mission** à ta place | — |

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

**Médicaments et infirmerie** : antiseptique (−10 %) et antibiotiques (−20 %) se trouvent dans les caisses et les armoires, et s'achètent chez les marchands et en gare. Le **sérum de sève** (−35 %) et le **vaccin expérimental** (−60 %) se préparent à l'**infirmerie**, une voiture à construire, avec les plans Pharmacie et Vaccin. Dans l'onglet **Infirmerie** du menu du train, on choisit le **patient** (toi ou un équipier) puis le médicament : **Prendre** ou **Donner à…**. Les lits de quarantaine y sont aussi.

## Gares refuges et sauvegarde

- **Gare refuge** (arrêts n°5, 10, 15…) : une ville fortifiée sur la ligne, **zone sûre** sans infection ni chrono. **Comptoir** pour échanger le surplus du stock, **bureau de quarantaine** pour recruter des survivants sains, **dépôt** pour réparer le train et renforcer la locomotive. Chaque offre est une carte en cases, « ce que tu donnes → ce que tu reçois », avec son bouton (la phrase du marchand est en infobulle). On repart en remontant à bord.
- **Campagne continue et sauvegarde** : chaque gare refuge est un **point de reprise**. **Train raté** : on reprend à la dernière gare (ou au départ du train), tout ce qui s'est passé depuis est perdu. La session est aussi sauvegardée à chaque trajet (`user://saves/`), pour reprendre après avoir fermé le jeu.

## Plateformes

Les contrôles sont dans le [README](../README.md#contrôles).

**Android** : le bouton retour fait comme Échap (il ferme le menu ouvert, sinon il ouvre la pause) et ne quitte le jeu que depuis l'écran titre. Quand l'app passe en arrière-plan (appel, notification, bouton accueil), le jeu se met en pause et se sauvegarde s'il est dans le train ou en trajet : Android peut fermer une app en arrière-plan. Sur PC, quitter la fenêtre met aussi en pause. La version du jeu s'affiche sur l'écran titre et dans le menu pause.

Les touches sont définies par **position physique** : ZQSD fonctionne directement en AZERTY, sans réglage. Les consignes à l'écran s'adaptent au dernier périphérique utilisé (« Maintenir E », « Maintenir A » ou « Maintenir Agir »).
