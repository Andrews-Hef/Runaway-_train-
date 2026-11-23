#!/usr/bin/env python3
"""Définitions td2d de la grande gare fortifiée (gares refuges) : art/assets/props/<id>/asset.json.

Une gare refuge est une ville sûre sur la ligne : elle doit se voir de loin. On y trouve
le bâtiment voyageurs (verrière en berceau, horloge, pavillons d'angle), les remparts et
leurs tours, la porte fortifiée, et la vie du quai et de la place : lampadaires, horloge
de quai, bancs, malles, étals de marché, fontaine, arbres, jardinières, grue à eau du
dépôt, tente de la quarantaine, colonnes de la marquise.

Même caméra, même lumière, mêmes 16 px par mètre que les autres sprites (td2d.project.json).
Pas de violet (réservé à l'infection).

Usage, depuis la racine du repo :
    python3 tools/gen_station_assets.py
    cd art && td2d generate props/grand-station ...   (ou td2d batch --json)
    cd .. && python3 tools/sync_td2d.py
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "art" / "assets" / "props"


# --- Petites briques ----------------------------------------------------------------------

def box(pid, mat, size, pos, rot=None, **extra):
    part = {"type": "box", "id": pid, "material": mat, "size": list(size), "position": list(pos)}
    if rot:
        part["rotation"] = list(rot)
    part.update(extra)
    return part


def cyl(pid, mat, radius, height, pos, rot=None, segments=None, **extra):
    part = {"type": "cylinder", "id": pid, "material": mat, "radius": radius, "height": height, "position": list(pos)}
    if rot:
        part["rotation"] = list(rot)
    if segments:
        part["segments"] = segments
    part.update(extra)
    return part


def cone(pid, mat, radius, height, pos, rot=None, segments=None):
    part = {"type": "cone", "id": pid, "material": mat, "radius": radius, "height": height, "position": list(pos)}
    if rot:
        part["rotation"] = list(rot)
    if segments:
        part["segments"] = segments
    return part


def sphere(pid, mat, radius, pos, **extra):
    part = {"type": "sphere", "id": pid, "material": mat, "radius": radius, "position": list(pos)}
    part.update(extra)
    return part


def torus(pid, mat, radius, tube, pos, rot=None, **extra):
    part = {"type": "torus", "id": pid, "material": mat, "radius": radius, "tube": tube, "position": list(pos)}
    if rot:
        part["rotation"] = list(rot)
    part.update(extra)
    return part


def repeat(part, count, offset):
    part["repeat"] = {"count": count, "offset": list(offset)}
    return part


def arch_window(pid, x, y, z, width, height, mat="glass", frame="limestone-dark"):
    """Fenêtre cintrée sur une façade tournée vers +z : un rectangle et un demi-disque."""
    r = width / 2.0
    rect_h = height - r
    return [
        box(pid + "-frame", frame, (width + 0.16, rect_h, 0.05), (x, y + rect_h / 2.0, z)),
        cyl(pid + "-frame-top", frame, r + 0.08, 0.05, (x, y + rect_h, z), rot=(90, 0, 0)),
        box(pid, mat, (width, rect_h, 0.07), (x, y + rect_h / 2.0, z + 0.02)),
        cyl(pid + "-top", mat, r, 0.07, (x, y + rect_h, z + 0.02), rot=(90, 0, 0)),
    ]


def arch(pid, mat, cx, cy, z, radius, thickness, depth, count=11):
    """Arc en plein cintre (demi-cercle du haut) fait de claveaux : un tore ferait le cercle entier."""
    parts = []
    length = math.pi * radius / count * 1.15
    for i in range(count):
        theta = math.pi * (i + 0.5) / count
        parts.append(box(f"{pid}-{i}", mat, (length, thickness, depth),
                         (cx + math.cos(theta) * radius, cy + math.sin(theta) * radius, z),
                         rot=(0, 0, math.degrees(theta) + 90)))
    return parts


def merlons(pid, mat, length, y, z, width=0.42, gap=0.42, depth=0.32, height=0.6, along="x", x=0.0):
    """Créneaux le long d'un rempart (axe x ou z), centrés sur 0."""
    step = width + gap
    count = max(int((length + gap) / step), 2)
    start = -(count - 1) * step / 2.0
    if along == "x":
        part = box(pid, mat, (width, height, depth), (start, y + height / 2.0, z))
        return repeat(part, count, (step, 0, 0))
    part = box(pid, mat, (depth, height, width), (x, y + height / 2.0, start))
    return repeat(part, count, (0, 0, step))


