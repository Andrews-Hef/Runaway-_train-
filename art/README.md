# Sprites du jeu (td2d)

Les sprites de personnages, d'objets et du train sont **modélisés en 3D puis rendus en pixel art** par [td2d](https://github.com/brphillis/threedee-twodee) (outil MIT). Ce dossier ne contient que les définitions JSON : les images générées vont dans `build/` (non versionné), puis sont copiées dans le projet Godot par `tools/sync_td2d.py`.

Ce sont des **assets temporaires**, cohérents entre eux (même caméra, même lumière, même échelle) en attendant les vrais.

## Réglages du projet (`td2d.project.json`)

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Caméra | `three-quarter` | Vue de dessus 3/4 classique de RPG, comme le jeu |
| Échelle | `pixelsPerUnit: 16` | 1 m = 16 px = une tuile du sol |
| Pixel | `outlined` | Contour sombre d'1 px, lisible sur l'herbe comme sur le violet |
| Lumière | `studio-toon` | Ombrage en aplats, peu de couleurs |
| Matériaux | `defaults.materials` | Couleurs partagées (rouille, olive, bois mort…) |

**Le violet (`infected-glow`, `infected-leaf`) est réservé à l'infection.** Le joueur porte une veste ocre pour rester visible sur l'herbe et sur le violet.

## Assets

| Id | Directions | Animations | Utilisé par |
|---|---|---|---|
| `characters/survivor` | 4 (s, e, n, w) | `idle`, `walk` | Le joueur (`SpriteFrames` Godot) |
| `props/wreck` | 1 | — | Épave (ferraille) |
| `props/dead-tree` | 1 | — | Arbre mort (bois) |
| `props/herb` | 1 | — | Plante (plantes) |
| `props/infected-herb` | 1 | — | Plante infectée |
| `props/rock` | 1 | — | Rocher (obstacle) |
| `train/locomotive`, `train/wagon` | 1 | — | Le train à quai |

## Générer et mettre à jour les sprites

Prérequis : Node.js 24+, et td2d cloné et compilé une fois (`pnpm install && pnpm build`, voir son README).

```sh
td2d() { node /chemin/vers/threedee-twodee/packages/cli/dist/main.js "$@"; }

cd art
td2d validate --json                 # vérifie les définitions
td2d batch --json                    # génère tout dans build/
td2d preview props/wreck --json      # aperçu agrandi d'un asset
cd ..
python tools/sync_td2d.py            # copie vers assets/sprites/ et affiche les pivots
```

Le script affiche le **pivot** de chaque sprite (le point au sol). Dans Godot, le sprite est réglé avec `centered = false` et `offset = -pivot` : la position du nœud est ainsi ses pieds ou sa base, ce qui fait marcher le tri en profondeur (y-sort).

## Règles des fichiers td2d

- Identifiants en `kebab-case` (assets, pièces, matériaux) : `dead-tree`, pas `dead_tree`.
- JSON strict : pas de commentaires, les notes vont dans `description`.
- Mètres, Y vers le haut, degrés. Une boîte de 1 m posée au sol est à `y = 0.5`.
