# Tests, builds et CI

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

## Signer l'APK Android

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

## Exporter en local

Les presets sont dans `export_presets.cfg` (versionné, sans secret : Godot range les mots de passe dans `.godot/export_credentials.cfg`, ignoré). Dans l'éditeur : *Projet* → *Exporter*. Pour signer en local, renseigne le keystore de release dans le preset Android, ou passe-le par les variables d'environnement `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` et `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