def asset(aid, description, frame, parts):
    return {
        "$schema": "../../../.td2d/schemas/asset.schema.json",
        "schemaVersion": "1.0.0",
        "id": aid,
        "type": "prop",
        "description": description,
        "frame": {"width": frame[0], "height": frame[1]},
        "directions": "d1",
        "model": {"parts": parts},
        "animation": {"fps": 10, "clips": {"idle": {"duration": 0.1}}},
    }


# --- Bâtiment voyageurs ---------------------------------------------------------------------

def grand_station():
    """22 m de façade : pavillon central (grande verrière en berceau, rosace vitrée, horloge,
    trois portes), deux ailes à fenêtres cintrées et toits d'ardoise, deux pavillons d'angle
    coiffés d'une pyramide et d'un épi doré."""
    p = []
    depth = 5.0
    front = depth / 2.0
    # Socle et marches.
    p.append(box("plinth", "stone", (22.4, 0.35, depth + 0.6), (0, 0.175, 0)))
    p.append(box("steps", "stone", (6.0, 0.18, 0.8), (0, 0.09, front + 0.6)))
    # Ailes.
    for side, sx in (("l", -1), ("r", 1)):
        cx = sx * 6.75
        p.append(box(f"wing-{side}", "limestone", (6.5, 3.6, depth - 0.4), (cx, 0.35 + 1.8, 0)))
        p.append(box(f"wing-{side}-cornice", "limestone-dark", (6.7, 0.22, depth - 0.2), (cx, 0.35 + 3.6, 0)))
        p.append(box(f"wing-{side}-base", "limestone-dark", (6.6, 0.5, depth - 0.3), (cx, 0.6, 0)))
        # Toit d'ardoise à deux pans.
        p.append(box(f"wing-{side}-roof-f", "slate", (6.7, 0.14, 1.75), (cx, 4.55, 0.95), rot=(32, 0, 0)))
        p.append(box(f"wing-{side}-roof-b", "slate", (6.7, 0.14, 1.75), (cx, 4.55, -0.95), rot=(-32, 0, 0)))
        p.append(box(f"wing-{side}-ridge", "iron-black", (6.75, 0.1, 0.14), (cx, 5.05, 0)))
        # Lucarnes.
        for i, lx in enumerate((-1.6, 1.6)):
            p.append(box(f"dormer-{side}{i}", "limestone", (0.7, 0.6, 0.5), (cx + lx, 4.35, 1.35)))
            p.append(box(f"dormer-{side}{i}-glass", "glass", (0.4, 0.38, 0.05), (cx + lx, 4.32, 1.61)))
            p.append(cone(f"dormer-{side}{i}-cap", "slate", 0.5, 0.35, (cx + lx, 4.82, 1.35), segments=4, rot=(0, 45, 0)))
        # Fenêtres cintrées.
        for i in range(4):
            wx = cx - 2.4 + i * 1.6
            p += arch_window(f"win-{side}{i}", wx, 1.05, front - 0.19, 0.8, 2.0)
    # Pavillons d'angle.
    for side, sx in (("l", -1), ("r", 1)):
        cx = sx * 10.25
        p.append(box(f"pav-{side}", "limestone", (2.3, 4.6, depth), (cx, 0.35 + 2.3, 0)))
        p.append(box(f"pav-{side}-quoin-a", "limestone-dark", (0.25, 4.6, 0.25), (cx - 1.1, 2.65, front)))
        p.append(box(f"pav-{side}-quoin-b", "limestone-dark", (0.25, 4.6, 0.25), (cx + 1.1, 2.65, front)))
        p.append(box(f"pav-{side}-cornice", "limestone-dark", (2.5, 0.25, depth + 0.2), (cx, 5.0, 0)))
        p.append(cone(f"pav-{side}-roof", "slate", 2.0, 2.2, (cx, 6.2, 0), segments=4, rot=(0, 45, 0)))
        p.append(cyl(f"pav-{side}-finial", "brass", 0.05, 0.6, (cx, 7.5, 0)))
        p.append(sphere(f"pav-{side}-finial-ball", "brass", 0.12, (cx, 7.85, 0)))
        p += arch_window(f"pav-{side}-win", cx, 1.4, front + 0.01, 1.0, 2.6)
        p.append(cyl(f"pav-{side}-oculus", "glass", 0.32, 0.06, (cx, 4.35, front + 0.03), rot=(90, 0, 0)))
        p.append(torus(f"pav-{side}-oculus-ring", "limestone-dark", 0.34, 0.06, (cx, 4.35, front + 0.04), rot=(90, 0, 0)))
    # Pavillon central : la grande verrière en berceau derrière une façade à rosace.
    hall_w = 7.2
    p.append(box("hall", "limestone", (hall_w, 4.8, depth), (0, 0.35 + 2.4, 0)))
    p.append(box("hall-pilaster-l", "limestone-dark", (0.45, 5.4, 0.3), (-hall_w / 2 + 0.1, 2.95, front + 0.1)))
    p.append(box("hall-pilaster-r", "limestone-dark", (0.45, 5.4, 0.3), (hall_w / 2 - 0.1, 2.95, front + 0.1)))
    vault_y = 5.15
    vault_r = 3.3
    p.append(cyl("vault", "glass-roof", vault_r, depth - 0.3, (0, vault_y, -0.1), rot=(90, 0, 0), segments=24))
    p.append(repeat(torus("vault-rib", "iron-black", vault_r + 0.02, 0.07, (0, vault_y, -2.1), rot=(90, 0, 0)), 5, (0, 0, 1.0)))
    p.append(box("vault-ridge", "iron-black", (0.12, 0.1, depth - 0.3), (0, vault_y + vault_r + 0.02, -0.1)))
    # Grand arc vitré de la façade (rosace) et ses rayons.
    arch_r = 2.7
    arch_y = 3.0
    p.append(cyl("rose", "glass-roof", arch_r, 0.08, (0, arch_y, front + 0.03), rot=(90, 0, 0), segments=24))
    p.append(box("rose-low", "glass-roof", (arch_r * 2, 1.6, 0.08), (0, arch_y - 0.8, front + 0.03)))
    p += arch("rose-arch", "limestone-dark", 0, arch_y, front + 0.06, arch_r + 0.12, 0.3, 0.14, count=13)
    for i, jx in enumerate((-arch_r - 0.12, arch_r + 0.12)):
        p.append(box(f"rose-jamb-{i}", "limestone-dark", (0.3, arch_y - 0.35, 0.14), (jx, 0.35 + (arch_y - 0.35) / 2, front + 0.06)))
    for i, angle in enumerate((-60, -30, 0, 30, 60)):
        # Un rayon part du centre de l'arc : centre du barreau à mi-rayon, tourné de -angle.
        a = math.radians(angle)
        p.append(box(f"rose-spoke-{i}", "iron-black", (0.07, arch_r, 0.05),
                     (math.sin(a) * arch_r / 2, arch_y + math.cos(a) * arch_r / 2, front + 0.09), rot=(0, 0, -angle)))
    p.append(box("rose-transom", "iron-black", (arch_r * 2, 0.09, 0.05), (0, arch_y, front + 0.09)))
    # Trois portes en bas du grand arc.
    for i, dx in enumerate((-1.6, 0.0, 1.6)):
        p.append(box(f"door-{i}", "panel-wood", (1.0, 1.7, 0.08), (dx, 0.35 + 0.85, front + 0.1)))
        p.append(cyl(f"door-{i}-top", "panel-wood", 0.5, 0.08, (dx, 0.35 + 1.7, front + 0.1), rot=(90, 0, 0)))
        p.append(box(f"door-{i}-handle", "brass", (0.06, 0.2, 0.05), (dx + 0.3, 1.2, front + 0.16)))
    # Attique, horloge et fronton au-dessus de l'arc.
    p.append(box("attic", "limestone", (hall_w + 0.4, 0.9, 0.6), (0, 5.6, front - 0.1)))
    p.append(box("attic-cornice", "limestone-dark", (hall_w + 0.6, 0.18, 0.75), (0, 6.1, front - 0.1)))
    p.append(cyl("clock-case", "limestone-dark", 0.95, 0.35, (0, 6.75, front - 0.05), rot=(90, 0, 0), segments=20))
    p.append(cyl("clock", "clock-face", 0.75, 0.1, (0, 6.75, front + 0.14), rot=(90, 0, 0), segments=20))
    p.append(torus("clock-rim", "brass", 0.78, 0.06, (0, 6.75, front + 0.18), rot=(90, 0, 0)))
    p.append(box("clock-hour", "iron-black", (0.08, 0.42, 0.04), (0.08, 6.88, front + 0.21), rot=(0, 0, -40)))
    p.append(box("clock-minute", "iron-black", (0.06, 0.6, 0.04), (0, 7.02, front + 0.22)))
    p.append(box("pediment-l", "limestone", (1.6, 0.3, 0.5), (-1.4, 6.45, front - 0.15), rot=(0, 0, 18)))
    p.append(box("pediment-r", "limestone", (1.6, 0.3, 0.5), (1.4, 6.45, front - 0.15), rot=(0, 0, -18)))
    p.append(cyl("crest-pole", "iron-black", 0.04, 1.2, (0, 8.0, front - 0.2)))
    p.append(box("crest-flag", "train-red", (0.8, 0.45, 0.04), (0.42, 8.35, front - 0.2)))
    # Enseigne dorée sous l'arc.
    p.append(box("sign", "panel-wood", (3.4, 0.36, 0.07), (0, 2.55, front + 0.13)))
    p.append(box("sign-band", "brass", (3.0, 0.08, 0.06), (0, 2.55, front + 0.18)))
    # Lanternes de façade.
    for i, lx in enumerate((-hall_w / 2 + 0.1, hall_w / 2 - 0.1)):
        p.append(box(f"lantern-arm-{i}", "iron-black", (0.06, 0.06, 0.4), (lx, 2.6, front + 0.35)))
        p.append(box(f"lantern-{i}", "lamp", (0.22, 0.3, 0.22), (lx, 2.45, front + 0.5)))
    return asset("props/grand-station",
                 "Gare refuge : batiment voyageurs, verriere en berceau, rosace vitree, horloge, ailes et pavillons.",
                 (380, 200), p)


