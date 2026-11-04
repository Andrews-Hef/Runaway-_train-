"""Icônes pixel art 12x12 de l'interface (ressources, vie, infection, temps...).

Usage, depuis la racine du repo :
    python tools/gen_icons.py

Chaque icône est dessinée en formes simples, puis reçoit un contour sombre d'un pixel :
toutes ont le même style et restent lisibles à 12 px. Sortie : assets/ui/icons/<nom>.png
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "icons"
SIZE = 12
OUTLINE = (26, 20, 22, 255)


def rgb(hex_color: str) -> tuple:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def canvas() -> tuple:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def px(img: Image.Image, points: list, color: str) -> None:
    for x, y in points:
        img.putpixel((x, y), rgb(color))


def outline(img: Image.Image) -> Image.Image:
    """Ajoute un contour sombre autour des pixels opaques (4 voisins)."""
    out = img.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            if img.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < SIZE and 0 <= ny < SIZE and img.getpixel((nx, ny))[3] > 0 and img.getpixel((nx, ny)) != OUTLINE:
                    out.putpixel((x, y), OUTLINE)
                    break
    return out


def from_map(rows: list, palette: dict) -> Image.Image:
    img, _ = canvas()
    assert len(rows) == SIZE, rows
    for y, row in enumerate(rows):
        assert len(row) == SIZE, (row, len(row))
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), rgb(palette[ch]))
    return img


# --- Interface ------------------------------------------------------------------------

def heart() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        "..rr....rr..",
        ".rwrr..rrrr.",
        ".rwrrrrrrrr.",
        ".rrrrrrrrRr.",
        "..rrrrrrRr..",
        "...rrrrRr...",
        "....rrRr....",
        ".....rr.....",
        "............",
        "............",
    ], {"r": "#d8433a", "R": "#9e2a24", "w": "#ffb3a8"}))


def spore() -> Image.Image:
    return outline(from_map([
        "............",
        ".....p......",
        "..p.ppp.p...",
        "...ppppp....",
        "..pplpppp...",
        ".ppllppPPp..",
        "..ppppPPp...",
        "...pppPP....",
        "..p.pPP.p...",
        ".....p......",
        "............",
        "............",
    ], {"p": "#b45ce6", "P": "#7a2fa8", "l": "#e8b3ff"}))


def clock() -> Image.Image:
    img, d = canvas()
    d.ellipse((1, 1, 10, 10), fill=rgb("#e8e2cf"))
    px(img, [(5, 3), (5, 4), (5, 5), (6, 5), (7, 5)], "#3a3030")
    px(img, [(5, 1), (5, 10), (1, 5), (10, 5)], "#b9ad8f")
    return outline(img)


def bag() -> Image.Image:
    return outline(from_map([
        "............",
        "....bbbb....",
        "...b....b...",
        "..BBBBBBBB..",
        "..BbbbbbbB..",
        "..BbbyybbB..",
        "..BbbbbbbB..",
        "..BbbbbbbB..",
        "..BbbbbbbB..",
        "..BBBBBBBB..",
        "............",
        "............",
    ], {"b": "#9a6b3f", "B": "#6b4a2f", "y": "#d9b25a"}))


def star() -> Image.Image:
    return outline(from_map([
        "............",
        ".....y......",
        ".....y......",
        "....yYy.....",
        ".yyyyYyyyy..",
        "..yyYYYyy...",
        "...yYYYy....",
        "...yy.yy....",
        "..yy...yy...",
        "............",
        "............",
        "............",
    ], {"y": "#f2c94c", "Y": "#c9962a"}))


def person() -> Image.Image:
    return outline(from_map([
        "............",
        "....ssss....",
        "....ssss....",
        "....ssss....",
        ".....ss.....",
        "...cccccc...",
        "..cccccccc..",
        "..cccccccc..",
        "..cc.cc.cc..",
        ".....cc.....",
        "....c..c....",
        "............",
    ], {"s": "#d8a27a", "c": "#b0742e"}))


def plan() -> Image.Image:
    return outline(from_map([
        "............",
        "..bbbbbbbb..",
        "..bwwwwwwb..",
        "..bbbbbbbb..",
        "..bwwbwwbb..",
        "..bbbbbbbb..",
        "..bwbbbbwb..",
        "..bwwwwwwb..",
        "..bbbbbbbb..",
        "..BBBBBBBB..",
        "............",
        "............",
    ], {"b": "#3a6fb0", "w": "#c9dcf0", "B": "#27486f"}))


# --- Ressources ------------------------------------------------------------------------

def scrap() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        "...rrr......",
        "..rRRrr.....",
        "..rRrrrr....",
        "...rrrrrgg..",
        "....rr.gGGg.",
        "...ll..gGgg.",
        "..llll..gg..",
        "..lLll......",
        "...ll.......",
        "............",
    ], {"r": "#b5653a", "R": "#e09060", "g": "#8f969e", "G": "#c8ced6", "l": "#7d4a2e", "L": "#a8673f"}))


def wood() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        "............",
        "..bbbbbbbyy.",
        ".bBBbbbbyooy",
        ".bbbbBBbyoyy",
        ".bbbbbbbyooy",
        "..bbbbbbbyy.",
        "............",
        "............",
        "............",
        "............",
    ], {"b": "#8a5a2b", "B": "#6b4220", "y": "#d9b27a", "o": "#a8763f"}))


def leaf(main: str, dark: str, light: str, dots: bool = False) -> Image.Image:
    img = from_map([
        "............",
        ".......ggg..",
        ".....ggggg..",
        "....gglggg..",
        "...gglgggd..",
        "...glggggd..",
        "..gglgggdd..",
        "..glgggdd...",
        "..lgggdd....",
        ".s.ddd......",
        "s...........",
        "............",
    ], {"g": main, "d": dark, "l": light, "s": "#5a7a32"})
    if dots:
        px(img, [(10, 3), (1, 6), (9, 8)], "#e8b3ff")
    return outline(img)


def cloth() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        "..cccccccc..",
        "..cCcccccc..",
        "..cccccccc..",
        "..dddddddd..",
        "..cccccccc..",
        "..cccccCcc..",
        "..dddddddd..",
        "..cccccccc..",
        "............",
        "............",
    ], {"c": "#c9b48a", "C": "#e6d6b0", "d": "#9a8660"}))


def gear() -> Image.Image:
    return outline(from_map([
        "............",
        ".....gg.....",
        "..g.gggg.g..",
        "...gggggg...",
        "..gggGGggg..",
        ".gggG..Gggg.",
        ".gggG..Gggg.",
        "..gggGGggg..",
        "...gggggg...",
        "..g.gggg.g..",
        ".....gg.....",
        "............",
    ], {"g": "#8fb0c8", "G": "#5d7a8f"}))


def metal_plate() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        ".mmmmmmmmmm.",
        ".mrmmmmmmrm.",
        ".mmwwmmmmmm.",
        ".mmmwwmmmmm.",
        ".mmmmmwwmmm.",
        ".mrmmmmmmrm.",
        ".MMMMMMMMMM.",
        "............",
        "............",
        "............",
    ], {"m": "#a7adb8", "M": "#6f7580", "r": "#4a4f58", "w": "#e1e5ec"}))


def flask() -> Image.Image:
    return outline(from_map([
        "............",
        "....gggg....",
        ".....gg.....",
        ".....gg.....",
        "....g..g....",
        "...g....g...",
        "...gllllg...",
        "..gllLllllg.",
        "..glllllllg.",
        "..gggggggg..",
        "............",
        "............",
    ], {"g": "#c8dde0", "l": "#5fd6a8", "L": "#b8ffe2"}))


def bottle() -> Image.Image:
    return outline(from_map([
        "............",
        ".....bb.....",
        "....bbbb....",
        "...wwwwww...",
        "...wwrrww...",
        "...wrrrrw...",
        "...wwrrww...",
        "...wwwwww...",
        "...wwwwww...",
        "...WWWWWW...",
        "............",
        "............",
    ], {"b": "#5d7a8f", "w": "#eeeee6", "W": "#b8b8ae", "r": "#c23b36"}))


def capsule() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        "........rr..",
        ".......rrrr.",
        "......rRrrr.",
        ".....wwrrr..",
        "....wwwwr...",
        "...wwwww....",
        "..wwwww.....",
        "..wWww......",
        "...ww.......",
        "............",
    ], {"r": "#d8433a", "R": "#ffb3a8", "w": "#f2f2ea", "W": "#ffffff"}))


def vial(liquid: str, light: str) -> Image.Image:
    return outline(from_map([
        "............",
        "....kkkk....",
        "....gggg....",
        "....g..g....",
        "....g..g....",
        "....gllg....",
        "....glLg....",
        "....gllg....",
        "....gllg....",
        "....gllg....",
        ".....gg.....",
        "............",
    ], {"k": "#6f7580", "g": "#c8dde0", "l": liquid, "L": light}))


def syringe() -> Image.Image:
    return outline(from_map([
        "............",
        "..........n.",
        ".........n..",
        "........gg..",
        ".......gyyg.",
        "......gyyg..",
        ".....gyyg...",
        "....gyyg....",
        "...pgyg.....",
        "..pp.g......",
        ".pp.........",
        "............",
    ], {"n": "#c8ced6", "g": "#c8dde0", "y": "#f2c94c", "p": "#8f969e"}))


ICONS = {
    "health": heart, "infection": spore, "timer": clock, "bag": bag, "order": star, "recruit": person, "plan": plan,
    "scrap": scrap, "wood": wood,
    "herb": lambda: leaf("#6fbf4a", "#3f7a2a", "#b5e88f"),
    "infected_herb": lambda: leaf("#a04fd0", "#5e2585", "#d9a6ff", dots=True),
    "cloth": cloth, "parts": gear, "metal_plate": metal_plate, "chemicals": flask,
    "antiseptic": bottle, "antibiotics": capsule,
    "serum": lambda: vial("#5aa8e6", "#c9e8ff"), "vaccine": syringe,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in ICONS.items():
        draw().save(OUT / f"{name}.png")
    print(f"{len(ICONS)} icônes dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
