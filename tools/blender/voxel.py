"""Voxel modelling for Steal a Chibi art. Pure Python: no Blender needed.

Models are built on the same 3/16-stud grid as the Zone 3 egg (Egg_Zone3_Blocky), then
turned into:
  * Roblox parts (greedy box merging, see `merge_boxes`) for the place file, and
  * face-culled, greedy-meshed quads (see `mesh_quads`) for Blender and FBX export.

Coordinates use Roblox axes in voxel units:
  x  the model's right is +X       y  up, feet on y = 0       z  back is +Z (models face -Z)
Voxel (i, j, k) is the cube centred on (i, j + 0.5, k), so x and z are symmetric about 0.
"""

from __future__ import annotations

import contextlib
import itertools
import math

VOXEL = 0.1875  # studs per voxel (Egg_Zone3_Blocky uses the same grid)

# The model's right/left swap when a drawing is mirrored across x = 0
MIRROR_GROUPS = {"ArmR": "ArmL", "ArmL": "ArmR", "LegR": "LegL", "LegL": "LegR"}

NEIGHBORS = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))


def hex_rgb(color: str) -> tuple[float, float, float]:
    color = color.lstrip("#")
    return tuple(int(color[i : i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_hex(rgb) -> str:
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02X}" for c in rgb)


def shade(color: str, factor: float) -> str:
    """Darken (factor < 1) or lighten toward white (factor > 1). Matches EggBuilder's tint."""
    r, g, b = hex_rgb(color)
    if factor >= 1:
        t = factor - 1
        return rgb_hex((r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t))
    return rgb_hex((r * factor, g * factor, b * factor))


def mix(a: str, b: str, t: float) -> str:
    ra, ga, ba = hex_rgb(a)
    rb, gb, bb = hex_rgb(b)
    return rgb_hex((ra + (rb - ra) * t, ga + (gb - ga) * t, ba + (bb - ba) * t))


class Mat:
    """A voxel material. `part` is the Roblox part name; game code keys effects off names
    (anything containing "Eye", "Glint" or "Pupil" keeps its colour under the Golden
    mutation), so eye materials must be named accordingly."""

    def __init__(
        self,
        key: str,
        color: str,
        part: str | None = None,
        surface: str = "Plastic",  # Plastic | Neon | Glass
        transparency: float = 0.0,
        reflectance: float = 0.0,
        tint: float | None = None,  # egg shells: recoloured in game with the cosmetic colour
        orbit: bool = False,  # spins around the model's vertical axis in game
    ):
        self.key = key
        self.color = color.upper()
        self.part = part or (key[:1].upper() + key[1:])
        self.surface = surface
        self.transparency = transparency
        self.reflectance = reflectance
        self.tint = tint
        self.orbit = orbit

    @property
    def see_through(self) -> bool:
        return self.surface == "Glass" or self.transparency > 0


class Model:
    def __init__(self, name: str, kind: str):
        self.name = name
        self.kind = kind  # "Character" | "Egg"
        self.vox: dict[tuple[int, int, int], tuple[str, str]] = {}
        self.mats: dict[str, Mat] = {}
        self.groups: dict[str, tuple[float, float, float]] = {}  # group -> joint pivot (voxel space)
        self.group = "Body"
        self.attributes: dict[str, object] = {}
        self.preview_tint = "#ADB5BD"  # shell colour used for the asset's stored colours
        self.notes: list[str] = []
        self._mirror = False

    # -- setup -----------------------------------------------------------------------
    def mat(self, key: str, color: str, **kw) -> str:
        self.mats[key] = Mat(key, color, **kw)
        return key

    def use(self, group: str, pivot: tuple[float, float, float] | None = None) -> "Model":
        """Switch the group new voxels go into. Pivot = the joint the group rotates about."""
        self.group = group
        if pivot is not None:
            self.groups[group] = pivot
        self.groups.setdefault(group, (0.0, 0.0, 0.0))
        return self

    @contextlib.contextmanager
    def mirrored(self):
        """Everything drawn inside also appears mirrored across x = 0 (ArmR <-> ArmL ...)."""
        previous = self._mirror
        self._mirror = True
        try:
            yield self
        finally:
            self._mirror = previous

    # -- primitive edits -------------------------------------------------------------
    def set(self, x: int, y: int, z: int, m: str | None):
        self._put((x, y, z), m, self.group)
        if self._mirror and x != 0:
            group = MIRROR_GROUPS.get(self.group, self.group)
            if group not in self.groups:
                px, py, pz = self.groups[self.group]
                self.groups[group] = (-px, py, pz)
            self._put((-x, y, z), m, group)

    def _put(self, p, m, group):
        if m is None:
            self.vox.pop(p, None)
        else:
            assert m in self.mats, f"{self.name}: unknown material {m}"
            self.vox[p] = (m, group)

    def get(self, x: int, y: int, z: int) -> str | None:
        entry = self.vox.get((x, y, z))
        return entry[0] if entry else None

    def box(self, x0, x1, y0, y1, z0, z1, m, fill: bool = False):
        """Fill an inclusive voxel range (None clears). fill=True only adds to empty space."""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    if not fill or (x, y, z) not in self.vox:
                        self.set(x, y, z, m)

    def front(self, x: int, y: int, z_from: int = -40, z_to: int = 40) -> int | None:
        """z of the frontmost voxel in column (x, y), or None."""
        for z in range(z_from, z_to + 1):
            if (x, y, z) in self.vox:
                return z
        return None

    def paint_front(self, x: int, y: int, m: str, only: tuple[str, ...] | None = None):
        """Recolour the frontmost voxel of column (x, y): drawing on curved faces."""
        z = self.front(x, y)
        if z is not None and (only is None or self.get(x, y, z) in only):
            self.set(x, y, z, m)

    def face(self, rows: list[str], legend: dict[str, str], top_left: tuple[int, int], only: tuple[str, ...] | None = None):
        """Pixel art painted onto the frontmost voxels, seen from the front (the model's
        right on your left). top_left is (x, y) of the first character."""
        ox, oy = top_left
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch not in ". ":
                    self.paint_front(ox - c, oy - r, legend[ch], only)

    def clear(self, x0, x1, y0, y1, z0, z1):
        self.box(x0, x1, y0, y1, z0, z1, None)

    def paint(self, x0, x1, y0, y1, z0, z1, m, only: tuple[str, ...] | None = None):
        """Recolour voxels that already exist (optionally only some materials)."""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    current = self.get(x, y, z)
                    if current is not None and (only is None or current in only):
                        self.set(x, y, z, m)

    def rbox(self, x0, x1, y0, y1, z0, z1, m, r: int = 1, flat: str = "", fill: bool = False):
        """Box with rounded (stepped) edges. `flat` lists sides left square, e.g. "y-"."""
        x0, x1 = sorted((x0, x1))
        y0, y1 = sorted((y0, y1))
        z0, z1 = sorted((z0, z1))

        def depth(v, lo, hi, axis):
            d_lo = 0 if f"{axis}-" in flat else max(0, lo + r - v)
            d_hi = 0 if f"{axis}+" in flat else max(0, v - (hi - r))
            return max(d_lo, d_hi)

        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    dx, dy, dz = depth(x, x0, x1, "x"), depth(y, y0, y1, "y"), depth(z, z0, z1, "z")
                    if dx * dx + dy * dy + dz * dz <= r * r and (not fill or (x, y, z) not in self.vox):
                        self.set(x, y, z, m)

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, m):
        """Voxels whose centres fall inside the ellipsoid (cy is a height, not a row)."""
        for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
            for y in range(math.floor(cy - ry) - 1, math.ceil(cy + ry) + 1):
                for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                    if ((x - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 + ((z - cz) / rz) ** 2 <= 1.0:
                        self.set(x, y, z, m)

    def disc(self, y, radius, m, cx=0, cz=0, ring: float | None = None):
        """Horizontal disc (or ring of width `ring`) one voxel tall."""
        reach = math.ceil(radius) + 1
        for x in range(cx - reach, cx + reach + 1):
            for z in range(cz - reach, cz + reach + 1):
                d = math.hypot(x - cx, z - cz)
                if d <= radius + 0.01 and (ring is None or d > radius - ring + 0.01):
                    self.set(x, y, z, m)

    def draw(self, rows: list[str], legend: dict[str, str | None], at: tuple[int, int, int], plane: str = "front"):
        """Pixel art on a plane. The first character of the first row lands on `at`.
        front: seen from in front of the model (the model's right, +X, is on your left)
        back:  seen from behind     left/right: seen from that side     top: seen from above,
        front of the model at the bottom of the drawing. '.' and ' ' are skipped."""
        ox, oy, oz = at
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch in ". ":
                    continue
                m = legend[ch]
                if plane == "front":
                    p = (ox - c, oy - r, oz)
                elif plane == "back":
                    p = (ox + c, oy - r, oz)
                elif plane == "right":  # viewer at +X looking at the model's right side
                    p = (ox, oy - r, oz - c)
                elif plane == "left":  # viewer at -X
                    p = (ox, oy - r, oz + c)
                elif plane == "top":
                    p = (ox - c, oy, oz - r)
                else:
                    raise ValueError(plane)
                self.set(*p, m)

    def line(self, points: list[tuple[int, int, int]], m):
        """Stair-stepped 3D line through the given points (6-connected, so it stays solid)."""
        for a, b in zip(points, points[1:]):
            p = list(a)
            self.set(*p, m)
            while tuple(p) != tuple(b):
                # step along the axis with the largest remaining distance
                axis = max(range(3), key=lambda i: abs(b[i] - p[i]))
                p[axis] += 1 if b[axis] > p[axis] else -1
                self.set(*p, m)

    # -- queries ---------------------------------------------------------------------
    def bounds(self):
        xs = [p[0] for p in self.vox]
        ys = [p[1] for p in self.vox]
        zs = [p[2] for p in self.vox]
        return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))

    def size_studs(self):
        (x0, x1), (y0, y1), (z0, z1) = self.bounds()
        return ((x1 - x0 + 1) * VOXEL, (y1 - y0 + 1) * VOXEL, (z1 - z0 + 1) * VOXEL)

    def by_group(self) -> dict[str, dict[tuple[int, int, int], str]]:
        groups: dict[str, dict] = {}
        for p, (m, g) in self.vox.items():
            groups.setdefault(g, {})[p] = m
        return groups


# -- visibility -------------------------------------------------------------------------
def exposed(gvox: dict, mats: dict[str, Mat], p, d) -> bool:
    """Is the face of voxel p in direction d visible? Glass counts as see-through."""
    other = gvox.get((p[0] + d[0], p[1] + d[1], p[2] + d[2]))
    if other is None:
        return True
    if mats[gvox[p]].see_through:
        return False  # glass hides its faces against anything solid (and against glass)
    return mats[other].see_through


def visible_set(gvox: dict, mats: dict[str, Mat]) -> set:
    return {p for p in gvox if any(exposed(gvox, mats, p, d) for d in NEIGHBORS)}


# -- greedy boxes for Roblox parts ------------------------------------------------------
SEED_ORDERS = (
    lambda p: (p[1], p[2], p[0]),
    lambda p: (p[0], p[1], p[2]),
    lambda p: (p[2], p[0], p[1]),
    lambda p: (-p[1], p[2], p[0]),
    lambda p: (abs(p[0]) + abs(p[2]), p[1]),
    lambda p: (-(abs(p[0]) + abs(p[2])), p[1]),
)


def merge_boxes(gvox: dict, mats: dict[str, Mat]) -> list[tuple[tuple[int, int, int], tuple[int, int, int], str]]:
    """Cover every visible voxel with as few boxes as possible.

    A box holds one material. It may run through hidden (fully enclosed) voxels of any
    opaque material, and may overlap other boxes of its own material, which keeps part
    counts low without ever showing a seam: different materials only meet inside the solid.
    See-through boxes never overlap anything. Several seed orders are tried; the smallest
    result wins.
    """
    best = None
    for order in SEED_ORDERS:
        boxes = _merge(gvox, mats, order)
        if best is None or len(boxes) < len(best):
            best = boxes
    return best


def _merge(gvox: dict, mats: dict[str, Mat], order) -> list:
    visible = visible_set(gvox, mats)
    hidden = set(gvox) - visible
    uncovered = set(visible)
    boxes = []

    def allowed(p, key):
        k = gvox.get(p)
        if k is None:
            return False
        if k == key:
            return (p in uncovered) if mats[key].see_through else True
        return p in hidden and not mats[key].see_through and not mats[k].see_through

    def layer_ok(lo, hi, axis, value, key):
        ranges = [range(lo[i], hi[i] + 1) for i in range(3)]
        ranges[axis] = (value,)
        return all(allowed(p, key) for p in itertools.product(*ranges))

    for seed in sorted(visible, key=order):
        if seed not in uncovered:
            continue
        key = gvox[seed]
        best = None
        for axes in itertools.permutations((0, 1, 2)):
            lo, hi = list(seed), list(seed)
            for axis in axes:
                while layer_ok(lo, hi, axis, hi[axis] + 1, key):
                    hi[axis] += 1
                while layer_ok(lo, hi, axis, lo[axis] - 1, key):
                    lo[axis] -= 1
            cells = itertools.product(*(range(lo[i], hi[i] + 1) for i in range(3)))
            gain = sum(1 for p in cells if p in uncovered and gvox[p] == key)
            volume = (hi[0] - lo[0] + 1) * (hi[1] - lo[1] + 1) * (hi[2] - lo[2] + 1)
            score = (gain, -volume)
            if best is None or score > best[0]:
                best = (score, tuple(lo), tuple(hi))
        _, lo, hi = best
        for p in itertools.product(*(range(lo[i], hi[i] + 1) for i in range(3))):
            if gvox.get(p) == key:
                uncovered.discard(p)
        boxes.append((lo, hi, key))
    return boxes


# -- greedy quads for meshes ------------------------------------------------------------
def _bounds_on_axis(axis: int, i0: int, i1: int) -> tuple[float, float]:
    # x and z voxels are centred on integers, y voxels start on integers
    if axis == 1:
        return float(i0), float(i1 + 1)
    return i0 - 0.5, i1 + 0.5


def mesh_quads(gvox: dict, mats: dict[str, Mat], select) -> list[tuple[list[tuple[float, float, float]], str]]:
    """Exposed faces of the selected materials, merged into rectangles of one material.
    Returns (corners, material) with corners counter-clockwise seen from outside."""
    quads = []
    for axis in range(3):
        b, c = (axis + 1) % 3, (axis + 2) % 3
        for sign in (1, -1):
            d = [0, 0, 0]
            d[axis] = sign
            planes: dict[int, dict[tuple[int, int], str]] = {}
            for p, key in gvox.items():
                if select(key) and exposed(gvox, mats, p, d):
                    planes.setdefault(p[axis], {})[(p[b], p[c])] = key
            for layer, cells in planes.items():
                lo_a, hi_a = _bounds_on_axis(axis, layer, layer)
                plane_coord = hi_a if sign > 0 else lo_a
                done = set()
                for (u, v) in sorted(cells):
                    if (u, v) in done:
                        continue
                    key = cells[(u, v)]
                    u1 = u
                    while (u1 + 1, v) in cells and cells[(u1 + 1, v)] == key and (u1 + 1, v) not in done:
                        u1 += 1
                    v1 = v
                    while all(
                        (uu, v1 + 1) in cells and cells[(uu, v1 + 1)] == key and (uu, v1 + 1) not in done
                        for uu in range(u, u1 + 1)
                    ):
                        v1 += 1
                    for uu in range(u, u1 + 1):
                        for vv in range(v, v1 + 1):
                            done.add((uu, vv))
                    b0, b1 = _bounds_on_axis(b, u, u1)
                    c0, c1 = _bounds_on_axis(c, v, v1)
                    corners = []
                    for bb, cc in ((b0, c0), (b1, c0), (b1, c1), (b0, c1)):
                        point = [0.0, 0.0, 0.0]
                        point[axis] = plane_coord
                        point[b] = bb
                        point[c] = cc
                        corners.append(tuple(point))
                    if sign < 0:
                        corners.reverse()
                    quads.append((corners, key))
    return quads


# -- export -----------------------------------------------------------------------------
def roblox_parts(model: Model) -> dict:
    """Plain-data description of the model as Roblox parts (consumed by tools/import-art.luau).
    Positions are in studs relative to the model origin (feet centre for characters,
    shell bottom centre for eggs)."""
    groups = []
    total = 0
    for group, gvox in model.by_group().items():
        parts = []
        for lo, hi, key in merge_boxes(gvox, model.mats):
            mat = model.mats[key]
            x0, x1 = _bounds_on_axis(0, lo[0], hi[0])
            y0, y1 = _bounds_on_axis(1, lo[1], hi[1])
            z0, z1 = _bounds_on_axis(2, lo[2], hi[2])
            color = shade(model.preview_tint, mat.tint) if mat.tint is not None else mat.color
            part = {
                "name": mat.part,
                "size": [round((x1 - x0) * VOXEL, 4), round((y1 - y0) * VOXEL, 4), round((z1 - z0) * VOXEL, 4)],
                "position": [round((x0 + x1) / 2 * VOXEL, 4), round((y0 + y1) / 2 * VOXEL, 4), round((z0 + z1) / 2 * VOXEL, 4)],
                "color": color,
                "material": {"Plastic": "SmoothPlastic", "Neon": "Neon", "Glass": "Glass"}[mat.surface],
            }
            if mat.transparency:
                part["transparency"] = mat.transparency
            if mat.reflectance:
                part["reflectance"] = mat.reflectance
            attributes = {}
            if mat.tint is not None:
                attributes["Tint"] = mat.tint
            if mat.orbit:
                attributes["Orbit"] = True
            if group == "Ornament":
                attributes["OrnamentPart"] = True
            if attributes:
                part["attributes"] = attributes
            parts.append(part)
        px, py, pz = model.groups.get(group, (0.0, 0.0, 0.0))
        groups.append({"name": group, "pivot": [px * VOXEL, py * VOXEL, pz * VOXEL], "parts": parts})
        total += len(parts)
    (x0, x1), (y0, y1), (z0, z1) = model.bounds()
    lo = (_bounds_on_axis(0, x0, x0)[0], _bounds_on_axis(1, y0, y0)[0], _bounds_on_axis(2, z0, z0)[0])
    hi = (_bounds_on_axis(0, x1, x1)[1], _bounds_on_axis(1, y1, y1)[1], _bounds_on_axis(2, z1, z1)[1])
    return {
        "name": model.name,
        "kind": model.kind,
        "voxel": VOXEL,
        "attributes": model.attributes,
        "partCount": total,
        "voxelCount": len(model.vox),
        "size": [round(v, 4) for v in model.size_studs()],
        "bounds": [[round(v * VOXEL, 4) for v in lo], [round(v * VOXEL, 4) for v in hi]],
        "previewTint": model.preview_tint,
        "groups": groups,
    }
