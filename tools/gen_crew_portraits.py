#!/usr/bin/env python3
"""Portraits 12 px des équipiers (tête et épaules), tirés de leur sprite td2d.

Source : la première image (idle, face) de assets/sprites/crew/crew_XX/crew-XX.png.
Sortie : assets/ui/portraits/crew_XX.png, affichés ×2 dans les cases des menus.
Usage, après tools/sync_td2d.py crew- :
    python3 tools/gen_crew_portraits.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites" / "crew"
OUT = ROOT / "assets" / "ui" / "portraits"
## Tête et épaules dans une image de 36 x 40 (personnage centré, pieds en bas).
CROP = (12, 7, 24, 19)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    count = 0
    for folder in sorted(SPRITES.glob("crew_*")):
        sheet = folder / (folder.name.replace("_", "-") + ".png")
        frame = Image.open(sheet).convert("RGBA").crop((0, 0, 36, 40))
        frame.crop(CROP).save(OUT / f"{folder.name}.png")
        count += 1
    print(f"{count} portraits dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
