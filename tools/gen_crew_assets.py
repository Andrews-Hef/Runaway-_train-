#!/usr/bin/env python3
"""Définitions td2d des 20 apparences d'équipiers : art/assets/characters/crew-01..20/asset.json.

Chaque équipier part du même squelette et des mêmes animations que le joueur (survivor :
4 directions, idle, walk, harvest, attack, work). Ce qui change : la carrure, la peau, la
coiffure ou le couvre-chef, les couleurs de la tenue et les accessoires (écharpe, sac,
lunettes, barbe, manteau long, gilet).

Pas de violet (réservé à l'infection), pas d'ocre (la veste du joueur) : on reconnaît le
joueur d'un coup d'œil.

Usage, depuis la racine du repo :
    python3 tools/gen_crew_assets.py
    cd art && td2d batch --json        (ou td2d generate characters/crew-01 ...)
    cd .. && python3 tools/sync_td2d.py && python3 tools/gen_crew_portraits.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "assets" / "characters"
SURVIVOR = ART / "survivor" / "asset.json"

SKINS = {
    "pale": "#efc6a2",
    "light": "#dcaa82",
    "medium": "#c98f6b",
    "tan": "#a8714c",
    "dark": "#7a4e33",
    "deep": "#5a3826",
}
HAIRS = {
    "black": "#1f1b1c",
    "dark-brown": "#3b2a20",
    "brown": "#5e3e28",
    "auburn": "#7a3a22",
    "blond": "#b8955a",
    "red": "#8c3a20",
    "grey": "#7d7c80",
    "white": "#c4c2bd",
}
CLOTH = {
    "olive": "#5a6b3b",
    "navy": "#2f3e5c",
    "rust": "#8a4b2a",
    "teal": "#2f6b6b",
    "burgundy": "#6e2a2e",
    "khaki": "#8a7f5a",
    "grey": "#5c5f66",
    "denim": "#3d5a80",
    "forest": "#2f5233",
    "red": "#9a3a2c",
    "mustard": "#a8902e",
    "tan": "#9c7a54",
    "black": "#2a2a30",
    "white": "#b9b6ad",
    "steel": "#5f6670",
}
PANTS = {
    "charcoal": "#3a3f4b",
    "brown": "#4f3a2a",
    "khaki": "#6e6448",
    "denim": "#34465f",
    "black": "#26262c",
    "olive": "#46502f",
}
BUILDS = {
    # largeur du torse, écart des bras, largeur du bassin
    "slim": (0.36, 0.23, 0.31),
    "normal": (0.40, 0.25, 0.34),
    "broad": (0.47, 0.285, 0.38),
}

# Les 20 équipiers : choisis à la main pour qu'aucun ne ressemble à un autre.
LOOKS = [
    dict(desc="cheveux courts bruns, veste olive, écharpe rouge", build="normal", skin="light", hair="short", hair_color="brown",
         top="olive", pants="charcoal", accents=["scarf"], accent="red"),
    dict(desc="crâne rasé, barbe noire, veste marine, costaud", build="broad", skin="dark", hair="shaved", hair_color="black",
         top="navy", pants="black", accents=["beard"]),
    dict(desc="cheveux longs blonds, veste en jean, mince", build="slim", skin="pale", hair="long", hair_color="blond",
         top="denim", pants="khaki", accents=[]),
    dict(desc="bonnet gris, manteau long bordeaux, lunettes", build="normal", skin="medium", hair="beanie", hair_color="dark-brown",
         top="burgundy", pants="charcoal", accents=["longcoat", "glasses"], accent="grey"),
    dict(desc="casquette kaki, veste sarcelle, sac à dos", build="normal", skin="tan", hair="cap", hair_color="black",
         top="teal", pants="brown", accents=["backpack"], accent="khaki"),
    dict(desc="capuche vert forêt, écharpe beige", build="slim", skin="dark", hair="hood", hair_color="black",
         top="forest", pants="brown", accents=["scarf"], accent="tan", hood="forest"),
    dict(desc="casque d'acier, lunettes de soudeur, veste rouille, costaud", build="broad", skin="light", hair="helmet",
         hair_color="brown", top="rust", pants="charcoal", accents=["goggles"], accent="steel"),
    dict(desc="queue de cheval auburn, gilet gris sur chemise claire", build="slim", skin="pale", hair="ponytail",
         hair_color="auburn", top="white", pants="denim", accents=["vest"], accent="grey"),
    dict(desc="coupe afro noire, veste rouge, sacoche", build="normal", skin="deep", hair="afro", hair_color="black",
         top="red", pants="black", accents=["satchel"]),
    dict(desc="bandana rouge, veste noire, barbe brune", build="normal", skin="medium", hair="bandana", hair_color="dark-brown",
         top="black", pants="khaki", accents=["beard"], accent="red"),
    dict(desc="chignon gris, manteau long beige, lunettes", build="slim", skin="light", hair="bun", hair_color="grey",
         top="tan", pants="brown", accents=["longcoat", "glasses"]),
    dict(desc="crâne rasé, gilet kaki sur chemise olive, sac à dos, costaud", build="broad", skin="dark", hair="shaved",
         hair_color="black", top="olive", pants="olive", accents=["vest", "backpack"], accent="khaki"),
    dict(desc="cheveux blancs, barbe blanche, manteau long marine", build="normal", skin="pale", hair="short", hair_color="white",
         top="navy", pants="charcoal", accents=["beard", "longcoat"]),
    dict(desc="cheveux longs noirs, veste moutarde, écharpe sarcelle", build="slim", skin="tan", hair="long", hair_color="black",
         top="mustard", pants="black", accents=["scarf"], accent="teal"),
    dict(desc="bonnet moutarde, veste en jean, lunettes de soudeur", build="normal", skin="light", hair="beanie",
         hair_color="blond", top="denim", pants="brown", accents=["goggles"], accent="mustard"),
    dict(desc="capuche grise, veste marine, sac à dos", build="normal", skin="medium", hair="hood", hair_color="brown",
         top="navy", pants="khaki", accents=["backpack"], hood="grey"),
    dict(desc="casquette rouge, cheveux blonds, veste vert forêt, mince", build="slim", skin="pale", hair="cap", hair_color="blond",
         top="forest", pants="denim", accents=[], accent="red"),
    dict(desc="bandana olive, cheveux longs bruns, gilet bordeaux sur chemise grise", build="normal", skin="tan", hair="bandana-long",
         hair_color="brown", top="grey", pants="charcoal", accents=["vest"], accent="olive", vest="burgundy"),
    dict(desc="casque olive, veste olive, barbe noire, costaud", build="broad", skin="medium", hair="helmet", hair_color="black",
         top="khaki", pants="olive", accents=["beard"], accent="olive"),
    dict(desc="cheveux roux courts, manteau long sarcelle, lunettes", build="normal", skin="pale", hair="short", hair_color="red",
         top="teal", pants="brown", accents=["longcoat", "glasses"]),
]


def mat(color: str, bands: int = 3, hue: int = 25) -> dict:
    return {"color": color, "bands": bands, "hueShift": hue}


def darker(hex_color: str, factor: float = 0.72) -> str:
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % (int(r * factor), int(g * factor), int(b * factor))


def box(pid, bone, material, size, position, **extra):
    return {"type": "box", "id": pid, "bone": bone, "material": material, "size": size, "position": position, **extra}


def sphere(pid, bone, material, radius, position, **extra):
    return {"type": "sphere", "id": pid, "bone": bone, "material": material, "radius": radius, "position": position, **extra}


def capsule(pid, bone, material, radius, length, position, **extra):
    return {"type": "capsule", "id": pid, "bone": bone, "material": material, "radius": radius, "length": length,
            "position": position, **extra}


def head_parts(look: dict) -> list:
    """Visage, puis coiffure ou couvre-chef."""
    style = look["hair"]
    parts = [sphere("face", "head", "skin", 0.12, [0, 1.62, 0.03])]
    short_hair = sphere("hair", "head", "hair", 0.128, [0, 1.655, -0.02])
    if style == "short":
        parts.append(short_hair)
    elif style == "shaved":
        parts.append(sphere("hair", "head", "hair", 0.122, [0, 1.645, -0.03]))
    elif style == "long":
        parts += [short_hair, box("hair-back", "head", "hair", [0.25, 0.26, 0.08], [0, 1.52, -0.1])]
    elif style == "ponytail":
        parts += [short_hair, box("ponytail", "head", "hair", [0.07, 0.2, 0.07], [0, 1.53, -0.16])]
    elif style == "bun":
        parts += [short_hair, sphere("bun", "head", "hair", 0.065, [0, 1.71, -0.12])]
    elif style == "afro":
        parts.append(sphere("hair", "head", "hair", 0.165, [0, 1.69, -0.03]))
    elif style == "beanie":
        parts += [sphere("beanie", "head", "accent", 0.135, [0, 1.69, -0.01]),
                  box("beanie-rim", "head", "accent-dark", [0.27, 0.05, 0.27], [0, 1.655, 0])]
    elif style == "cap":
        parts += [short_hair, sphere("cap", "head", "accent", 0.13, [0, 1.69, -0.01]),
                  box("visor", "head", "accent-dark", [0.18, 0.02, 0.11], [0, 1.675, 0.15])]
    elif style == "hood":
        parts.append(sphere("hood", "head", "hood", 0.145, [0, 1.64, -0.03]))
    elif style == "helmet":
        parts += [sphere("helmet", "head", "accent", 0.142, [0, 1.68, -0.01]),
                  box("helmet-rim", "head", "accent-dark", [0.31, 0.03, 0.31], [0, 1.635, 0])]
    elif style == "bandana":
        parts += [short_hair, box("bandana", "head", "accent", [0.265, 0.05, 0.265], [0, 1.68, -0.005])]
    elif style == "bandana-long":
        parts += [short_hair, box("hair-back", "head", "hair", [0.25, 0.26, 0.08], [0, 1.52, -0.1]),
                  box("bandana", "head", "accent", [0.265, 0.05, 0.265], [0, 1.68, -0.005])]
    else:
        raise ValueError(style)
    return parts


def accessory_parts(look: dict, torso_w: float, arm_x: float) -> list:
    parts = []
    for name in look["accents"]:
        if name == "scarf":
            parts.append(box("scarf", "chest", "accent", [torso_w - 0.08, 0.1, 0.3], [0, 1.5, 0.02]))
        elif name == "beard":
            parts.append(box("beard", "head", "hair", [0.16, 0.08, 0.07], [0, 1.55, 0.1]))
        elif name == "glasses":
            parts.append(sphere("glasses", "head", "dark", 0.03, [0.045, 1.63, 0.13], mirror="x"))
        elif name == "goggles":
            parts += [box("goggle-band", "head", "dark", [0.27, 0.035, 0.27], [0, 1.7, 0]),
                      sphere("goggles", "head", "lens", 0.036, [0.05, 1.705, 0.125], mirror="x")]
        elif name == "backpack":
            parts.append(box("backpack", "chest", "pack", [torso_w - 0.08, 0.38, 0.16], [0, 1.27, -0.2]))
        elif name == "satchel":
            parts += [box("satchel", "hips", "pack", [0.12, 0.14, 0.08], [arm_x - 0.02, 1.0, 0.04]),
                      box("strap", "chest", "pack", [torso_w + 0.02, 0.04, 0.3], [0, 1.4, 0], rotation=[0, 0, 35])]
        elif name == "longcoat":
            parts.append(box("coat-skirt", "hips", "top", [torso_w + 0.02, 0.34, 0.28], [0, 0.86, 0]))
        elif name == "vest":
            parts.append(box("vest", "chest", "vest", [torso_w + 0.02, 0.42, 0.28], [0, 1.28, 0]))
        else:
            raise ValueError(name)
    return parts


def asset(index: int, look: dict, base: dict) -> dict:
    torso_w, arm_x, pelvis_w = BUILDS[look["build"]]
    top = CLOTH[look["top"]]
    accent = CLOTH.get(look.get("accent", "grey"), "#5c5f66")
    materials = {
        "skin": mat(SKINS[look["skin"]], 3, 25),
        "hair": mat(HAIRS[look["hair_color"]], 3, 20),
        "top": mat(top, 3, 30),
        "top-dark": mat(darker(top), 3, 30),
        "pants": mat(PANTS[look["pants"]], 3, 20),
        "boots": {"color": "#2b2522", "bands": 2},
        "pack": mat("#6b4a2f", 3, 25),
        "accent": mat(accent, 3, 25),
        "accent-dark": mat(darker(accent), 3, 25),
        "hood": mat(CLOTH[look.get("hood", "grey")], 3, 25),
        "vest": mat(CLOTH[look.get("vest", look.get("accent", "khaki"))], 3, 25),
        "lens": {"color": "#8fd3c4", "emissive": "#1f4a40", "bands": 2},
    }
    parts = [
        box("pelvis", "hips", "pants", [pelvis_w, 0.18, 0.22], [0, 0.95, 0]),
        box("torso", "chest", "top", [torso_w, 0.5, 0.26], [0, 1.26, 0]),
        *head_parts(look),
        capsule("upper-arm", "leftUpperArm", "top", 0.065, 0.18, [arm_x, 1.3, 0], mirror="x"),
        capsule("lower-arm", "leftLowerArm", "top-dark", 0.055, 0.18, [arm_x, 1.04, 0], mirror="x"),
        sphere("hand", "leftLowerArm", "skin", 0.05, [arm_x, 0.88, 0], mirror="x"),
        capsule("thigh", "leftUpperLeg", "pants", 0.085, 0.24, [0.1, 0.71, 0], mirror="x"),
        capsule("shin", "leftLowerLeg", "pants", 0.075, 0.24, [0.1, 0.31, 0], mirror="x"),
        box("boot", "leftFoot", "boots", [0.13, 0.1, 0.24], [0.1, 0.05, 0.03], mirror="x"),
        *accessory_parts(look, torso_w, arm_x),
    ]
    # Seulement les matériaux portés par une pièce (td2d signale les autres).
    used = {part["material"] for part in parts}
    materials = {key: value for key, value in materials.items() if key in used}
    name = "crew-%02d" % index
    return {
        "$schema": "../../../.td2d/schemas/asset.schema.json",
        "schemaVersion": "1.0.0",
        "id": f"characters/{name}",
        "type": "character",
        "description": f"Équipier n°{index} : {look['desc']}.",
        "frame": dict(base["frame"]),
        "directions": base["directions"],
        "rig": base["rig"],
        "export": {"formats": ["manifest", "godot-spriteframes"],
                   "godot": {"directory": f"res://assets/sprites/crew/{name.replace('-', '_')}/"}},
        "materials": materials,
        "model": {"parts": parts},
        "animation": base["animation"],
    }


def main() -> None:
    base = json.loads(SURVIVOR.read_text())
    for index, look in enumerate(LOOKS, start=1):
        data = asset(index, look, base)
        path = ART / ("crew-%02d" % index) / "asset.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(LOOKS)} équipiers écrits dans {ART.relative_to(ROOT)}/crew-XX/")


if __name__ == "__main__":
    main()
