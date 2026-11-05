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



# --- Équipement -----------------------------------------------------------------------
# Tenues : même silhouette (veste à manches), couleur et détails propres.

def jacket(main: str, dark: str, cuff: str, detail: str = "", detail_rows: tuple = ()) -> Image.Image:
    rows = [
        "............",
        "...mm..mm...",
        "..mmmmmmmm..",
        ".mmmmmmmmmm.",
        ".mmdmmmmdmm.",
        ".mmdmmmmdmm.",
        ".mmdmmmmdmm.",
        ".ccdmmmmdcc.",
        "...dmmmmd...",
        "...dmmmmd...",
        "...dddddd...",
        "............",
    ]
    for r in detail_rows:
        rows[r] = rows[r][:4] + "xxxx" + rows[r][8:]
    palette = {"m": main, "d": dark, "c": cuff}
    if detail:
        palette["x"] = detail
    return outline(from_map(rows, palette))


def worn_clothes() -> Image.Image:
    img = jacket("#7d7468", "#4f4840", "#5f574d")
    px(img, [(5, 5), (6, 5), (5, 6), (6, 6)], "#a0814f")  # pièce cousue
    return img


def hazmat() -> Image.Image:
    return outline(from_map([
        "....mmmm....",
        "...mvvvvm...",
        "..mmvvvvmm..",
        ".mmmmmmmmmm.",
        ".mmdmmmmdmm.",
        ".mmdmmmmdmm.",
        ".mmdmmmmdmm.",
        ".kkdmmmmdkk.",
        "...dmmmmd...",
        "...dmddmd...",
        "...kk..kk...",
        "............",
    ], {"m": "#e0c23a", "d": "#9c8420", "v": "#6fb6e8", "k": "#2c2c30"}))


def vest(main: str, dark: str, accent: str, rows_mid: tuple) -> Image.Image:
    return outline(from_map([
        "............",
        "..dd....dd..",
        "..dmd..dmd..",
        "..dmmddmmd..",
        rows_mid[0],
        rows_mid[1],
        "..dmmmmmmd..",
        "..dmmmmmmd..",
        rows_mid[2],
        "..dmmmmmmd..",
        "...dddddd...",
        "............",
    ], {"m": main, "d": dark, "a": accent}))


def plate_vest() -> Image.Image:
    return vest("#9aa3ab", "#5d646b", "#3e4449", ("..dmammamd..", "..dmmmmmmd..", "..dmammamd.."))


def kevlar_vest() -> Image.Image:
    return vest("#4f5a34", "#2f361e", "#6f7d48", ("..daammaad..", "..daammaad..", "..d333333d..".replace("3", "a")))


# Masques à gaz : vue de face.
def gas_mask(main: str, lens: str, filt: str, filt_light: str) -> Image.Image:
    return outline(from_map([
        "............",
        "...mmmmmm...",
        "..mmmmmmmm..",
        "..meemmeem..",
        "..meemmeem..",
        "..mmmmmmmm..",
        "...mmffmm...",
        "....ffff....",
        "....fFFf....",
        "....ffff....",
        "............",
        "............",
    ], {"m": main, "e": lens, "f": filt, "F": filt_light}))


def cartridge_mask() -> Image.Image:
    return outline(from_map([
        "............",
        "...mmmmmm...",
        "..mmmmmmmm..",
        "..meemmeem..",
        "..meemmeem..",
        "..mmmmmmmm..",
        ".cc.mmmm.cc.",
        ".cCc.mm.cCc.",
        ".ccc....ccc.",
        "............",
        "............",
        "............",
    ], {"m": "#3d3f45", "e": "#9fd0ff", "c": "#b45c3a", "C": "#e08a5a"}))


# Sacs.
def small_bag() -> Image.Image:
    return outline(from_map([
        "............",
        "............",
        "....bbbb....",
        "...b....b...",
        "..BBBBBBBB..",
        "..BbbbbbbB..",
        "..BbyybbbB..",
        "..BbbbbbbB..",
        "..BBBBBBBB..",
        "............",
        "............",
        "............",
    ], {"b": "#9a6b3f", "B": "#6b4a2f", "y": "#d9b25a"}))


def backpack(main: str, dark: str, flap: str, buckle: str, pocket: str, side: bool = False) -> Image.Image:
    rows = [
        "....dddd....",
        "...dmmmmd...",
        "..dmmmmmmd..",
        "..dffffffd..",
        "..dffyyffd..",
        "..dmmmmmmd..",
        "..dmmmmmmd..",
        "..dmppppmd..",
        "..dmppppmd..",
        "..dmmmmmmd..",
        "...dddddd...",
        "............",
    ]
    if side:  # poches latérales du sac militaire
        for r in (5, 6, 7, 8):
            rows[r] = ".p" + rows[r][2:10] + "p."
    return outline(from_map(rows, {"m": main, "d": dark, "f": flap, "y": buckle, "p": pocket}))


# Outils et armes : tracés en diagonale (manche en bas à gauche).
def line(d: ImageDraw.ImageDraw, a: tuple, b: tuple, color: str, width: int = 2) -> None:
    d.line([a, b], fill=rgb(color), width=width)


def crowbar() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (6, 5), "#c0392b")
    # crochet en haut : la barre remonte puis se recourbe
    px(img, [(6, 4), (7, 4), (6, 3), (7, 3), (7, 2), (8, 1), (9, 1), (10, 2), (10, 3), (8, 2)], "#c0392b")
    px(img, [(1, 10), (2, 11)], "#8e2a20")
    return outline(img)


