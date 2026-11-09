# Runaway Train

Jeu en pixel art pour **Android et PC** : survie et gestion à bord d'un train qui traverse un monde ravagé par une peste qui transforme les gens en membres d'une ruche.

Tu es la nouvelle recrue. À chaque arrêt, tu as une à deux minutes pour fouiller la zone, remplir l'ordre du capitaine et remonter à bord avant le départ, sans trop t'exposer à l'infection. Entre deux arrêts, tu gères le train : stock, équipage, voitures, énergie de la locomotive. Au fil du mérite, tu montes en grade et prends les décisions du capitaine.

> Version de test : les graphismes sont provisoires. Les musiques et bruitages sont des sons libres (voir [Crédits](assets/audio/CREDITS.md)).

## Jouer

**Télécharger** : page [Releases](../../releases), dernière version. APK pour Android, zip pour Windows et Linux.

**Installer sur Android** (téléphone 64 bits) :

1. Télécharge l'APK sur le téléphone et ouvre-le.
2. Android demande d'autoriser l'installation pour l'app qui l'ouvre (Fichiers, Chrome, Discord…) : accepte.
3. Si Play Protect affiche « application inconnue » : **Installer quand même**.

Une nouvelle version s'installe par-dessus l'ancienne et garde la sauvegarde.

### Contrôles

| Action | Clavier | Manette | Tactile |
|---|---|---|---|
| Se déplacer | ZQSD en AZERTY (WASD en QWERTY) ou flèches | Stick gauche, croix directionnelle | Joystick : toucher la moitié gauche de l'écran |
| Agir (maintenir) : récolter, monter à bord | E | A (Xbox) / Croix (PlayStation) | Bouton « Agir » |
| Frapper | Espace ou clic gauche | X (Xbox) / Carré (PlayStation) | Bouton « Coup » |
| Inventaire | I ou Tab | Y (Xbox) / Triangle (PlayStation) | Bouton « Sac », en haut à droite |
| Pause, retour | Échap | Start (pause), B (retour) | Bouton « II », en haut à droite, ou bouton retour du téléphone |

- Les touches suivent leur **position physique** : ZQSD marche en AZERTY sans réglage. Les consignes à l'écran s'adaptent au dernier périphérique utilisé.
- **Android** : le bouton retour fait comme Échap et ne quitte le jeu que depuis l'écran titre. Quand l'app passe en arrière-plan, le jeu se met en pause et se sauvegarde.
- **Son** : volumes Musique et Effets sur l'écran titre et dans le menu pause, à côté des **Crédits**.

Tout ce qui est jouable, système par système : [docs/gameplay.md](docs/gameplay.md).

## Développer

**Prérequis** : [Godot 4.7 stable](https://godotengine.org/download). Pour exporter en local, les modèles d'export ; pour Android, en plus, Java 17 et le SDK Android. Sinon, la CI fabrique les builds.

**Lancer** : ouvrir `project.godot` dans Godot, puis **F5**. Pour une scène précise, l'ouvrir et **F6**.

**Tests** (code de sortie 0 = tout est vert) :

```
godot --headless --path . --script res://tests/run_tests.gd
```

Sous Windows : `Godot_v4.7-stable_win64_console.exe` à la place de `godot`.

**Builds** : la CI GitHub teste chaque push. Elle fabrique l'APK et les versions Windows et Linux à la demande (*Actions* → *CI* → *Run workflow*) ou à chaque tag poussé (`git tag 0.0.2-rc1` puis `git push origin 0.0.2-rc1` : Release créée en brouillon, à publier).

| Doc | Contenu |
|---|---|
| [docs/gameplay.md](docs/gameplay.md) | Ce qui est jouable : voyage, monde, arrêts, combat, train, équipage, progression |
| [docs/architecture.md](docs/architecture.md) | Principes, systèmes, ajouter du contenu (rencontre, objet, voiture, ennemi…), dossiers, débogage, conventions |
| [docs/graphismes-et-son.md](docs/graphismes-et-son.md) | Rendu, sprites, police, interface ; musiques, bruitages, playlists, `tools/build_audio.py` |
| [docs/builds.md](docs/builds.md) | Tests, CI, signature de l'APK (clé et secrets GitHub), export local |
| [art/README.md](art/README.md) | Sprites provisoires générés avec td2d |

## Licence

**Tous droits réservés.** Aucune utilisation, copie, modification ou distribution du contenu de ce dépôt n'est autorisée sans l'accord écrit de l'auteur. Voir [LICENSE](LICENSE).

Exceptions, sous leur propre licence :

- la police Barlow (`assets/fonts/barlow/`) : SIL Open Font License 1.1 (`OFL.txt`) ;
- les musiques et bruitages (`assets/audio/`) : œuvres d'autres auteurs, en CC0 ou CC-BY, listées avec leurs licences dans [assets/audio/CREDITS.md](assets/audio/CREDITS.md).
