"""Builds the zone 7 voxel art: Blender scene, FBX meshes, Roblox part data and renders.

    pip install bpy==5.0.1            # Blender as a Python module (Python 3.11)
    python3 tools/blender/build.py               # everything
    python3 tools/blender/build.py --no-render   # skip the Cycles renders (fast)

Outputs (paths relative to the repo root):
    assets/models/zone7/Zone7.blend          all 12 models in a lineup, one collection each
    assets/models/zone7/fbx/<Model>.fbx      vertex-coloured meshes for Studio's 3D importer
    assets/models/zone7/parts/<Model>.json   Roblox part layout, read by tools/import-art.luau
    assets/models/zone7/manifest.json        names, sizes, groups and pivots for each model
    docs/art/zone7/*.png                     preview renders

Then `lune run tools/import-art` turns the part layouts into Roblox models and puts them in
StealAChibi.rbxl.
"""

from __future__ import annotations

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import zone7  # noqa: E402
from voxel import VOXEL, roblox_parts  # noqa: E402

OUT = os.path.join(ROOT, "assets", "models", "zone7")
DOCS = os.path.join(ROOT, "docs", "art", "zone7")


def log(message: str):
    print(message, flush=True)


def write_json(path: str, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=1)
        handle.write("\n")


def luau(value, indent: str = "") -> str:
    """A Python value as a Luau literal (dicts become tables with sorted keys)."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(round(value, 4)) if isinstance(value, float) else str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (list, tuple)):
        return "{ " + ", ".join(luau(v) for v in value) + " }"
    if isinstance(value, dict):
        if not value:
            return "{}"
        inner = indent + "\t"
        items = [f"{inner}{key} = {luau(value[key], inner)}," for key in sorted(value)]
        return "{\n" + "\n".join(items) + "\n" + indent + "}"
    raise TypeError(value)


def write_import_helper(manifest: list):
    """assets/models/zone7/ImportFBX.lua: the Studio command-bar helper with this set's data."""
    meta = {}
    for entry in manifest:
        meta[entry["name"]] = {
            "Kind": entry["kind"],
            "Size": entry["size"],
            "Bounds": entry["bounds"],
            "PreviewTint": entry["previewTint"],
            "Groups": entry["groups"],
            "Attributes": entry["attributes"],
        }
    with open(os.path.join(HERE, "studio_import.luau"), encoding="utf-8") as handle:
        template = handle.read()
    assert "--[[META]] {}" in template
    text = template.replace("--[[META]] {}", luau(meta))
    with open(os.path.join(OUT, "ImportFBX.lua"), "w", encoding="utf-8") as handle:
        handle.write(text)