# --- Remparts ---------------------------------------------------------------------------------

def rampart():
    """3 m de rempart en pierre (axe x), chemin de ronde et créneaux : se pose bout à bout."""
    p = [
        box("wall", "stone", (3.0, 2.6, 1.2), (0, 1.3, 0)),
        box("plinth", "concrete-dark", (3.0, 0.4, 1.35), (0, 0.2, 0)),
        box("band", "limestone-dark", (3.0, 0.14, 1.3), (0, 2.6, 0)),
        merlons("merlon", "stone", 3.0, 2.67, 0.45),
        box("joint", "concrete-dark", (0.06, 2.2, 0.04), (0.6, 1.4, 0.61)),
        box("joint-b", "concrete-dark", (0.06, 1.2, 0.04), (-0.9, 0.9, 0.61)),
    ]
    return asset("props/rampart", "Rempart en pierre, 3 m, chemin de ronde et creneaux.", (64, 64), p)


def rampart_side():
    """3 m de rempart en pierre dans l'axe nord-sud (bords est et ouest de la ville)."""
    p = [
        box("wall", "stone", (1.2, 2.6, 3.0), (0, 1.3, 0)),
        box("plinth", "concrete-dark", (1.35, 0.4, 3.0), (0, 0.2, 0)),
        box("band", "limestone-dark", (1.3, 0.14, 3.0), (0, 2.6, 0)),
        merlons("merlon", "stone", 3.0, 2.67, 0, along="z", x=0.0),
    ]
    return asset("props/rampart-side", "Rempart en pierre, 3 m, axe nord-sud.", (40, 76), p)


