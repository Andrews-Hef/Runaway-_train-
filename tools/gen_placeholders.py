"""Génère les tuiles de sol temporaires (programmer art) du projet.

Les sprites (personnages, objets, train) viennent de td2d : voir art/ et tools/sync_td2d.py.

Usage : python tools/gen_placeholders.py   (depuis la racine du repo, Pillow requis)

Ces tuiles servent seulement à rendre le jeu jouable en attendant les vrais assets. Le dossier tools/ contient un .gdignore : Godot ne l'importe pas.
La couleur violette est RÉSERVÉE à l'infection (voir la note Direction artistique).
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent



def ground_atlas() -> Image.Image:
    """Atlas 80x16 : herbe A, herbe B, terre, sol infecté (violet réservé), rails."""
    rng = random.Random(7)
    tiles = [
        ((62, 91, 47), [(74, 107, 55), (52, 80, 42)], 0.18),
        ((69, 101, 53), [(84, 118, 62), (58, 88, 45)], 0.22),
        ((93, 74, 55), [(107, 86, 64), (78, 62, 46)], 0.20),
        ((46, 31, 58), [(122, 63, 176), (192, 107, 255)], 0.12),
    ]
    img = Image.new("RGBA", (80, 16), (0, 0, 0, 255))
    for i, (base, dots, density) in enumerate(tiles):
        for x in range(16):
            for y in range(16):
                color = base
                if rng.random() < density:
                    color = rng.choice(dots)
                img.putpixel((i * 16 + x, y), color + (255,))
    _rails(img, 64, rng)
    return img


def _rails(img: Image.Image, ox: int, rng: random.Random) -> None:
    """Tuile 16x16 de voie ferrée horizontale : ballast, traverses, deux rails."""
    ballast = [(92, 86, 78), (78, 72, 66), (104, 98, 88)]
    for x in range(16):
        for y in range(16):
            img.putpixel((ox + x, y), rng.choice(ballast) + (255,))
    for x in (1, 2, 9, 10):  # traverses en bois
        for y in range(2, 14):
            img.putpixel((ox + x, y), (74, 54, 38, 255))
    for y, color in ((4, (150, 154, 160)), (5, (88, 92, 98)), (10, (150, 154, 160)), (11, (88, 92, 98))):
        for x in range(16):
            img.putpixel((ox + x, y), color + (255,))


def main() -> None:
    tiles = ROOT / "assets" / "tiles"
    tiles.mkdir(parents=True, exist_ok=True)
    ground_atlas().save(tiles / "ground_placeholder.png")
    print("Placeholders générés.")


if __name__ == "__main__":
    main()