def main():
    render = "--no-render" not in sys.argv
    started = time.time()
    characters = [build() for build in zone7.CHARACTERS]
    eggs = [build() for build in zone7.EGGS]
    descriptions = {}
    for build, model in zip(zone7.CHARACTERS + zone7.EGGS, characters + eggs):
        descriptions[model.name] = " ".join((build.__doc__ or "").split())

    # -- Roblox part layouts + manifest (no Blender needed) ---------------------------
    manifest = []
    for model in characters + eggs:
        data = roblox_parts(model)
        write_json(os.path.join(OUT, "parts", model.name + ".json"), data)
        manifest.append(
            {
                "name": model.name,
                "kind": model.kind,
                "description": descriptions[model.name],
                "size": data["size"],
                "bounds": data["bounds"],
                "previewTint": data["previewTint"],
                "parts": data["partCount"],
                "voxels": data["voxelCount"],
                "attributes": model.attributes,
                "groups": {g["name"]: g["pivot"] for g in data["groups"]},
            }
        )
        log(f"  {model.name:22s} {data['partCount']:4d} parts  {data['voxelCount']:5d} voxels  {data['size']} studs")
    write_json(os.path.join(OUT, "manifest.json"), {"voxel": VOXEL, "models": manifest})
    write_import_helper(manifest)

    # -- Blender ------------------------------------------------------------------------
    import bpy  # noqa: F401  (imported late so the JSON export works without Blender)

    import blend

    blend.reset_scene()
    scene = blend.setup_render(samples=48)
    lighting = blend.add_lights()
    floor = blend.add_floor()
    chars_coll = blend.collection("Characters")
    eggs_coll = blend.collection("Eggs")
    # each character with its egg beside it
    spacing = 7.4
    roots = {}
    objects = {}
    for index, (character, egg) in enumerate(zip(characters, eggs)):
        x = (index - (len(characters) - 1) / 2) * spacing
        coll = blend.collection(character.name, chars_coll)
        root, objs = blend.build_model(character, location=(x - 1.3, 0.0, 0.0), coll=coll)
        roots[character.name], objects[character.name] = root, objs
        coll = blend.collection(egg.name, eggs_coll)
        root, objs = blend.build_model(egg, location=(x + 2.0, -0.6, 0.0), coll=coll)
        roots[egg.name], objects[egg.name] = root, objs
    scene.render.resolution_x = 2400
    blend.frame_camera([o for objs in objects.values() for o in objs], yaw_deg=-10, pitch_deg=12, margin=1.04, fit_height=True)
    os.makedirs(OUT, exist_ok=True)
    blend_path = os.path.join(OUT, "Zone7.blend")
    bpy.context.preferences.filepaths.save_version = 0  # no Zone7.blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=True)
    log(f"Saved {os.path.relpath(blend_path, ROOT)}")

    # -- FBX ----------------------------------------------------------------------------
    fbx_dir = os.path.join(OUT, "fbx")
    os.makedirs(fbx_dir, exist_ok=True)
    for name, root in roots.items():
        blend.export_fbx(root, os.path.join(fbx_dir, name + ".fbx"))
    log(f"Exported {len(roots)} FBX files")

    if not render:
        log(f"Done in {time.time() - started:.0f}s (renders skipped)")
        return

    # -- renders ------------------------------------------------------------------------
    os.makedirs(os.path.join(DOCS, "models"), exist_ok=True)
    blend.render(os.path.join(DOCS, "lineup.png"))
    log("Rendered lineup")

    def solo(name: str, path: str, yaw: float = -30.0):
        for other, root in roots.items():
            hide = other != name
            root.hide_render = hide
            for obj in objects[other]:
                obj.hide_render = hide
        location = roots[name].location.copy()
        roots[name].location = (0.0, 0.0, 0.0)
        scene.render.resolution_x = scene.render.resolution_y = 900
        blend.frame_camera(objects[name], yaw_deg=yaw, pitch_deg=14, margin=1.1)
        blend.render(path)
        roots[name].location = location

    for name in roots:
        solo(name, os.path.join(DOCS, "models", name + ".png"))
        log(f"Rendered {name}")
    for root in roots.values():
        root.hide_render = False
    for objs in objects.values():
        for obj in objs:
            obj.hide_render = False

    # egg colour sheet: every egg in each of the zone's cosmetic colours
    for root in roots.values():
        root.hide_render = True
    for objs in objects.values():
        for obj in objs:
            obj.hide_render = True
    sheet = blend.collection("ColourSheet")
    sheet_objects = []
    for row, model in enumerate(eggs):
        for col, color in enumerate(zone7.PALETTE):
            location = ((col - 2) * 4.0, 0.0, (len(eggs) - 1 - row) * 4.2)
            _, objs = blend.build_model(model, location=location, coll=sheet, tint=color, suffix=f"_{col}")
            sheet_objects.extend(objs)
    floor.hide_render = True
    scene.render.resolution_x, scene.render.resolution_y = 1500, 1900
    blend.frame_camera(sheet_objects, yaw_deg=-24, pitch_deg=10, margin=1.04, aspect=1500 / 1900)
    blend.render(os.path.join(DOCS, "egg-colours.png"))
    log("Rendered egg colour sheet")
    log(f"Done in {time.time() - started:.0f}s")


if __name__ == "__main__":
    main()
