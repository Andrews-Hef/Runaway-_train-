#!/usr/bin/env python3
"""Sol et marquise de la grande gare refuge (pixel art dessiné au pixel, comme les icônes).

- assets/tiles/ground_refuge.png : atlas 128x16, une tuile de 16 px par sorte de sol :
  pelouse A, pelouse B, pavés du quai, dalles de la place, voie, bord du quai (ligne
  blanche), allée de gravier, pelouse fleurie. Voir Refuge.Ground dans levels/refuge/refuge.gd.
- assets/sprites/props/canopy_roof.png : un module de 64 px du toit vitré de la marquise,
  translucide (on voit le joueur et le train dessous), armature de fonte et lambrequin.

Pas de violet (réservé à l'infection).

Usage, depuis la racine du repo : python3 tools/gen_refuge_ground.py
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILES = ROOT / "assets" / "tiles"
PROPS = ROOT / "assets" / "sprites" / "props"


def speckle(img, ox, base, dots, density, rng):
    for x in range(16):
        for y in range(16):
            color = rng.choice(dots) if rng.random() < density else base
            img.putpixel((ox + x, y), color + (255,))


def lawn(img, ox, rng, base=(78, 122, 58)):
    speckle(img, ox, base, [(92, 140, 66), (66, 106, 50), (100, 148, 72)], 0.3, rng)


def cobbles(img, ox, rng):
    """Pavés gris en quinconce, joints sombres."""
    joint = (70, 68, 66)
    for y in range(16):
        for x in range(16):
            row = y // 4
            shift = 2 if row % 2 else 0
            edge = y % 4 == 3 or (x + shift) % 4 == 3
            if edge:
                color = joint
            else:
                color = rng.choice([(128, 124, 118), (120, 116, 110), (136, 132, 124)])
                if y % 4 == 0 and (x + shift) % 4 == 0:
                    color = (150, 146, 138)  # arête éclairée
            img.putpixel((ox + x, y), color + (255,))


def flagstones(img, ox, rng):
    """Grandes dalles beiges de la place (8 px), joints fins."""
    joint = (118, 104, 84)
    tones = [(176, 160, 130), (168, 152, 122), (182, 166, 136), (172, 158, 128)]
    for by in (0, 8):
        for bx in (0, 8):
            tone = rng.choice(tones)
            for y in range(by, by + 8):
                for x in range(bx, bx + 8):
                    shift = 4 if by == 8 else 0
                    edge = y == by + 7 or (x + shift) % 8 == 7
                    color = joint if edge else tone
                    if not edge and rng.random() < 0.08:
                        color = (tone[0] - 10, tone[1] - 10, tone[2] - 10)
                    img.putpixel((ox + x, y), color + (255,))


def rails(img, ox, rng):
    ballast = [(92, 86, 78), (78, 72, 66), (104, 98, 88)]
    for x in range(16):
        for y in range(16):
            img.putpixel((ox + x, y), rng.choice(ballast) + (255,))
    for x in (1, 2, 9, 10):
        for y in range(2, 14):
            img.putpixel((ox + x, y), (74, 54, 38, 255))
    for y, color in ((4, (150, 154, 160)), (5, (88, 92, 98)), (10, (150, 154, 160)), (11, (88, 92, 98))):
        for x in range(16):
            img.putpixel((ox + x, y), color + (255,))


def platform_edge(img, ox, rng):
    """Bord du quai côté voie : bordure de pierre, ligne blanche, puis pavés."""
    cobbles(img, ox, rng)
    for x in range(16):
        img.putpixel((ox + x, 0), (96, 92, 86, 255))
        img.putpixel((ox + x, 1), (172, 166, 154, 255))
        img.putpixel((ox + x, 2), (150, 144, 134, 255))
        img.putpixel((ox + x, 4), (232, 228, 214, 255))
        img.putpixel((ox + x, 5), (232, 228, 214, 255))


def gravel(img, ox, rng):
    speckle(img, ox, (150, 132, 102), [(170, 152, 120), (128, 112, 86), (182, 166, 134)], 0.45, rng)


def flowers(img, ox, rng):
    lawn(img, ox, rng)
    for color in ((214, 74, 58), (240, 206, 74), (238, 232, 220), (214, 74, 58), (240, 206, 74)):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        img.putpixel((ox + x, y), color + (255,))
        img.putpixel((ox + x, y - 1), tuple(min(c + 20, 255) for c in color) + (255,))


def ground_atlas():
    rng = random.Random(11)
    img = Image.new("RGBA", (128, 16), (0, 0, 0, 255))
    lawn(img, 0, rng)
    lawn(img, 16, rng, base=(72, 114, 54))
    cobbles(img, 32, rng)
    flagstones(img, 48, rng)
    rails(img, 64, rng)
    platform_edge(img, 80, rng)
    gravel(img, 96, rng)
    flowers(img, 112, rng)
    return img


def canopy_roof():
    """Module de 64 x 48 px du toit vitré : verre translucide, chevrons de fonte tous les
    16 px, rive avant et lambrequin découpé (opaques)."""
    width, height = 64, 48
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glass = (168, 206, 222, 78)
    glint = (214, 236, 244, 120)
    iron = (43, 43, 51, 255)
    iron_light = (74, 76, 86, 255)
    fringe = (140, 44, 36, 255)
    for y in range(4, height - 8):
        for x in range(width):
            img.putpixel((x, y), glass)
    # Reflets en diagonale.
    for start in (6, 30, 46):
        for i in range(10):
            x, y = start + i, 8 + i * 2
            if 4 <= y < height - 8 and x < width:
                img.putpixel((x, y), glint)
    # Faîtage (arrière) et chevrons.
    for x in range(width):
        for y in (2, 3):
            img.putpixel((x, y), iron)
        img.putpixel((x, 4), iron_light)
    for cx in (0, 16, 32, 48):
        for y in range(2, height - 8):
            img.putpixel((cx, y), iron)
            if cx + 1 < width:
                img.putpixel((cx + 1, y), iron_light)
    for x in range(width):  # panne au milieu
        img.putpixel((x, 20), iron)
    # Rive avant (chéneau) et lambrequin rouge découpé en dents.
    for x in range(width):
        for y in range(height - 8, height - 5):
            img.putpixel((x, y), iron if y != height - 7 else iron_light)
        depth = 3 if (x % 8) in (2, 3, 4, 5) else (2 if (x % 8) in (1, 6) else 1)
        for y in range(height - 5, height - 5 + depth):
            img.putpixel((x, y), fringe)
    return img


def main() -> None:
    TILES.mkdir(parents=True, exist_ok=True)
    ground_atlas().save(TILES / "ground_refuge.png")
    PROPS.mkdir(parents=True, exist_ok=True)
    canopy_roof().save(PROPS / "canopy_roof.png")
    print("Sol et marquise de la gare refuge générés.")


if __name__ == "__main__":
    main()