def watchtower():
    """Tour de guet carrée : pierre, créneaux en encorbellement, toit pointu d'ardoise, bannière."""
    p = [
        box("base", "stone", (3.0, 0.6, 3.0), (0, 0.3, 0)),
        box("shaft", "stone", (2.6, 5.2, 2.6), (0, 2.9, 0)),
        box("loop-a", "dark", (0.16, 0.7, 0.05), (0, 2.6, 1.31)),
        box("loop-b", "dark", (0.16, 0.7, 0.05), (0, 4.2, 1.31)),
        box("corbel", "limestone-dark", (3.1, 0.3, 3.1), (0, 5.55, 0)),
        box("parapet", "stone", (3.1, 0.5, 3.1), (0, 5.95, 0)),
        merlons("merlon-f", "stone", 3.1, 6.2, 1.4, depth=0.3),
        cone("roof", "slate", 2.1, 2.0, (0, 7.6, 0), segments=4, rot=(0, 45, 0)),
        cyl("pole", "iron-black", 0.04, 1.3, (0, 9.1, 0)),
        box("flag", "train-red", (0.9, 0.5, 0.04), (0.47, 9.45, 0)),
        box("banner", "train-red", (0.9, 1.6, 0.05), (0, 4.0, 1.33)),
        box("banner-band", "brass", (0.9, 0.12, 0.06), (0, 4.75, 1.35)),
    ]
    return asset("props/watchtower", "Tour de guet : pierre, creneaux, toit pointu d'ardoise, banniere rouge.", (64, 156), p)