def hatchet() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (7, 4), "#8a5a2b")
    d.polygon([(5, 2), (9, 1), (10, 5), (8, 6)], fill=rgb("#9aa3ab"))
    px(img, [(9, 1), (10, 2), (10, 3), (10, 4)], "#d8dde2")
    return outline(img)


def shears() -> Image.Image:
    img, d = canvas()
    line(d, (6, 6), (10, 1), "#c8ced6")
    line(d, (6, 5), (10, 2), "#9aa3ab", 1)
    d.ellipse((1, 6, 4, 9), outline=rgb("#c0392b"), width=1)
    d.ellipse((4, 8, 7, 11), outline=rgb("#c0392b"), width=1)
    px(img, [(4, 7), (5, 7), (6, 7)], "#c0392b")
    return outline(img)


def torch() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (6, 6), "#4a4f57", 3)
    line(d, (6, 6), (8, 4), "#c9962a", 1)
    px(img, [(9, 3), (10, 2), (9, 2), (10, 3)], "#6fb6e8")
    px(img, [(10, 1), (11, 1), (11, 2)], "#c9e8ff")
    px(img, [(3, 8), (4, 9)], "#d8433a")
    return outline(img)


def chem_kit() -> Image.Image:
    return outline(from_map([
        "............",
        "....kkkk....",
        "....k..k....",
        ".bbbbbbbbbb.",
        ".bwwwwwwwwb.",
        ".bwwwggwwwb.",
        ".bwwgggwwwb.",
        ".bwgGGGgwwb.",
        ".bwgGGGgwwb.",
        ".bwwwwwwwwb.",
        ".bbbbbbbbbb.",
        "............",
    ], {"k": "#4a4f57", "b": "#55622d", "w": "#e8e2cf", "g": "#9aa3ab", "G": "#7ad85a"}))


def iron_bar() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (9, 2), "#8f969e", 2)
    px(img, [(9, 1), (10, 1), (10, 2)], "#5d646b")
    px(img, [(1, 10), (1, 11), (2, 11)], "#5d646b")
    px(img, [(5, 6), (6, 5)], "#c8ced6")
    return outline(img)


def machete() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (4, 8), "#2c2c30", 2)
    d.polygon([(4, 7), (9, 1), (11, 1), (11, 2), (6, 8)], fill=rgb("#c8ced6"))
    px(img, [(10, 2), (9, 3), (8, 4), (7, 5)], "#eef2f5")
    return outline(img)


def fire_axe() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (8, 3), "#a0703a", 2)
    d.polygon([(6, 1), (9, 0), (11, 3), (10, 6), (8, 4)], fill=rgb("#c0392b"))
    px(img, [(10, 3), (10, 4), (11, 3)], "#d8dde2")
    return outline(img)


def sledgehammer() -> Image.Image:
    img, d = canvas()
    line(d, (2, 10), (7, 5), "#a0703a", 2)
    d.polygon([(5, 2), (8, 0), (11, 3), (8, 6)], fill=rgb("#5d646b"))
    px(img, [(8, 1), (9, 1), (9, 2)], "#9aa3ab")
    return outline(img)


EQUIPMENT_ICONS = {
    "outfit_worn": worn_clothes,
    "outfit_padded": lambda: jacket("#c9913f", "#8a5f28", "#8a5f28", "#a87530", (4, 6, 8)),
    "outfit_hazmat": hazmat,
    "outfit_plate": plate_vest,
    "outfit_kevlar": kevlar_vest,
    "mask_worn": lambda: gas_mask("#6f6a5f", "#8fb0a8", "#4a4640", "#7a7468"),
    "mask_filter": lambda: gas_mask("#556b4a", "#b8e0e8", "#d8d0b0", "#a59d7a"),
    "mask_cartridge": cartridge_mask,
    "bag_small": small_bag,
    "bag_hiking": lambda: backpack("#3f7fbf", "#24486e", "#2f5f90", "#f2c94c", "#5596d6"),
    "bag_military": lambda: backpack("#6b7a3a", "#3f4a22", "#55622d", "#a59d7a", "#7f8f4a", side=True),
    "tool_crowbar": crowbar,
    "tool_hatchet": hatchet,
    "tool_shears": shears,
    "tool_torch": torch,
    "tool_chem_kit": chem_kit,
    "weapon_pipe": iron_bar,
    "weapon_machete": machete,
    "weapon_axe": fire_axe,
    "weapon_sledge": sledgehammer,
}


def sun() -> Image.Image:
    return outline(from_map([
        "............",
        ".....y......",
        "..y..y..y...",
        "...yyyyy....",
        "..yyYYYyy...",
        "yyyYYYYYyyy.",
        "..yyYYYyy...",
        "...yyyyy....",
        "..y..y..y...",
        ".....y......",
        "............",
        "............",
    ], {"y": "#f2c94c", "Y": "#ffe9a3"}))


def moon() -> Image.Image:
    return outline(from_map([
        "............",
        "....mmm.....",
        "...mmM......",
        "..mmM.......",
        "..mmM.......",
        "..mmM.......",
        "..mmmM......",
        "...mmmMM....",
        "....mmmm....",
        "............",
        "............",
        "............",
    ], {"m": "#c9d6ff", "M": "#8fa0d8"}))


ICONS = {
    "health": heart, "infection": spore, "timer": clock, "sun": sun, "moon": moon, "bag": bag, "order": star, "recruit": person, "plan": plan,
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
    items_dir = OUT / "items"
    items_dir.mkdir(exist_ok=True)
    for name, draw in EQUIPMENT_ICONS.items():
        draw().save(items_dir / f"{name}.png")
    print(f"{len(ICONS)} icônes dans {OUT.relative_to(ROOT)}, {len(EQUIPMENT_ICONS)} dans items/")


if __name__ == "__main__":
    main()
