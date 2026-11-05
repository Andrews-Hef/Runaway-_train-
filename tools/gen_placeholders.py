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



# Sols de chaque biome : (base, [taches], densité) pour le sol A, le sol B et le sol
# secondaire. Le sol infecté (violet, réservé à l'infection) et les rails sont communs.
BIOME_GROUNDS = {
    "countryside": [
        ((62, 91, 47), [(74, 107, 55), (52, 80, 42)], 0.18),
        ((69, 101, 53), [(84, 118, 62), (58, 88, 45)], 0.22),
        ((93, 74, 55), [(107, 86, 64), (78, 62, 46)], 0.20),
    ],
    "marsh": [
        ((50, 64, 40), [(62, 78, 46), (40, 52, 32)], 0.22),
        ((56, 70, 44), [(70, 86, 50), (44, 58, 36)], 0.24),
        ((66, 56, 38), [(78, 66, 44), (54, 46, 32)], 0.22),
    ],
    "tundra": [
        ((222, 229, 236), [(240, 244, 248), (204, 212, 222)], 0.18),
        ((214, 222, 230), [(232, 238, 244), (196, 205, 216)], 0.20),
        ((176, 182, 188), [(190, 196, 202), (150, 156, 162)], 0.30),
    ],
    "city": [
        ((58, 60, 64), [(70, 72, 76), (48, 50, 54)], 0.20),
        ((64, 66, 70), [(76, 78, 82), (52, 54, 58)], 0.22),
        ((128, 126, 120), [(140, 138, 132), (112, 110, 104)], 0.15),
    ],
    "industrial": [
        ((112, 110, 104), [(124, 122, 116), (98, 96, 90)], 0.18),
        ((104, 102, 96), [(116, 114, 108), (90, 88, 82)], 0.20),
        ((110, 84, 62), [(126, 96, 70), (90, 68, 50)], 0.30),
    ],
}
INFECTED = ((46, 31, 58), [(122, 63, 176), (192, 107, 255)], 0.12)


def ground_atlas(biome: str = "countryside") -> Image.Image:
    """Atlas 96x16 : sol A, sol B, sol secondaire, sol infecté (violet réservé), rails,
    sol piégeux du biome (flaque, eau, glace, gravats, flaque toxique)."""
    rng = random.Random(7)
    tiles = BIOME_GROUNDS[biome][:2] + [BIOME_GROUNDS[biome][2], INFECTED]
    img = Image.new("RGBA", (96, 16), (0, 0, 0, 255))
    for i, (base, dots, density) in enumerate(tiles):
        _speckle(img, i * 16, base, dots, density, rng)
    if biome == "city":
        _paving(img, 32)
    _rails(img, 64, rng)
    _hazard(img, 80, biome, rng)
    return img


def _speckle(img: Image.Image, ox: int, base: tuple, dots: list, density: float, rng: random.Random) -> None:
    for x in range(16):
        for y in range(16):
            color = rng.choice(dots) if rng.random() < density else base
            img.putpixel((ox + x, y), color + (255,))


def _paving(img: Image.Image, ox: int) -> None:
    """Trottoir : dalles de 8 px."""
    for i in range(16):
        for line in (0, 8):
            img.putpixel((ox + i, line), (108, 106, 100, 255))
            img.putpixel((ox + line, i), (108, 106, 100, 255))


def _hazard(img: Image.Image, ox: int, biome: str, rng: random.Random) -> None:
    """Tuile piégeuse : ce qu'elle fait dépend du biome (voir BiomeData.rule)."""
    styles = {
        "countryside": ((70, 56, 40), [(58, 46, 34), (92, 76, 58)], 0.25),  # flaque de boue
        "marsh": ((36, 56, 50), [(52, 80, 72), (28, 44, 40)], 0.20),  # eau stagnante
        "tundra": ((156, 196, 222), [(178, 212, 232), (132, 176, 206)], 0.18),  # glace
        "city": ((70, 70, 72), [(110, 108, 104), (40, 40, 42)], 0.35),  # gravats
        "industrial": ((92, 116, 42), [(120, 150, 54), (70, 92, 30)], 0.22),  # flaque toxique
    }
    _speckle(img, ox, *styles[biome], rng)
    if biome == "marsh":  # rides et lentilles d'eau
        for x, y in ((3, 4), (4, 4), (5, 4), (10, 11), (11, 11), (12, 11)):
            img.putpixel((ox + x, y), (74, 104, 92, 255))
        for x, y in ((8, 6), (2, 12), (13, 3)):
            img.putpixel((ox + x, y), (96, 130, 60, 255))
    elif biome == "tundra":  # fissures blanches
        for x, y in ((2, 3), (3, 4), (4, 4), (5, 5), (9, 10), (10, 10), (11, 11), (12, 12), (7, 7)):
            img.putpixel((ox + x, y), (236, 246, 252, 255))
    elif biome == "industrial":  # bulles
        for x, y in ((4, 5), (11, 9), (7, 12), (13, 3)):
            img.putpixel((ox + x, y), (176, 206, 96, 255))


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
    ground_atlas().save(tiles / "ground_placeholder.png")  # campagne
    for biome in ("marsh", "tundra", "city", "industrial"):
        ground_atlas(biome).save(tiles / f"ground_{biome}.png")
    print("Placeholders générés.")


if __name__ == "__main__":
    main()
