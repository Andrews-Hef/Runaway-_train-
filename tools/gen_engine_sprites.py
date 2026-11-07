#!/usr/bin/env python3
"""Sprites de l'énergie du train, dessinés au pixel (en attendant les vrais assets).

- assets/sprites/props/coal_pile.png : tas de charbon à ramasser dans les zones.
- assets/sprites/interior/coal_bin.png : soute à charbon de la cabine (charger la chaudière).

Même contour (#1a1c2c) et même ombrage en aplats que les sprites td2d.
Usage : python3 tools/gen_engine_sprites.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUTLINE = (0x1A, 0x1C, 0x2C, 255)


def rgb(hex_color: str) -> tuple[int, int, int, int]:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def from_map(rows: list[str], palette: dict[str, str]) -> Image.Image:
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == len(rows[0]), f"ligne {y} : {len(row)} au lieu de {len(rows[0])}"
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), rgb(palette[ch]))
    return img


def outline(img: Image.Image) -> Image.Image:
    """Contour d'1 px autour des pixels opaques (4 voisins)."""
    out = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] > 0:
                    out.putpixel((x, y), OUTLINE)
                    break
    return out


COAL = {"k": "#2e3038", "m": "#454955", "h": "#6c7488", "w": "#a3adc2"}


def coal_pile() -> Image.Image:
    return outline(from_map([
        "................................",
        "................................",
        "...............mm...............",
        ".............mmhmmm.............",
        "...........mmhhmmmkkm...........",
        "..........mmhwhmmkmmkk..........",
        "........mmmhhmmkkmhmkkkk........",
        ".......mmhmmmkkmmhwhmkkkk.......",
        "......mmhwhmkkmmmhhmmkkkkk......",
        ".....mmmhhmmkkmmkkmmkkmhmkk.....",
        "....kmmmmmkkkmmkkkkkkmhwhkkk....",
        "...kkmmmkkkkmmkkmmkkkkhhkkkkk...",
        "..kkkkkkkkkkkkkkmhmkkkkkkkkkkk..",
        "..kkkkmkkkkkkkkkkkkkkkkmkkkkkk..",
        "...kkkkkkkkkkkkkkkkkkkkkkkkkk...",
        ".mh...kkkkkkkkkkkkkkkkkkkk...hm.",
        ".kk.............................",
        "................................",
    ], COAL))


def coal_bin() -> Image.Image:
    palette = dict(COAL)
    palette.update({"a": "#4a3a2c", "b": "#7c583d", "c": "#967c5f", "d": "#5e4430", "e": "#a8936c"})
    return outline(from_map([
        "..........................",
        "..........................",
        "........mmmhmm............",
        "......mmhhwhmmmkm.........",
        "....mmmhhhmmkkmhmkk.......",
        "..ammmmmmkkkkmhwhmkkka....",
        "..akkkkkkkkkkkkhhkkkkka...",
        "..eeeeeeeeeeeeeeeeeeeee...",
        "..cbbbbbbbbbbbbbbbbbbbc...",
        "..cbbbbbbbbbbbbbbbbbbbc...",
        "..cdddddddddddddddddddc...",
        "..cbbbbbbbbbbbbbbbbbbbc...",
        "..cbbbbbbbbbbbbbbbbbbbc...",
        "..cdddddddddddddddddddc...",
        "..cbbbbbbbbbbbbbbbbbbbc...",
        "..cbbbbbbbbbbbbbbbbbbbc...",
        "..aaaaaaaaaaaaaaaaaaaaa...",
        "..........................",
    ], palette))


def main() -> None:
    targets = {
        "assets/sprites/props/coal_pile.png": coal_pile(),
        "assets/sprites/interior/coal_bin.png": coal_bin(),
    }
    for path, img in targets.items():
        (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
        img.save(ROOT / path)
        print(path, img.size)


if __name__ == "__main__":
    main()