def city_gate():
    """Porte fortifiée : arche de pierre, deux battants cloutés, herse relevée, deux tourelles."""
    p = [
        box("wall", "stone", (7.0, 3.2, 1.6), (0, 1.6, 0)),
        box("plinth", "concrete-dark", (7.0, 0.4, 1.8), (0, 0.2, 0)),
        box("door-l", "panel-wood", (1.25, 2.1, 0.1), (-0.64, 1.05, 0.86)),
        box("door-r", "panel-wood", (1.25, 2.1, 0.1), (0.64, 1.05, 0.86)),
        cyl("door-top", "panel-wood", 1.28, 0.1, (0, 2.1, 0.86), rot=(90, 0, 0), segments=20),
        box("door-split", "iron-black", (0.06, 2.9, 0.04), (0, 1.75, 0.93)),
        repeat(box("door-band", "iron-black", (2.5, 0.08, 0.04), (0, 0.5, 0.93)), 3, (0, 0.7, 0)),
        box("jamb-l", "limestone-dark", (0.3, 2.1, 0.2), (-1.45, 1.05, 0.86)),
        box("jamb-r", "limestone-dark", (0.3, 2.1, 0.2), (1.45, 1.05, 0.86)),
    ]
    p += arch("arch", "limestone-dark", 0, 2.1, 0.88, 1.45, 0.3, 0.2, count=9)
    p += [
        merlons("merlon", "stone", 7.0, 3.2, 0.6),
        box("banner", "train-red", (0.8, 1.5, 0.05), (0, 3.05, 0.95)),
    ]
    for side, sx in (("l", -1), ("r", 1)):
        x = sx * 3.3
        p += [
            cyl(f"turret-{side}", "stone", 1.1, 4.4, (x, 2.2, 0.1), segments=12),
            cyl(f"turret-{side}-top", "limestone-dark", 1.25, 0.35, (x, 4.55, 0.1), segments=12),
            cone(f"turret-{side}-roof", "slate", 1.3, 1.6, (x, 5.5, 0.1), segments=12),
            box(f"turret-{side}-loop", "dark", (0.14, 0.6, 0.05), (x, 2.8, 1.2)),
            sphere(f"turret-{side}-ball", "brass", 0.1, (x, 6.35, 0.1)),
        ]
    return asset("props/city-gate", "Porte fortifiee de la ville refuge : arche, battants cloutes, deux tourelles.", (160, 124), p)


# --- Quai -------------------------------------------------------------------------------------

def lamp_post():
    p = [
        cyl("foot", "iron-black", 0.16, 0.4, (0, 0.2, 0), segments=8),
        cyl("pole", "iron-black", 0.05, 2.9, (0, 1.85, 0)),
        torus("collar", "brass", 0.07, 0.03, (0, 1.2, 0)),
        box("arm", "iron-black", (1.0, 0.05, 0.05), (0, 3.1, 0)),
        box("lamp-l", "lamp", (0.2, 0.32, 0.2), (-0.45, 2.88, 0)),
        box("lamp-r", "lamp", (0.2, 0.32, 0.2), (0.45, 2.88, 0)),
        cone("cap-l", "iron-black", 0.18, 0.16, (-0.45, 3.12, 0), segments=4, rot=(0, 45, 0)),
        cone("cap-r", "iron-black", 0.18, 0.16, (0.45, 3.12, 0), segments=4, rot=(0, 45, 0)),
        sphere("finial", "brass", 0.07, (0, 3.45, 0)),
    ]
    return asset("props/lamp-post", "Lampadaire de quai a deux lanternes, fonte noire et laiton.", (40, 64), p)


