"""Shared voxel chibi template: about 2.5 heads tall, big anime eyes, limbs in groups.

Layout (voxel units, the model faces -Z, odd widths so x and z are symmetric about 0):

    y 24     hair top            head  x -6..6   y 12..23   z -5..5   (13 x 12 x 11)
    y 12-23  head                torso x -4..4   y 5..11    z -2..2   (9 x 7 x 5)
    y 5-11   torso, arms         arms  x 5..7    y 5..11    z -1..1   (hands y 5..6)
    y 2-4    legs                legs  x 1..4    y 2..4     z -1..1
    y 0-1    shoes                     shoes y 0..1, z -2..1 (toes forward)

Groups (each pivots about its joint, so the limbs can be rigged or animated later):
    Head (neck)  Torso (hips)  ArmR/ArmL (shoulders)  LegR/LegL (hips)
"""

from __future__ import annotations

from voxel import Model, mix

NEIGHBORS_26 = [
    (dx, dy, dz)
    for dx in (-1, 0, 1)
    for dy in (-1, 0, 1)
    for dz in (-1, 0, 1)
    if (dx, dy, dz) != (0, 0, 0)
]

HEAD = dict(x0=-6, x1=6, y0=12, y1=23, z0=-5, z1=5)
PIVOTS = {
    "Head": (0.0, 12.0, 0.0),
    "Torso": (0.0, 5.0, 0.0),
    "ArmR": (6.0, 11.5, 0.0),
    "ArmL": (-6.0, 11.5, 0.0),
    "LegR": (2.5, 5.0, 0.0),
    "LegL": (-2.5, 5.0, 0.0),
}

# Mouth shapes, rows y = 15, 14, 13, columns x = 2..-2 (seen from the front)
MOUTHS = {
    "smile": [".....", ".M.M.", "..M.."],
    "grin": [".....", ".MMM.", "..T.."],
    "flat": [".....", ".MMM.", "....."],
    "cat": [".....", "M.M.M", ".M.M."],
    "smirk": ["....M", "..MM.", "....."],
    "open": [".....", ".MMM.", ".MTM."],
    "dot": [".....", "..M..", "....."],
}


def materials(m: Model, look: dict):
    """Standard chibi materials. Part names matter: anything containing "Eye" or "Glint"
    keeps its colour under the Golden mutation."""
    eye = look["eyes"]
    m.mat("skin", look["skin"], part="Skin")
    m.mat("hair", look["hair"], part="Hair")
    m.mat("hairShade", look.get("hair_shade", mix(look["hair"], "#000000", 0.18)), part="Hair")
    m.mat("eye", eye, part="Eye")
    m.mat("eyeShine", mix(eye, "#FFFFFF", 0.42), part="EyeShine")
    m.mat("glint", "#FFFFFF", part="EyeGlint")
    m.mat("lash", look.get("lash", "#2A1E1E"), part="EyeLash")
    m.mat("blush", "#FF9AB5", part="Blush")
    m.mat("mouth", "#5A2A27", part="Mouth")
    m.mat("tongue", "#FF6F91", part="Mouth")


def head(m: Model, look: dict, mouth: str = "smile", blush: bool = True, y_offset: int = 0):
    """Skin head with a painted anime face. y_offset raises the whole head (mech suits)."""
    o = y_offset
    m.use("Head", (0.0, 12.0 + o, 0.0))
    m.rbox(-6, 6, 12 + o, 23 + o, -5, 5, "skin", r=2)
    face(m, mouth, blush, o)


def face(m: Model, mouth: str, blush: bool, o: int = 0):
    # columns run x = 6 .. -6 (the model's right is on the left of the drawing)
    rows = [
        "..LLL...LLL..",  # y 19  lashes with a little outer flick
        "...WE...WE...",  # y 18  sparkle on the same side of both eyes
        "...EE...EE...",  # y 17
        "...SS...SS...",  # y 16  lighter lower half
        ".BB.......BB." if blush else ".............",  # y 15
    ]
    legend = {"L": "lash", "W": "glint", "E": "eye", "S": "eyeShine", "B": "blush"}
    m.face(rows, legend, (6, 19 + o), only=("skin",))
    m.face(MOUTHS[mouth], {"M": "mouth", "T": "tongue"}, (2, 15 + o), only=("skin",))


def hair(
    m: Model,
    o: int = 0,
    nape: int = 14,
    sides: int = 16,
    fringe: str = "H....H.H....H",
    volume: bool = True,
):
    """Hair hugging the head: paint the scalp, then grow it one voxel outward (26-way) so
    the shell follows the rounded head with no gaps. The face window stays clear.
    fringe: pattern for the row just under the bangs (y 19), columns x = 6..-6."""
    scalp = []
    for (x, y, z), (mat, group) in list(m.vox.items()):
        if group != "Head" or mat != "skin":
            continue
        y_rel = y - o
        in_face = z <= -2 and y_rel <= 19 and abs(x) <= 5
        hair_zone = y_rel >= 20 or (z >= 1 and y_rel >= nape) or (abs(x) >= 6 and y_rel >= sides) or (
            abs(x) >= 5 and z >= -1 and y_rel >= sides
        )
        if hair_zone and not in_face:
            scalp.append((x, y, z))
    for p in scalp:
        m.set(*p, "hair")
    if not volume:
        return
    face_front = {}
    for x in range(-6, 7):
        for y in range(12 + o, 24 + o):
            face_front[(x, y)] = m.front(x, y)
    for x, y, z in scalp:
        for dx, dy, dz in NEIGHBORS_26:
            q = (x + dx, y + dy, z + dz)
            if q in m.vox:
                continue
            qx, qy, qz = q
            front = face_front.get((qx, qy))
            # keep the face window clear below the bangs
            if qy - o <= 19 and abs(qx) <= 5 and front is not None and qz < front + 1 and qz <= -2:
                continue
            if qy - o < nape - 1:
                continue
            m.set(*q, "hair")
    # darker bottom edge all round gives the hair some definition
    for (x, y, z), (mat, group) in list(m.vox.items()):
        if group == "Head" and mat == "hair" and (x, y - 1, z) not in m.vox and y - o <= 18:
            m.set(x, y, z, "hairShade")
    # fringe row hanging just in front of the face
    for c, ch in enumerate(fringe):
        x = 6 - c
        if ch == "H":
            z = face_front.get((x, 19 + o))
            if z is not None:
                m.set(x, 19 + o, z - 1, "hair")


def legs(m: Model, pants: str, shoes: str, sole: str | None = None, cuff: str | None = None):
    m.use("LegR", PIVOTS["LegR"])
    with m.mirrored():
        m.box(1, 4, 2, 4, -1, 1, pants)
        m.box(1, 4, 0, 1, -2, 1, shoes)
        if sole:
            m.box(1, 4, 0, 0, -2, 1, sole)
        if cuff:
            m.box(1, 4, 2, 2, -1, 1, cuff)


def torso(m: Model, shirt: str):
    m.use("Torso", PIVOTS["Torso"])
    m.rbox(-4, 4, 5, 11, -2, 2, shirt, r=1, flat="y- y+")


def arms(m: Model, sleeve: str, hand: str = "skin", sleeve_bottom: int = 7):
    m.use("ArmR", PIVOTS["ArmR"])
    with m.mirrored():
        m.box(5, 7, sleeve_bottom, 11, -1, 1, sleeve)
        if sleeve_bottom > 5:
            m.box(5, 7, 5, sleeve_bottom - 1, -1, 1, hand)
