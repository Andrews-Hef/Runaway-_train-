"""Kit d'interface pixel art : plaques, boutons, onglets, papier, cases, jauges.

Usage, depuis la racine du repo :
    python tools/gen_ui.py

Chaque texture est petite et se découpe en 9 morceaux (StyleBoxTexture de Godot) :
les coins restent nets, les bords et le centre s'étirent. Le style reprend le train :
fer noirci, liseré rouge, rivets en laiton. Sortie : assets/ui/frames/<nom>.png
Les marges de découpe sont dans ui/theme/game_theme.tres (texture_margin_*).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "frames"

OUTLINE = (20, 16, 18, 255)
IRON_DEEP = (16, 16, 20, 255)
IRON_DARK = (27, 28, 33, 246)
IRON = (52, 54, 63, 255)
IRON_LIGHT = (84, 87, 99, 255)
BRASS = (201, 164, 90, 255)
BRASS_LIGHT = (240, 210, 138, 255)
BRASS_DARK = (107, 85, 48, 255)
TRAIN_RED = (130, 38, 33, 255)
CLEAR = (0, 0, 0, 0)


def new(w: int, h: int, fill=CLEAR) -> Image.Image:
    return Image.new("RGBA", (w, h), fill)


def ring(img: Image.Image, inset: int, top_left, bottom_right=None, sides: str = "tlbr") -> None:
    """Trace un cadre d'un pixel à `inset` du bord : haut/gauche et bas/droite de couleurs différentes."""
    bottom_right = bottom_right or top_left
    w, h = img.size
    x0, y0, x1, y1 = inset, inset, w - 1 - inset, h - 1 - inset
    for x in range(x0, x1 + 1):
        if "t" in sides:
            img.putpixel((x, y0), top_left)
        if "b" in sides:
            img.putpixel((x, y1), bottom_right)
    for y in range(y0, y1 + 1):
        if "l" in sides:
            img.putpixel((x0, y), top_left)
        if "r" in sides:
            img.putpixel((x1, y), bottom_right)


def fill_inside(img: Image.Image, inset: int, color) -> None:
    w, h = img.size
    for y in range(inset, h - inset):
        for x in range(inset, w - inset):
            img.putpixel((x, y), color)


def rivet(img: Image.Image, x: int, y: int) -> None:
    """Rivet 2x2 en laiton : reflet en haut à gauche, ombre en bas à droite."""
    img.putpixel((x, y), BRASS_LIGHT)
    img.putpixel((x + 1, y), BRASS)
    img.putpixel((x, y + 1), BRASS)
    img.putpixel((x + 1, y + 1), BRASS_DARK)


# --- Panneaux -------------------------------------------------------------------------

def plate() -> Image.Image:
    """Grande plaque des menus (24x24, marge 6) : fer, biseau, liseré rouge, 4 rivets."""
    img = new(24, 24)
    fill_inside(img, 1, IRON_DARK)
    ring(img, 0, OUTLINE)
    ring(img, 1, IRON_LIGHT, IRON_DEEP)
    ring(img, 4, TRAIN_RED)
    for x, y in ((2, 2), (20, 2), (2, 20), (20, 20)):
        rivet(img, x, y)
    return img


def hud_plate() -> Image.Image:
    """Petite plaque du HUD (12x12, marge 3), plus transparente : on voit le jeu derrière."""
    img = new(12, 12)
    fill_inside(img, 1, (22, 23, 28, 205))
    ring(img, 0, (20, 16, 18, 225))
    ring(img, 1, (84, 87, 99, 200), (12, 12, 15, 210))
    for x, y in ((1, 1), (10, 1), (1, 10), (10, 10)):
        img.putpixel((x, y), BRASS)
    return img


def paper() -> Image.Image:
    """Télégramme du capitaine (24x24, marge 6) : papier jauni, bord abîmé, deux punaises."""
    img = new(24, 24)
    fill_inside(img, 1, (218, 202, 163, 250))
    ring(img, 0, (62, 46, 32, 255))
    ring(img, 1, (238, 226, 196, 255), (176, 154, 112, 255))
    # bord du bas un peu déchiré
    for x in (5, 6, 12, 17, 18):
        img.putpixel((x, 23), CLEAR)
        img.putpixel((x, 22), (62, 46, 32, 255))
    for x, y in ((3, 3), (19, 3)):
        img.putpixel((x, y), (230, 90, 70, 255))
        img.putpixel((x + 1, y), (190, 50, 40, 255))
        img.putpixel((x, y + 1), (190, 50, 40, 255))
        img.putpixel((x + 1, y + 1), (120, 30, 25, 255))
    return img