def platform_clock():
    p = [
        cyl("foot", "iron-black", 0.18, 0.35, (0, 0.18, 0), segments=8),
        cyl("pole", "iron-black", 0.06, 2.6, (0, 1.6, 0)),
        cyl("case", "iron-black", 0.5, 0.32, (0, 3.2, 0), rot=(90, 0, 0), segments=18),
        cyl("face", "clock-face", 0.42, 0.06, (0, 3.2, 0.15), rot=(90, 0, 0), segments=18),
        torus("rim", "brass", 0.44, 0.04, (0, 3.2, 0.18), rot=(90, 0, 0)),
        box("hour", "iron-black", (0.05, 0.22, 0.03), (0.06, 3.27, 0.2), rot=(0, 0, -50)),
        box("minute", "iron-black", (0.04, 0.34, 0.03), (0, 3.35, 0.2)),
        sphere("finial", "brass", 0.07, (0, 3.78, 0)),
    ]
    return asset("props/platform-clock", "Horloge de quai sur colonne de fonte.", (32, 72), p)


def bench():
    p = [
        box("seat", "wood", (1.6, 0.07, 0.42), (0, 0.48, 0)),
        repeat(box("back-slat", "wood", (1.6, 0.09, 0.04), (0, 0.66, -0.19)), 3, (0, 0.13, -0.01)),
        box("leg-l", "iron-black", (0.07, 0.48, 0.44), (-0.7, 0.24, 0)),
        box("leg-r", "iron-black", (0.07, 0.48, 0.44), (0.7, 0.24, 0)),
        box("arm-l", "iron-black", (0.07, 0.05, 0.42), (-0.76, 0.66, 0)),
        box("arm-r", "iron-black", (0.07, 0.05, 0.42), (0.76, 0.66, 0)),
    ]
    return asset("props/bench", "Banc de quai en bois, pieds de fonte.", (40, 32), p)


def luggage():
    p = [
        box("trunk", "leather", (0.9, 0.5, 0.55), (0, 0.25, 0)),
        box("trunk-band", "brass", (0.92, 0.06, 0.57), (0, 0.4, 0)),
        box("case", "train-red", (0.6, 0.38, 0.3), (0.1, 0.69, 0.02), rot=(0, 12, 0)),
        box("case-handle", "dark", (0.2, 0.05, 0.05), (0.1, 0.9, 0.02)),
        box("bag", "canvas", (0.45, 0.35, 0.35), (0.72, 0.18, 0.15), rot=(0, -20, 0)),
    ]
    return asset("props/luggage", "Malles et valises de voyageurs.", (44, 36), p)


def canopy_column():
    """Colonne de fonte de la marquise du quai (le toit vitré est dessiné à part, translucide)."""
    p = [
        cyl("base", "iron-black", 0.18, 0.3, (0, 0.15, 0), segments=8),
        cyl("shaft", "iron-black", 0.08, 2.6, (0, 1.6, 0), segments=8),
        torus("ring", "brass", 0.1, 0.03, (0, 0.9, 0)),
        cone("capital", "iron-black", 0.24, 0.3, (0, 2.95, 0), rot=(180, 0, 0), segments=8),
        box("bracket", "iron-black", (0.06, 0.06, 1.4), (0, 3.05, -0.6)),
    ]
    return asset("props/canopy-column", "Colonne de fonte de la marquise du quai.", (24, 64), p)


def water_crane():
    """Grue à eau du dépôt : colonne, bras pivotant et manche de cuir (on y remplit la chaudière)."""
    p = [
        cyl("plinth", "stone", 0.45, 0.3, (0, 0.15, 0), segments=10),
        cyl("column", "iron", 0.18, 2.8, (0, 1.7, 0), segments=10),
        torus("band", "brass", 0.2, 0.04, (0, 1.0, 0)),
        cyl("arm", "iron", 0.1, 2.2, (0.95, 3.0, 0), rot=(0, 0, 90), segments=8),
        cyl("hose", "leather", 0.08, 1.1, (2.0, 2.45, 0), segments=8),
        box("wheel-hub", "iron-black", (0.08, 0.08, 0.1), (0, 2.2, 0.22)),
        torus("wheel", "train-red", 0.25, 0.04, (0, 2.2, 0.26), rot=(90, 0, 0)),
        sphere("top", "brass", 0.14, (0, 3.2, 0)),
    ]
    return asset("props/water-crane", "Grue a eau du depot, pour la chaudiere des locomotives.", (100, 68), p)


