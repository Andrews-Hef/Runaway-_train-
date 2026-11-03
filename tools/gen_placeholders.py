"""Génère les sprites temporaires (programmer art) du projet.

Usage : python tools/gen_placeholders.py   (depuis la racine du repo, Pillow requis)

Ces images servent seulement à rendre le jeu jouable en attendant les vrais
assets. Le dossier tools/ contient un .gdignore : Godot ne l'importe pas.
La couleur violette est RÉSERVÉE à l'infection (voir la note Direction artistique).
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

OUTLINE = (26, 26, 34, 255)
PALETTE = {
    "skin": (201, 143, 107, 255),
    "hair": (59, 43, 34, 255),
    "mask": (108, 114, 122, 255),
    "mask_dark": (71, 75, 82, 255),
    "lens": (143, 211, 196, 255),
    "jacket": (90, 107, 59, 255),
    "jacket_dark": (69, 83, 44, 255),
    "belt": (107, 74, 47, 255),
    "pants": (58, 63, 75, 255),
    "boots": (43, 37, 34, 255),
    "rock": (111, 106, 99, 255),
    "rock_dark": (87, 82, 76, 255),
    "rock_light": (141, 135, 126, 255),
}


def rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, color: tuple) -> None:
    """Remplit le rectangle inclusif (x0, y0)-(x1, y1)."""
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            img.putpixel((x, y), color)


def outline(img: Image.Image) -> None:
    """Ajoute un contour sombre de 1 px autour des pixels opaques."""
    w, h = img.size
    src = img.copy()
    for x in range(w):
        for y in range(h):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] != 0:
                    img.putpixel((x, y), OUTLINE)
                    break


def player() -> Image.Image:
    """Survivant avec masque à gaz, vu de face, 16x24, pieds en bas."""
    p = PALETTE
    img = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    rect(img, 5, 2, 10, 3, p["hair"])          # cheveux
    rect(img, 5, 4, 10, 4, p["skin"])          # front
    rect(img, 5, 5, 10, 8, p["mask"])          # masque
    img.putpixel((6, 5), p["lens"])            # verres
    img.putpixel((9, 5), p["lens"])
    rect(img, 7, 7, 8, 9, p["mask_dark"])      # filtre
    rect(img, 4, 10, 11, 15, p["jacket"])      # veste
    rect(img, 4, 10, 4, 15, p["jacket_dark"])
    rect(img, 3, 11, 3, 15, p["jacket_dark"])  # bras
    rect(img, 12, 11, 12, 15, p["jacket_dark"])
    img.putpixel((3, 16), p["skin"])           # mains
    img.putpixel((12, 16), p["skin"])
    rect(img, 4, 15, 11, 15, p["belt"])        # ceinture
    rect(img, 5, 16, 10, 20, p["pants"])       # pantalon
    rect(img, 7, 19, 8, 20, (0, 0, 0, 0))      # écart entre les jambes
    rect(img, 5, 21, 7, 22, p["boots"])        # bottes
    rect(img, 8, 21, 10, 22, p["boots"])
    outline(img)
    return img


def rock() -> Image.Image:
    """Rocher 16x16, base en bas."""
    p = PALETTE
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    rect(img, 3, 6, 12, 14, p["rock"])
    rect(img, 5, 4, 10, 5, p["rock"])
    rect(img, 2, 9, 2, 13, p["rock"])
    rect(img, 13, 8, 13, 13, p["rock_dark"])
    rect(img, 4, 12, 12, 14, p["rock_dark"])
    rect(img, 5, 5, 7, 6, p["rock_light"])
    img.putpixel((4, 7), p["rock_light"])
    outline(img)
    return img


def ground_atlas() -> Image.Image:
    """Atlas 64x16 : herbe A, herbe B, terre, sol infecté (violet réservé)."""
    rng = random.Random(7)
    tiles = [
        ((62, 91, 47), [(74, 107, 55), (52, 80, 42)], 0.18),
        ((69, 101, 53), [(84, 118, 62), (58, 88, 45)], 0.22),
        ((93, 74, 55), [(107, 86, 64), (78, 62, 46)], 0.20),
        ((46, 31, 58), [(122, 63, 176), (192, 107, 255)], 0.12),
    ]
    img = Image.new("RGBA", (64, 16), (0, 0, 0, 255))
    for i, (base, dots, density) in enumerate(tiles):
        for x in range(16):
            for y in range(16):
                color = base
                if rng.random() < density:
                    color = rng.choice(dots)
                img.putpixel((i * 16 + x, y), color + (255,))
    return img


def main() -> None:
    sprites = ROOT / "assets" / "sprites" / "placeholders"
    tiles = ROOT / "assets" / "tiles"
    sprites.mkdir(parents=True, exist_ok=True)
    tiles.mkdir(parents=True, exist_ok=True)
    player().save(sprites / "player.png")
    rock().save(sprites / "rock.png")
    ground_atlas().save(tiles / "ground_placeholder.png")
    print("Placeholders générés.")


if __name__ == "__main__":
    main()