def alert() -> Image.Image:
    """Bandeau d'alerte (sifflet du train) : plaque rouge sombre, rivets (12x12, marge 3)."""
    img = new(12, 12)
    fill_inside(img, 1, (96, 26, 22, 235))
    ring(img, 0, OUTLINE)
    ring(img, 1, (176, 60, 48, 255), (52, 14, 12, 255))
    for x, y in ((1, 1), (10, 1), (1, 10), (10, 10)):
        img.putpixel((x, y), BRASS_LIGHT)
    return img


def inset() -> Image.Image:
    """Fond creusé (8x8, marge 2) : contenu des onglets, sous la plaque."""
    img = new(8, 8)
    fill_inside(img, 1, (15, 15, 19, 200))
    ring(img, 0, (10, 10, 12, 230))
    ring(img, 1, (8, 8, 10, 220), (40, 41, 48, 200))
    return img


def slot() -> Image.Image:
    """Case d'équipement (8x8, marge 2) : creusée, ombre en haut, reflet en bas."""
    img = new(8, 8)
    fill_inside(img, 1, (12, 12, 16, 215))
    ring(img, 0, OUTLINE)
    ring(img, 1, (6, 6, 8, 255), (74, 76, 86, 255))
    return img


def track() -> Image.Image:
    """Fond des jauges (6x6, marge 2)."""
    img = new(6, 6)
    fill_inside(img, 1, (8, 8, 10, 225))
    ring(img, 0, OUTLINE)
    ring(img, 1, (4, 4, 6, 255), (30, 31, 37, 255), sides="tl")
    return img


# --- Boutons et onglets ---------------------------------------------------------------

def button(body, light, dark) -> Image.Image:
    """Bouton en relief (12x12, marge 4)."""
    img = new(12, 12)
    fill_inside(img, 1, body)
    ring(img, 0, OUTLINE)
    ring(img, 1, light, dark)
    return img


def button_disabled() -> Image.Image:
    img = new(12, 12)
    fill_inside(img, 1, (32, 33, 38, 220))
    ring(img, 0, (20, 16, 18, 200))
    ring(img, 1, (42, 43, 49, 220))
    return img


def focus() -> Image.Image:
    """Cadre de sélection (manette, clavier) : laiton, centre vide (12x12, marge 4)."""
    img = new(12, 12)
    ring(img, 0, BRASS_LIGHT)
    img.putpixel((0, 0), CLEAR)
    img.putpixel((11, 0), CLEAR)
    img.putpixel((0, 11), CLEAR)
    img.putpixel((11, 11), CLEAR)
    return img


def tab(body, top, active: bool) -> Image.Image:
    """Onglet (12x12, marge 4) : ouvert vers le bas pour se coller au contenu."""
    img = new(12, 12)
    fill_inside(img, 1, body)
    ring(img, 0, OUTLINE, sides="tlr")
    for x in range(1, 11):
        img.putpixel((x, 1), top)
    if active:
        for x in range(1, 11):
            img.putpixel((x, 2), BRASS_DARK)
    for y in range(1, 12):
        img.putpixel((1, y), (top[0], top[1], top[2], 160))
    return img


def grabber(body, light) -> Image.Image:
    """Poignée de la barre de défilement (6x8, marge 2)."""
    img = new(6, 8)
    fill_inside(img, 1, body)
    ring(img, 0, OUTLINE)
    ring(img, 1, light, BRASS_DARK)
    return img


FRAMES = {
    "plate": plate,
    "hud_plate": hud_plate,
    "paper": paper,
    "alert": alert,
    "inset": inset,
    "slot": slot,
    "track": track,
    "button_normal": lambda: button(IRON, IRON_LIGHT, (24, 25, 30, 255)),
    "button_hover": lambda: button((66, 69, 80, 255), BRASS, (24, 25, 30, 255)),
    "button_pressed": lambda: button((36, 38, 45, 255), (16, 16, 20, 255), IRON_LIGHT),
    "button_disabled": button_disabled,
    "focus": focus,
    "tab_selected": lambda: tab((27, 28, 33, 250), BRASS, True),
    "tab_unselected": lambda: tab((20, 21, 25, 235), (60, 62, 72, 255), False),
    "tab_hovered": lambda: tab((40, 42, 50, 245), IRON_LIGHT, False),
    "grabber": lambda: grabber(BRASS_DARK, BRASS),
    "grabber_hover": lambda: grabber(BRASS, BRASS_LIGHT),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in FRAMES.items():
        draw().save(OUT / f"{name}.png")
    print(f"{len(FRAMES)} textures dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