# --- Place et ville ---------------------------------------------------------------------------

def market_stall(name, awning, goods):
    """Étal : comptoir de bois, auvent rayé, caisses et marchandises."""
    p = [
        box("counter", "wood", (2.6, 0.9, 0.8), (0, 0.45, 0.3)),
        box("counter-top", "panel-wood", (2.7, 0.08, 0.9), (0, 0.94, 0.3)),
        cyl("post-fl", "wood", 0.06, 2.3, (-1.3, 1.15, 0.7)),
        cyl("post-fr", "wood", 0.06, 2.3, (1.3, 1.15, 0.7)),
        cyl("post-bl", "wood", 0.06, 2.6, (-1.3, 1.3, -0.6)),
        cyl("post-br", "wood", 0.06, 2.6, (1.3, 1.3, -0.6)),
        box("back", "panel-wood", (2.6, 1.6, 0.06), (0, 1.5, -0.62)),
        box("crate-a", "wood", (0.6, 0.5, 0.5), (-1.7, 0.25, 0.5), rot=(0, 12, 0)),
        box("crate-b", "wood", (0.5, 0.45, 0.45), (1.75, 0.23, 0.45), rot=(0, -8, 0)),
        cyl("barrel", "wood", 0.3, 0.75, (-1.75, 0.38, -0.3), segments=10),
    ]
    stripes = 7
    width = 2.9 / stripes
    for i in range(stripes):
        mat = awning if i % 2 == 0 else "awning-cream"
        x = -1.45 + width * (i + 0.5)
        p.append(box(f"awning-{i}", mat, (width, 0.06, 1.7), (x, 2.45, 0.08), rot=(-18, 0, 0)))
        p.append(box(f"valance-{i}", mat, (width, 0.28, 0.04), (x, 2.12, 0.92)))
    for i, (mat, x, z) in enumerate(goods):
        p.append(sphere(f"good-{i}", mat, 0.15, (x, 1.12, z)))
    p.append(box("sack", "canvas", (0.5, 0.55, 0.4), (1.0, 1.25, -0.25)))
    return asset(f"props/{name}", "Etal de marche : comptoir, auvent raye, caisses et marchandises.", (72, 72), p)


def fountain():
    p = [
        cyl("basin", "limestone", 1.8, 0.6, (0, 0.3, 0), segments=16),
        cyl("rim", "limestone-dark", 1.9, 0.12, (0, 0.62, 0), segments=16),
        cyl("water", "water", 1.6, 0.05, (0, 0.6, 0), segments=16),
        cyl("column", "limestone", 0.25, 1.5, (0, 1.2, 0), segments=10),
        cyl("bowl", "limestone", 0.75, 0.22, (0, 1.95, 0), segments=14),
        cyl("bowl-water", "water", 0.62, 0.04, (0, 2.06, 0), segments=14),
        cyl("spout", "limestone-dark", 0.1, 0.45, (0, 2.28, 0), segments=8),
        sphere("top", "brass", 0.14, (0, 2.55, 0)),
        cyl("jet", "water", 0.04, 0.35, (0, 2.75, 0)),
    ]
    return asset("props/fountain", "Fontaine de la place, deux vasques de pierre.", (72, 64), p)


def square_tree():
    p = [
        cyl("trunk", "dead-wood", 0.18, 2.0, (0, 1.0, 0), segments=8),
        cyl("grate", "iron-black", 0.6, 0.05, (0, 0.03, 0), segments=12),
        sphere("crown", "foliage", 1.1, (0, 2.7, 0)),
        sphere("crown-l", "leaf-dark", 0.8, (-0.7, 2.3, 0.1)),
        sphere("crown-r", "foliage", 0.75, (0.75, 2.4, -0.1)),
        sphere("crown-t", "foliage", 0.7, (0.1, 3.4, 0)),
    ]
    return asset("props/square-tree", "Arbre de la place, tronc dans sa grille de fonte.", (56, 76), p)


