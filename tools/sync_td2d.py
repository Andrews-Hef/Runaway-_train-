"""Copie les sprites générés par td2d (art/build/) vers le projet Godot (assets/sprites/).

Usage, depuis la racine du repo, après `td2d batch` dans art/ :
    python tools/sync_td2d.py

- Objets à une direction (props, train) : la première image de idle/s → assets/sprites/<groupe>/<nom>.png
- Personnages animés : la planche + le SpriteFrames Godot (.tres) → assets/sprites/<nom>/
Affiche le pivot (pieds / base) de chaque sprite : dans Godot, centered = false et
offset = -pivot, pour que la position du nœud soit au sol.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "art" / "build"
SPRITES = ROOT / "assets" / "sprites"


def main() -> None:
    for manifest_path in sorted(BUILD.glob("*/*/sheets/manifest.json")):
        manifest = json.loads(manifest_path.read_text())
        group, name = manifest["assetId"].split("/")
        pivot = manifest["pivot"]
        sheets_dir = manifest_path.parent
        animated = any(clip["frames"] > 1 for clip in manifest["clips"]) or len(manifest["directions"]) > 1

        if animated:
            dest = SPRITES / name
            dest.mkdir(parents=True, exist_ok=True)
            for sheet in manifest["files"]["sheets"]:
                shutil.copy(sheets_dir / sheet, dest / sheet)
            for tres in manifest["files"].get("godot-spriteframes", []):
                shutil.copy(sheets_dir / tres, dest / tres)
            target = dest
        else:
            dest = SPRITES / group
            dest.mkdir(parents=True, exist_ok=True)
            frame = manifest_path.parent.parent / "sprites" / "idle" / "s" / "000.png"
            target = dest / f"{name.replace('-', '_')}.png"
            shutil.copy(frame, target)

        print(f"{manifest['assetId']:<24} -> {target.relative_to(ROOT)}  pivot=({pivot['x']}, {pivot['y']})")


if __name__ == "__main__":
    main()
