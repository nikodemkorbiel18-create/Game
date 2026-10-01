"""Zone 7 (Mecha Hangar): six voxel chibis and their six Armor-Core eggs.

Characters follow docs/ART_SPEC.md (palettes, props, silhouettes). Eggs share the zone's
armor-plated shell with a glowing core, add that character's details, and carry their
rarity ornament built in: Legendary crown, Mythic horns, Cosmic orbiting stars.
The shell is tinted in game with a random zone 7 palette colour (see EggBuilder).
"""

from __future__ import annotations

import math

import chibi
from voxel import Model, mix

# zone 7 cosmetic egg palette (Config/Zones.luau) - used for preview renders
PALETTE = ["#ADB5BD", "#F8F9FA", "#FFBA08", "#4361EE", "#E5383B"]

# rarity colours (Config/Rarities.luau)
LEGENDARY = "#FFC93C"
MYTHIC = "#FF4757"
COSMIC = ("#34E7E4", "#FF4FD8")


def ring_outside(m: Model, y: int, mat: str, of: tuple[str, ...], z_min: int = -99, z_max: int = 99):
    """Wrap a one-voxel ring around whatever already exists at height y (straps, bands)."""
    added = []
    for (x, yy, z), (current, _group) in list(m.vox.items()):
        if yy != y or current not in of:
            continue
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y, z + dz)
            if q not in m.vox and z_min <= q[2] <= z_max:
                added.append(q)
    for q in added:
        m.set(*q, mat)
    return added