def planter():
    p = [
        box("box", "limestone", (1.4, 0.55, 0.6), (0, 0.28, 0)),
        box("rim", "limestone-dark", (1.5, 0.08, 0.7), (0, 0.57, 0)),
        repeat(sphere("leaf", "leaf-dark", 0.22, (-0.5, 0.7, 0)), 5, (0.25, 0, 0)),
        repeat(sphere("flower-a", "flower-red", 0.09, (-0.55, 0.88, 0.1)), 4, (0.36, 0, 0)),
        repeat(sphere("flower-b", "flower-yellow", 0.08, (-0.38, 0.86, -0.05)), 3, (0.38, 0, 0)),
        repeat(sphere("flower-c", "flower-white", 0.07, (-0.2, 0.92, 0.12)), 2, (0.45, 0, 0)),
    ]
    return asset("props/planter", "Jardiniere de pierre fleurie.", (36, 28), p)


def quarantine_tent():
    """Bureau de quarantaine : grande tente blanche à croix rouge, table et caisse de soins."""
    p = [
        box("floor", "floor-wood", (3.2, 0.1, 2.6), (0, 0.05, 0)),
        box("roof-l", "awning-cream", (1.95, 0.06, 2.8), (-0.8, 1.9, 0), rot=(0, 0, 38)),
        box("roof-r", "awning-cream", (1.95, 0.06, 2.8), (0.8, 1.9, 0), rot=(0, 0, -38)),
        box("wall-back", "awning-cream", (3.0, 1.3, 0.05), (0, 0.65, -1.35)),
        box("wall-l", "awning-cream", (0.05, 1.3, 2.7), (-1.52, 0.65, 0)),
        box("wall-r", "awning-cream", (0.05, 1.3, 2.7), (1.52, 0.65, 0)),
        cyl("pole", "wood", 0.05, 3.0, (0, 1.5, 1.45)),
        box("cross-v", "train-red", (0.22, 0.7, 0.04), (0, 1.75, 1.43)),
        box("cross-h", "train-red", (0.7, 0.22, 0.04), (0, 1.75, 1.43)),
        box("table", "wood", (1.2, 0.08, 0.6), (0.6, 0.75, 0.6)),
        box("table-leg", "wood", (1.1, 0.7, 0.5), (0.6, 0.38, 0.6)),
        box("med-box", "flower-white", (0.35, 0.25, 0.25), (0.4, 0.92, 0.6)),
        box("med-cross", "train-red", (0.12, 0.12, 0.03), (0.4, 0.94, 0.74)),
        box("cot", "canvas", (0.7, 0.35, 1.6), (-0.9, 0.25, -0.2)),
        box("flag", "flower-white", (0.6, 0.4, 0.03), (0.32, 2.85, 1.45)),
        box("flag-cross", "train-red", (0.14, 0.3, 0.035), (0.32, 2.85, 1.47)),
    ]
    return asset("props/quarantine-tent", "Bureau de quarantaine : tente blanche a croix rouge, table, lit de camp.", (72, 80), p)


ASSETS = {
    "grand-station": grand_station,
    "rampart": rampart,
    "rampart-side": rampart_side,
    "watchtower": watchtower,
    "city-gate": city_gate,
    "lamp-post": lamp_post,
    "platform-clock": platform_clock,
    "bench": bench,
    "luggage": luggage,
    "canopy-column": canopy_column,
    "water-crane": water_crane,
    "market-stall-red": lambda: market_stall("market-stall-red", "train-red",
                                             [("flower-red", -0.8, 0.3), ("toxic", -0.4, 0.45), ("bud", 0.0, 0.3), ("flower-red", 0.4, 0.45)]),
    "market-stall-green": lambda: market_stall("market-stall-green", "awning-green",
                                               [("foliage", -0.8, 0.3), ("leaf-dark", -0.4, 0.45), ("bud", 0.0, 0.3), ("foliage", 0.4, 0.45)]),
    "market-stall-blue": lambda: market_stall("market-stall-blue", "awning-blue",
                                              [("steel", -0.8, 0.3), ("brass", -0.4, 0.45), ("rust-light", 0.0, 0.3), ("steel", 0.4, 0.45)]),
    "fountain": fountain,
    "square-tree": square_tree,
    "planter": planter,
    "quarantine-tent": quarantine_tent,
}


def main() -> None:
    for name, build in ASSETS.items():
        path = PROPS / name / "asset.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n")
    print(f"{len(ASSETS)} assets dans {PROPS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