def spike(m: Model, base, grow, lean, mat: str, sizes=(3, 2, 1, 1)):
    """Stepped pyramid: square layers shrinking along `grow`, leaning toward `lean`.
    Each layer drifts one voxel toward the lean only while it still sits squarely on the
    layer below, so tips never end up touching by a corner (floating-looking voxels)."""
    gx, gy, gz = grow
    # the two axes across the spike, and the lean along each of them
    across = [axis for axis, g in enumerate((gx, gy, gz)) if g == 0]
    lean_across = [lean[axis] for axis in across]
    offset = [0, 0]
    previous = None
    for i, size in enumerate(sizes):
        lo, hi = -((size - 1) // 2), size // 2
        if previous is not None and i % 2 == 1:
            for k in range(2):
                trial = offset[k] + lean_across[k]
                p_lo, p_hi = previous[k]
                if trial + lo <= p_hi and trial + hi >= p_lo and trial != offset[k]:
                    offset[k] = trial
                    break
        footprint = [(offset[k] + lo, offset[k] + hi) for k in range(2)]
        for a in range(footprint[0][0], footprint[0][1] + 1):
            for b in range(footprint[1][0], footprint[1][1] + 1):
                p = list(base)
                p[0] += gx * i
                p[1] += gy * i
                p[2] += gz * i
                p[across[0]] += a
                p[across[1]] += b
                m.set(*p, mat)
        previous = footprint


# ======================================================================================
# CHARACTERS
# ======================================================================================


def bolt() -> Model:
    """Mechanic: messy orange hair, goggles pushed up, yellow tee under slate overalls,
    work gloves, oil smudge on the cheek and a big wrench held at the side."""
    look = dict(skin="#E0AC69", hair="#FF9F1C", eyes="#2B2B2B")
    m = Model("Char_Bolt", "Character")
    chibi.materials(m, look)
    m.mat("shirt", "#F9C74F", part="Shirt")
    m.mat("overalls", "#577590", part="Overalls")
    m.mat("pocket", "#46617A", part="Overalls")
    m.mat("button", "#DEE2E6", part="Button", reflectance=0.2)
    m.mat("boots", "#8B5E3C", part="Boots")
    m.mat("sole", "#3B2A20", part="Boots")
    m.mat("glove", "#4A4E54", part="Gloves")
    m.mat("belt", "#6F4E37", part="ToolBelt")
    m.mat("pouch", "#A47148", part="ToolBelt")
    m.mat("steel", "#ADB5BD", part="Wrench", reflectance=0.15)
    m.mat("steelDark", "#6C757D", part="Wrench")
    m.mat("strap", "#4A3728", part="Goggles")
    m.mat("brass", "#D4A72C", part="Goggles", reflectance=0.1)
    m.mat("lens", "#7FD8F0", part="GogglesLens")
    m.mat("smudge", "#4A4E54", part="OilSmudge")

    chibi.legs(m, "overalls", "boots", sole="sole")
    chibi.torso(m, "shirt")
    # overalls: waist, bib with pocket, straps with buttons
    m.paint(-4, 4, 5, 6, -2, 2, "overalls")
    m.paint(-2, 2, 7, 10, -2, -2, "overalls")
    m.paint(-1, 1, 8, 9, -2, -2, "pocket")
    with m.mirrored():
        m.paint(2, 2, 11, 11, -2, 2, "overalls")
        m.paint(2, 2, 7, 10, 2, 2, "overalls")
        m.paint(2, 2, 10, 10, -2, -2, "button")
    # tool belt with a pouch on the left hip
    m.paint(-4, 4, 6, 6, -2, 2, "belt")
    m.box(-4, -2, 4, 6, -3, -3, "pouch")
    m.box(-4, -2, 6, 6, -3, -3, "belt")

    # arms: short sleeves, bare forearms, work gloves
    m.use("ArmR", chibi.PIVOTS["ArmR"])
    with m.mirrored():
        m.box(5, 7, 9, 11, -1, 1, "shirt")
        m.box(5, 7, 7, 8, -1, 1, "skin")
        m.box(5, 7, 5, 6, -1, 1, "glove")
    # big wrench in the right hand, standing on its ring end
    m.use("ArmR")
    m.box(8, 8, 4, 12, 0, 0, "steel")
    m.draw(["S.S", "S.S", "SSS", ".S."], {"S": "steel"}, (9, 16, 0), "front")
    m.draw(["SSS", "S.S", "SSS"], {"S": "steelDark"}, (9, 3, 0), "front")
    m.box(8, 8, 5, 6, -1, -1, "glove")  # thumb in front of the handle
    m.box(8, 8, 5, 6, 1, 1, "glove")  # fingers behind it

    chibi.head(m, look, mouth="grin", blush=False)
    m.face(["....B"], {"B": "blush"}, (-1, 15), only=("skin",))  # left cheek blush
    m.face(["S.", ".S"], {"S": "smudge"}, (5, 16), only=("skin",))  # oil smudge, right cheek
    chibi.hair(m, fringe="H....H.H...HH")
    # goggles pushed up on the forehead: strap around the head, two lenses on the front
    ring_outside(m, 21, "strap", ("hair",))
    z = min(m.front(x, y) for x in range(-3, 4) for y in range(20, 23)) - 1
    m.draw(["FFF.FFF", "FLFFFLF", "FFF.FFF"], {"F": "brass", "L": "lens"}, (3, 22, z), "front")
    # messy tufts: chunky spikes sticking up and out in every direction
    m.use("Head")
    spike(m, (-3, 25, -1), (0, 1, 0), (-1, 0, -1), "hair", sizes=(3, 2, 1))
    spike(m, (2, 25, 1), (0, 1, 0), (1, 0, 1), "hair", sizes=(3, 2, 1, 1))
    spike(m, (4, 25, -3), (0, 1, 0), (1, 0, -1), "hair", sizes=(2, 1, 1))
    spike(m, (-2, 25, 3), (0, 1, 0), (-1, 0, 1), "hair", sizes=(3, 2, 1))
    spike(m, (0, 25, -3), (0, 1, 0), (0, 0, -1), "hair", sizes=(2, 1))
    spike(m, (8, 20, 1), (1, 0, 0), (0, 1, 0), "hair", sizes=(3, 2, 1))
    spike(m, (-8, 19, 0), (-1, 0, 0), (0, 1, -1), "hair", sizes=(3, 2, 1))
    spike(m, (0, 19, 7), (0, 0, 1), (0, -1, 0), "hair", sizes=(3, 2, 1))
    spike(m, (4, 16, 6), (0, 0, 1), (1, -1, 0), "hair", sizes=(2, 1))
    return m


def haruto() -> Model:
    """Rookie pilot: orange flight suit with white collar and zip, navy belt and boots,
    round squadron patch, pilot headset with a boom mic."""
    look = dict(skin="#F9D9C3", hair="#3E2723", eyes="#003049")
    m = Model("Char_Haruto", "Character")
    chibi.materials(m, look)
    m.mat("suit", "#F77F00", part="FlightSuit")
    m.mat("suitDark", "#D96A00", part="FlightSuit")
    m.mat("white", "#FFFFFF", part="Trim")
    m.mat("navy", "#003049", part="Trim")
    m.mat("buckle", "#DEE2E6", part="Buckle", reflectance=0.2)
    m.mat("boots", "#003049", part="Boots")
    m.mat("sole", "#14213D", part="Boots")
    m.mat("headset", "#003049", part="Headset")
    m.mat("pad", "#1B1B1E", part="Headset")
    m.mat("boom", "#6C757D", part="Headset")
    m.mat("mic", "#1B1B1E", part="Headset")
    m.mat("patch", "#003049", part="SquadronPatch")
    m.mat("star", "#FFFFFF", part="SquadronPatch")

    chibi.legs(m, "suit", "boots", sole="sole")
    m.use("LegR")
    with m.mirrored():
        m.paint(4, 4, 2, 4, -1, 1, "suitDark")  # side seam
    chibi.torso(m, "suit")
    m.paint(-3, 3, 11, 11, -2, -2, "white")  # collar
    m.paint(-1, 1, 10, 10, -2, -2, "white")
    m.paint(0, 0, 6, 9, -2, -2, "white")  # zip
    m.paint(-4, 4, 6, 6, -2, 2, "navy")  # belt
    m.paint(0, 0, 6, 6, -2, -2, "buckle")
    # squadron patch on the left chest: navy disc with a white star
    m.draw([".P.", "PSP", ".P."], {"P": "patch", "S": "star"}, (-1, 10, -3), "front")
    m.set(-3, 9, -3, "patch")
    m.set(-1, 9, -3, "patch")
    chibi.arms(m, "suit")
    m.use("ArmR")
    with m.mirrored():
        m.paint(5, 7, 7, 7, -1, 1, "white")  # cuffs
        m.paint(5, 7, 10, 11, 1, 1, "suitDark")

    chibi.head(m, look, mouth="smile")
    chibi.hair(m, fringe="H...HH.H....H")
    # headset: ear cups, band over the top, boom mic to the mouth
    m.use("Head")
    with m.mirrored():
        m.box(8, 8, 15, 18, -1, 1, "headset")
        m.box(7, 7, 15, 17, -1, 1, "pad", fill=True)
    m.line([(8, 19, 0), (8, 22, 0), (7, 24, 0), (6, 25, 0), (-6, 25, 0), (-7, 24, 0), (-8, 22, 0), (-8, 19, 0)], "headset")
    m.line([(8, 15, -2), (8, 15, -5), (7, 14, -6), (4, 14, -7)], "boom")
    m.box(2, 3, 14, 14, -7, -7, "mic")
    return m


def hive() -> Model:
    """Drone operator: mint bob, teal hoodie, drone remote held out in both hands and four
    tiny drones orbiting overhead (they spin in game)."""
    look = dict(skin="#C68642", hair="#80ED99", eyes="#22577A", hair_shade="#5CC97A")
    m = Model("Char_Hive", "Character")
    chibi.materials(m, look)
    m.mat("hoodie", "#22577A", part="Hoodie")
    m.mat("trim", "#38A3A5", part="Hoodie")
    m.mat("pants", "#2F3E46", part="Pants")
    m.mat("shoes", "#F1F3F5", part="Sneakers")
    m.mat("sole", "#57CC99", part="Sneakers")
    m.mat("remote", "#343A40", part="Remote")
    m.mat("remoteLight", "#ADB5BD", part="Remote")
    m.mat("stick", "#57CC99", part="Remote")
    m.mat("screen", "#57CC99", part="RemoteScreen", surface="Neon")
    m.mat("rotor", "#CED4DA", part="Drone", orbit=True)
    m.mat("droneBody", "#343A40", part="Drone", orbit=True)
    m.mat("droneLight", "#57CC99", part="DroneLight", surface="Neon", orbit=True)

    chibi.legs(m, "pants", "shoes", sole="sole")
    chibi.torso(m, "hoodie")
    m.paint(0, 0, 5, 11, -2, -2, "trim")  # zip
    m.paint(-4, 4, 5, 5, -2, 2, "trim")  # hem
    m.paint(-3, 3, 11, 11, -2, -2, "trim")
    m.box(-3, 3, 9, 11, 3, 3, "hoodie")  # hood bunched at the back
    m.box(-2, 2, 11, 11, 3, 3, "trim")

    # forearms out in front, holding a wide drone remote
    m.use("ArmR", chibi.PIVOTS["ArmR"])
    with m.mirrored():
        m.box(5, 7, 7, 11, -1, 1, "hoodie")
        m.box(5, 7, 7, 8, -4, -2, "hoodie")
        m.box(5, 7, 7, 8, -4, -4, "trim")  # cuffs
        m.box(5, 7, 7, 8, -5, -5, "skin")
    m.use("ArmR")
    m.box(-4, 4, 7, 8, -6, -4, "remote")
    m.box(-4, 4, 7, 7, -6, -6, "remoteLight")
    m.box(-1, 1, 9, 9, -5, -5, "screen")
    m.set(3, 9, -5, "stick")
    m.set(-3, 9, -5, "stick")
    with m.mirrored():
        m.box(4, 4, 9, 11, -4, -4, "remoteLight")  # antennas

    chibi.head(m, look, mouth="smile")
    chibi.hair(m, nape=13, sides=13, fringe="HH...H.H...HH")
    # bob: flare the ends out by one voxel
    m.use("Head")
    for (x, y, z), (mat, group) in list(m.vox.items()):
        if group == "Head" and mat in ("hair", "hairShade") and y == 13 and abs(x) >= 6:
            m.set(x + (1 if x > 0 else -1), y, z, "hairShade")
    m.paint(-8, 8, 13, 13, -6, 7, "hairShade", only=("hair",))

    # four tiny drones circling overhead
    m.use("Drones", (0.0, 27.0, 0.0))
    for index, (x, z) in enumerate(((6, -5), (-6, -5), (-6, 5), (6, 5))):
        y = (28, 30, 29, 31)[index]
        m.box(x - 1, x + 1, y, y, z - 1, z + 1, "rotor")
        m.set(x, y - 1, z, "droneBody")
        m.set(x, y - 1, z - 1, "droneLight")
    return m


def hikari() -> Model:
    """Ace pilot: white flight suit with blue panels, silver high ponytail, tinted visor
    over the eyes and a gold wing badge."""
    look = dict(skin="#FFE0CC", hair="#E9ECEF", eyes="#4361EE", hair_shade="#B4BECB")
    m = Model("Char_Hikari", "Character")
    chibi.materials(m, look)
    m.mat("suit", "#F8F9FA", part="FlightSuit")
    m.mat("blue", "#4361EE", part="Panel")
    m.mat("gold", "#FFBA08", part="WingBadge", reflectance=0.15)
    m.mat("zip", "#CED4DA", part="FlightSuit")
    m.mat("boots", "#4361EE", part="Boots")
    m.mat("sole", "#1B263B", part="Boots")
    m.mat("visor", "#4CC9F0", part="Visor", surface="Glass", transparency=0.45)
    m.mat("visorFrame", "#1B263B", part="Visor")
    m.mat("tie", "#4361EE", part="HairTie")

    chibi.legs(m, "suit", "boots", sole="sole")
    m.use("LegR")
    with m.mirrored():
        m.paint(4, 4, 2, 4, -1, 1, "blue")  # side stripes
    chibi.torso(m, "suit")
    m.paint(-4, 4, 6, 6, -2, 2, "blue")  # belt
    m.paint(-3, 3, 11, 11, -2, 2, "blue")  # collar / shoulders
    m.paint(0, 0, 7, 10, -2, -2, "zip")
    m.draw(["GG...GG", ".GGGGG.", "...G..."], {"G": "gold"}, (3, 10, -3), "front")  # wing badge
    chibi.arms(m, "suit")
    m.use("ArmR")
    with m.mirrored():
        m.paint(5, 7, 10, 11, -1, 1, "blue")  # shoulder panels
        m.paint(5, 7, 7, 7, -1, 1, "blue")  # cuffs

    chibi.head(m, look, mouth="smirk")
    chibi.hair(m, fringe="HH...H.H...HH")
    m.use("Head")
    # high ponytail: tie at the back of the crown, tail arcing up and back, then down
    m.box(-1, 1, 22, 24, 6, 7, "tie", fill=True)
    m.box(-1, 1, 23, 25, 7, 7, "tie")
    m.box(-1, 1, 25, 27, 8, 9, "hair")
    m.box(-1, 1, 24, 27, 10, 10, "hair")
    m.box(-1, 1, 18, 25, 11, 11, "hair")
    m.box(-1, 1, 18, 24, 10, 10, "hairShade", fill=True)
    m.box(-1, 1, 25, 25, 8, 9, "hairShade", fill=True)
    m.box(0, 0, 14, 17, 11, 11, "hair")
    m.box(0, 0, 15, 17, 12, 12, "hairShade")
    m.set(0, 27, 7, "hair")
    # sleek tinted visor across the eyes, frame along the top and back along the sides
    for x in range(-4, 5):
        for y in range(16, 19):
            m.set(x, y, m.front(x, y) - 1, "visor")
    m.box(-4, 4, 19, 19, -6, -6, "visorFrame")
    with m.mirrored():
        m.box(5, 5, 17, 19, -6, -6, "visorFrame")
        m.box(7, 7, 17, 17, -4, 1, "visorFrame")
    return m


def admiral_gotetsu() -> Model:
    """Iron admiral: navy greatcoat with gold epaulettes and buttons, white peaked cap,
    grey hair and moustache, stern brows, and a mechanical right arm with a glowing joint."""
    look = dict(skin="#E0AC69", hair="#ADB5BD", eyes="#14213D")
    m = Model("Char_AdmiralGotetsu", "Character")
    chibi.materials(m, look)
    m.mat("coat", "#14213D", part="Greatcoat")
    m.mat("coatDark", "#0B1324", part="Greatcoat")
    m.mat("gold", "#FCA311", part="GoldTrim", reflectance=0.15)
    m.mat("goldDark", "#D4880F", part="GoldTrim")
    m.mat("boots", "#1B1B1E", part="Boots")
    m.mat("cap", "#F8F9FA", part="AdmiralCap")
    m.mat("capBand", "#1B1B1E", part="AdmiralCap")
    m.mat("steel", "#ADB5BD", part="MechArm", reflectance=0.25)
    m.mat("steelDark", "#5C636A", part="MechArm")
    m.mat("joint", "#4CC9F0", part="MechJoint", surface="Neon")
    m.mat("brow", "#8D949A", part="Hair")

    chibi.legs(m, "coat", "boots")
    chibi.torso(m, "coat")
    # coat skirt over the legs, open down the front
    m.use("Torso")
    m.rbox(-5, 5, 2, 5, -3, 3, "coat", r=1, flat="y- y+", fill=True)
    m.paint(0, 0, 2, 5, -3, -3, "coatDark")
    m.paint(-5, 5, 2, 2, -3, 3, "coatDark", only=("coat",))
    with m.mirrored():
        for y in (6, 8, 10):
            m.paint(2, 2, y, y, -2, -2, "gold")
    m.paint(-4, 4, 5, 5, -2, 2, "coatDark", only=("coat",))

    # arms: left in a coat sleeve with a gold cuff, right mechanical
    m.use("ArmL", chibi.PIVOTS["ArmL"])
    m.box(-7, -5, 7, 11, -1, 1, "coat")
    m.box(-7, -5, 7, 7, -1, 1, "gold")
    m.box(-7, -5, 5, 6, -1, 1, "skin")
    m.use("ArmR", chibi.PIVOTS["ArmR"])
    m.box(5, 7, 10, 11, -1, 1, "coat")
    m.box(5, 7, 9, 9, -1, 1, "steel")
    m.box(5, 7, 8, 8, -1, 1, "joint")
    m.box(5, 7, 6, 7, -1, 1, "steel")
    m.box(5, 7, 6, 6, -1, 1, "steelDark")
    m.box(5, 7, 5, 5, -1, 1, "steel")
    for p in ((5, 4, -1), (7, 4, -1), (6, 4, 1)):
        m.set(*p, "steelDark")  # claw fingers
    m.set(7, 10, -1, "joint")  # shoulder light
    # gold epaulettes with fringe on both shoulders
    with m.mirrored():
        m.use("ArmR")
        m.box(5, 8, 12, 12, -1, 1, "gold")
        m.box(8, 8, 10, 11, -1, 1, "goldDark")
        m.set(8, 10, 0, "gold")

    chibi.head(m, look, mouth="flat", blush=False)
    m.face(["..BBB....BBB.", ".....B.B....."], {"B": "brow"}, (6, 20), only=("skin",))
    chibi.hair(m, fringe=".............")
    m.use("Head")
    # moustache
    for x in (-3, -2, -1, 1, 2, 3):
        m.set(x, 15, m.front(x, 15) - 1, "hair")
    with m.mirrored():
        m.set(3, 14, m.front(3, 14) - 1, "hair")
    # peaked cap: black band, wide white crown, gold cord and emblem, black brim
    ring_outside(m, 22, "capBand", ("hair",))
    ring_outside(m, 23, "capBand", ("hair",))
    m.rbox(-8, 8, 24, 25, -8, 7, "cap", r=2, flat="y-")
    front = min(z for (x, y, z) in m.vox if y == 23 and m.vox[(x, y, z)][0] == "capBand")
    m.box(-4, 4, 23, 23, front, front, "gold")
    m.box(-5, 5, 21, 21, front - 1, front - 1, "capBand")
    m.box(-4, 4, 21, 21, front - 2, front - 2, "capBand")
    m.draw([".G.", "GGG", ".G."], {"G": "gold"}, (1, 25, front - 2), "front")
    return m


def daichi() -> Model:
    """Colossus pilot in a tiny mech suit: spiky-haired chibi head poking out of a boxy red
    suit with white plates, a glass cockpit, big yellow fists and a back thruster."""
    look = dict(skin="#F1C27D", hair="#2B2B2B", eyes="#2B2B2B", hair_shade="#202024")
    m = Model("Char_Daichi", "Character")
    chibi.materials(m, look)
    m.mat("red", "#E5383B", part="MechSuit")
    m.mat("redDark", "#B21E2F", part="MechSuit")
    m.mat("white", "#F8F9FA", part="ArmorPlate")
    m.mat("yellow", "#FFBA08", part="Fist")
    m.mat("knuckle", "#D18F00", part="Fist")
    m.mat("dark", "#343A40", part="Joint")
    m.mat("sole", "#212529", part="Joint")
    m.mat("glass", "#8ECAE6", part="Cockpit", surface="Glass", transparency=0.35)
    m.mat("panel", "#1B263B", part="CockpitPanel")
    m.mat("lightG", "#57CC99", part="CockpitLight", surface="Neon")
    m.mat("lightY", "#FFD60A", part="SuitLight", surface="Neon")
    m.mat("thruster", "#495057", part="Thruster")
    m.mat("flame", "#FF8800", part="ThrusterFlame", surface="Neon")

    # stubby mech legs
    m.use("LegR", (3.5, 5.0, 0.0))
    with m.mirrored():
        m.box(1, 6, 0, 1, -3, 2, "dark")
        m.box(1, 6, 0, 0, -3, 2, "sole")
        m.box(2, 5, 2, 4, -2, 2, "red")
        m.box(2, 5, 3, 4, -3, -3, "white")  # knee plates
    # boxy suit body
    m.use("Torso", (0.0, 5.0, 0.0))
    m.rbox(-6, 6, 5, 14, -4, 4, "red", r=1)
    m.box(-5, 5, 9, 13, -4, -4, "white")  # chest plate
    m.paint(-6, 6, 9, 13, -4, -4, "white", only=("red",))
    m.box(-2, 2, 10, 12, -4, -4, "panel")
    m.set(-1, 10, -4, "lightG")
    m.set(1, 11, -4, "lightY")
    m.box(-2, 2, 10, 12, -5, -5, "glass")
    m.box(-3, 3, 13, 13, -5, -5, "white")
    for x in range(-6, 7):
        m.paint(x, x, 6, 6, -4, 4, "yellow" if x % 2 == 0 else "dark", only=("red",))  # hazard stripe
    m.paint(-6, 6, 5, 5, -4, 4, "redDark", only=("red",))
    with m.mirrored():
        m.set(5, 14, -4, "lightY")
    m.box(-4, 4, 15, 15, -3, 3, "dark")  # collar the head pokes out of
    m.box(-3, 3, 7, 13, 5, 6, "thruster")
    with m.mirrored():
        m.box(1, 2, 5, 6, 5, 6, "dark")
        m.box(1, 2, 4, 4, 5, 6, "flame")
    m.box(-3, 3, 13, 13, 5, 6, "white")
    # arms: white shoulder pads, red arms, big yellow fists
    m.use("ArmR", (8.5, 13.0, 0.0))
    with m.mirrored():
        m.rbox(7, 10, 12, 14, -2, 2, "white", r=1)
        m.box(8, 9, 8, 11, -1, 1, "red")
        m.box(7, 10, 4, 7, -2, 1, "yellow")
        m.box(7, 10, 6, 6, -2, -2, "knuckle")

    chibi.head(m, look, mouth="open", y_offset=4)
    chibi.hair(m, o=4, fringe="H.H..H.H..H.H")
    # a few big, tall anime spikes read better in black than many small ones
    m.use("Head")
    spike(m, (0, 29, -2), (0, 1, 0), (0, 0, -1), "hair", sizes=(5, 3, 3, 2, 1, 1))
    with m.mirrored():
        spike(m, (4, 29, 0), (0, 1, 0), (1, 0, 0), "hair", sizes=(4, 3, 2, 2, 1))
        spike(m, (8, 24, 1), (1, 0, 0), (0, 1, 0), "hair", sizes=(4, 3, 2, 1))
    spike(m, (0, 29, 3), (0, 1, 0), (0, 0, 1), "hair", sizes=(4, 3, 2, 1))
    spike(m, (0, 22, 7), (0, 0, 1), (0, -1, 0), "hair", sizes=(4, 3, 2, 1))
    return m


CHARACTERS = [bolt, haruto, hive, hikari, admiral_gotetsu, daichi]


# ======================================================================================
# EGGS
# ======================================================================================

EGG_HEIGHT, EGG_RADIUS, EGG_WIDEST = 16, 5.5, 0.4


def egg_radius(row: int) -> float:
    """Egg profile: wider below the middle, like the Zone 3 egg (11 x 16 x 11)."""
    yc = row + 0.5
    split = EGG_WIDEST * EGG_HEIGHT
    t = (split - yc) / split if yc < split else (yc - split) / (EGG_HEIGHT - split)
    return EGG_RADIUS * math.sqrt(max(0.0, 1 - t * t))


def armor_core_egg(name: str, core: str, preview: str) -> Model:
    """The shared zone 7 shell: tinted egg, two riveted armor bands, a framed glowing core."""
    m = Model(name, "Egg")
    m.preview_tint = preview
    m.attributes["ShellHeight"] = EGG_HEIGHT * 0.1875
    m.mat("shell", preview, part="Shell", tint=1.0)
    m.mat("shellDark", preview, part="Shell", tint=0.8)
    m.mat("shine", "#FFFFFF", part="Shine")
    m.mat("armor", "#495057", part="ArmorPlate")
    m.mat("rivet", "#CED4DA", part="Rivet", reflectance=0.2)
    m.mat("frame", "#343A40", part="CoreFrame")
    m.mat("core", core, part="Core", surface="Neon")
    m.use("Egg", (0.0, EGG_HEIGHT / 2, 0.0))
    for row in range(EGG_HEIGHT):
        m.disc(row, egg_radius(row), "shell")
    m.paint(-6, 6, 0, 1, -6, 6, "shellDark")
    # armor bands with rivets on the front
    for row in (3, 10):
        m.disc(row, egg_radius(row) + 1.0, "armor", ring=1.6)
    for x, row in ((-4, 3), (0, 3), (4, 3), (-3, 10), (0, 10), (3, 10)):
        z = m.front(x, row)
        if z is not None:
            m.set(x, row, z, "rivet")
    # recessed core in a raised frame
    for x in range(-2, 3):
        for row in range(4, 9):
            z = m.front(x, row)
            if abs(x) == 2 or row in (4, 8):
                m.set(x, row, z - 1, "frame")
            else:
                m.set(x, row, z, "core")
    # shine streak, upper front on the model's right (like the Zone 3 egg)
    for x, row in ((3, 12), (3, 13), (2, 14)):
        m.paint_front(x, row, "shine", only=("shell",))
    return m


def add_crown(m: Model):
    """Legendary: gold crown with a red gem, sitting on the egg's top."""
    m.mat("crown", LEGENDARY, part="Crown", reflectance=0.15)
    m.mat("crownDark", "#E0A400", part="Crown")
    m.mat("gem", "#E63946", part="CrownGem")
    m.use("Ornament", (0.0, EGG_HEIGHT / 2, 0.0))
    top = EGG_HEIGHT - 1
    for x in range(-2, 3):
        for z in range(-2, 3):
            if abs(x) == 2 or abs(z) == 2:
                m.set(x, top, z, "crownDark")
                m.set(x, top + 1, z, "crown")
                if x % 2 == 0 and z % 2 == 0:
                    m.set(x, top + 2, z, "crown")
    m.set(0, top, -2, "gem")
    m.attributes["Ornament"] = "Crown"


def add_horns(m: Model):
    """Mythic: curved red horns and a spike on top."""
    m.mat("horn", MYTHIC, part="Horn")
    m.mat("hornBase", "#C9184A", part="Horn")
    m.use("Ornament", (0.0, EGG_HEIGHT / 2, 0.0))
    top = EGG_HEIGHT - 1
    with m.mirrored():
        m.box(2, 2, top, top, -1, 1, "hornBase")
        m.box(3, 3, top + 1, top + 1, -1, 1, "hornBase")
        m.box(3, 3, top + 2, top + 2, -1, 0, "horn")
        m.box(4, 4, top + 3, top + 3, -1, 0, "horn")
        m.set(4, top + 4, -1, "horn")
    m.set(0, top + 1, 0, "hornBase")
    m.set(0, top + 2, 0, "horn")
    m.set(0, top + 3, 0, "horn")
    m.attributes["Ornament"] = "Horns"


def add_stars(m: Model):
    """Cosmic: three neon stars orbiting the egg (they spin in game)."""
    m.mat("starA", COSMIC[0], part="OrbitStar", surface="Neon", orbit=True)
    m.mat("starB", COSMIC[1], part="OrbitStar", surface="Neon", orbit=True)
    m.use("Ornament", (0.0, EGG_HEIGHT / 2, 0.0))
    for index, (angle, row) in enumerate(((20, 4), (140, 9), (260, 13))):
        cx = round(8 * math.cos(math.radians(angle)))
        cz = round(8 * math.sin(math.radians(angle)))
        mat = "starA" if index % 2 == 0 else "starB"
        for dx, dy, dz in ((0, 0, 0), (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            m.set(cx + dx, row + dy, cz + dz, mat)
    m.attributes["Ornament"] = "Stars"


def egg_bolt() -> Model:
    """Goggles strapped round the top, a wrench on the side, an oil smudge, amber core, crown."""
    m = armor_core_egg("Egg_Bolt", "#FFB703", PALETTE[0])
    m.mat("strap", "#4A3728", part="Goggles")
    m.mat("brass", "#D4A72C", part="Goggles", reflectance=0.1)
    m.mat("lens", "#7FD8F0", part="GogglesLens")
    m.mat("steel", "#ADB5BD", part="Wrench", reflectance=0.15)
    m.mat("steelDark", "#6C757D", part="Wrench")
    m.mat("smudge", "#343A40", part="OilSmudge")
    # goggles strapped round the top of the egg
    ring_outside(m, 12, "strap", ("shell",))
    for x0 in (3, -1):
        z = min(m.front(x, y) for x in range(x0 - 2, x0 + 1) for y in range(11, 14)) - 1
        m.draw(["FFF", "FLF", "FFF"], {"F": "brass", "L": "lens"}, (x0, 13, z), "front")
    # wrench strapped to the right side
    m.box(6, 6, 2, 8, 0, 0, "steel")
    m.draw(["S.S", "S.S", "SSS", ".S."], {"S": "steel"}, (6, 12, 1), "right")
    m.box(6, 6, 1, 1, -1, 1, "steelDark")
    # oil smudge, lower left
    for x, row in ((-3, 5), (-2, 6), (-3, 6)):
        m.paint_front(x, row, "smudge", only=("shell",))
    add_crown(m)
    return m


def egg_haruto() -> Model:
    """Pilot headset with ear cups and a boom mic, squadron patch, orange core, crown."""
    m = armor_core_egg("Egg_Haruto", "#F77F00", PALETTE[1])
    m.mat("headset", "#003049", part="Headset")
    m.mat("boom", "#6C757D", part="Headset")
    m.mat("mic", "#1B1B1E", part="Headset")
    m.mat("patch", "#003049", part="SquadronPatch")
    m.mat("star", "#FFFFFF", part="SquadronPatch")
    # ear cups on both sides, band round the back, boom mic to the front
    with m.mirrored():
        m.box(6, 7, 7, 9, -1, 1, "headset")
    ring_outside(m, 8, "headset", ("shell", "armor"), z_min=1)
    m.line([(6, 7, -2), (6, 6, -4), (4, 5, -6)], "boom")
    m.set(3, 5, -6, "mic")
    # squadron patch above the core
    z = min(m.front(x, y) for x in range(-1, 2) for y in range(11, 14)) - 1
    m.draw([".P.", "PSP", ".P."], {"P": "patch", "S": "star"}, (1, 13, z), "front")
    add_crown(m)
    return m


def egg_hive() -> Model:
    """Two tiny drones circling it, a little remote badge, mint core, horns."""
    m = armor_core_egg("Egg_Hive", "#57CC99", PALETTE[3])
    m.mat("rotor", "#CED4DA", part="Drone", orbit=True)
    m.mat("droneBody", "#343A40", part="Drone", orbit=True)
    m.mat("droneLight", "#57CC99", part="DroneLight", surface="Neon", orbit=True)
    m.mat("panel", "#343A40", part="Remote")
    m.mat("button", "#80ED99", part="Remote")
    # two tiny drones circling the egg
    m.use("Egg")
    for x, row, z in ((8, 12, 2), (-8, 7, -2)):
        m.box(x - 1, x + 1, row, row, z - 1, z + 1, "rotor")
        m.set(x, row - 1, z, "droneBody")
        m.set(x, row - 1, z - 1, "droneLight")
    # little remote badge above the core
    z = min(m.front(x, y) for x in range(-2, 3) for y in range(11, 13)) - 1
    m.draw(["PPPPP", "PB.BP"], {"P": "panel", "B": "button"}, (2, 12, z), "front")
    m.set(0, 11, z, "panel")
    add_horns(m)
    return m


def egg_hikari() -> Model:
    """Tinted visor band, gold wing badge, silver ponytail plume, blue core, horns."""
    m = armor_core_egg("Egg_Hikari", "#4361EE", PALETTE[1])
    m.mat("visor", "#4CC9F0", part="Visor", surface="Glass", transparency=0.45)
    m.mat("visorFrame", "#1B263B", part="Visor")
    m.mat("gold", "#FFBA08", part="WingBadge", reflectance=0.15)
    m.mat("plume", "#E9ECEF", part="Ponytail")
    m.mat("plumeShade", "#C5CBD3", part="Ponytail")
    m.mat("tie", "#4361EE", part="Ponytail")
    # tinted visor band across the upper front
    for x in range(-3, 4):
        for row in (11, 12):
            m.set(x, row, m.front(x, row) - 1, "visor")
    with m.mirrored():
        m.set(4, 11, m.front(4, 11) - 1, "visorFrame")
        m.set(4, 12, m.front(4, 12) - 1, "visorFrame")
    # gold wing badge on the lower band
    z = min(m.front(x, 3) for x in range(-2, 3)) - 1
    m.draw(["GG.GG", ".GGG."], {"G": "gold"}, (2, 3, z), "front")
    # silver ponytail plume streaming off the back
    m.box(0, 0, 13, 14, 4, 4, "tie")
    m.box(0, 0, 13, 15, 5, 5, "plume")
    m.box(0, 0, 11, 14, 6, 6, "plume")
    m.box(0, 0, 8, 12, 7, 7, "plume")
    m.box(0, 0, 8, 10, 6, 6, "plumeShade", fill=True)
    add_horns(m)
    return m


def egg_gotetsu() -> Model:
    """Admiral's peaked cap, gold epaulettes and buttons, cyan core, orbiting stars."""
    m = armor_core_egg("Egg_AdmiralGotetsu", "#4CC9F0", PALETTE[3])
    m.mat("cap", "#F8F9FA", part="AdmiralCap")
    m.mat("capBand", "#1B1B1E", part="AdmiralCap")
    m.mat("gold", "#FCA311", part="GoldTrim", reflectance=0.15)
    m.mat("goldDark", "#D4880F", part="GoldTrim")
    # peaked cap on top
    m.rbox(-4, 4, 15, 16, -4, 4, "cap", r=1, flat="y-")
    m.box(-3, 3, 14, 14, -3, 3, "capBand", fill=True)
    ring_outside(m, 14, "capBand", ("shell", "capBand"))
    z = min(z for (x, y, z), (mat, _g) in m.vox.items() if y == 14 and mat == "capBand")
    m.box(-2, 2, 13, 13, z - 1, z - 1, "capBand")
    m.box(-2, 2, 14, 14, z, z, "gold")
    m.set(0, 16, -5, "gold")
    # epaulettes on the shoulders, gold buttons down the front
    with m.mirrored():
        m.box(5, 7, 10, 10, -1, 1, "gold")
        m.box(7, 7, 8, 9, -1, 1, "goldDark")
        m.set(7, 9, 0, "gold")
    for row in (1, 2):
        for x in (-1, 1):
            m.paint_front(x, row, "gold")
    add_stars(m)
    return m


def egg_daichi() -> Model:
    """Glass cockpit, mini yellow fists, back thruster, spiky hair tuft, yellow core, orbiting stars."""
    m = armor_core_egg("Egg_Daichi", "#FFD60A", PALETTE[4])
    m.mat("white", "#F8F9FA", part="ArmorPlate")
    m.mat("glass", "#8ECAE6", part="Cockpit", surface="Glass", transparency=0.35)
    m.mat("panel", "#1B263B", part="CockpitPanel")
    m.mat("light", "#57CC99", part="CockpitLight", surface="Neon")
    m.mat("yellow", "#FFBA08", part="Fist")
    m.mat("knuckle", "#D18F00", part="Fist")
    m.mat("thruster", "#495057", part="Thruster")
    m.mat("flame", "#FF8800", part="ThrusterFlame", surface="Neon")
    m.mat("hair", "#2B2B2B", part="Hair")
    # glass cockpit window above the core
    for x in range(-2, 3):
        for row in (11, 12):
            z = m.front(x, row)
            m.set(x, row, z, "panel")
            m.set(x, row, z - 1, "glass")
    m.set(-1, 11, m.front(-1, 11) + 1, "light")
    m.box(-3, 3, 13, 13, m.front(0, 13) - 1, m.front(0, 13) - 1, "white")
    # mini fists on the sides, thruster on the back
    with m.mirrored():
        m.box(6, 8, 4, 6, -1, 1, "yellow")
        m.box(6, 8, 5, 5, -1, -1, "knuckle")
    m.box(-2, 2, 4, 9, 6, 6, "thruster")
    with m.mirrored():
        m.box(1, 1, 3, 3, 6, 6, "flame")
    # spiky hair tuft poking out of the top, between the stars
    spike(m, (0, 16, 0), (0, 1, 0), (0, 0, -1), "hair", sizes=(3, 2, 1, 1))
    with m.mirrored():
        spike(m, (2, 15, 1), (0, 1, 0), (1, 0, 0), "hair", sizes=(2, 1, 1))
    add_stars(m)
    return m


EGGS = [egg_bolt, egg_haruto, egg_hive, egg_hikari, egg_gotetsu, egg_daichi]


def all_models() -> list[Model]:
    return [build() for build in CHARACTERS] + [build() for build in EGGS]
