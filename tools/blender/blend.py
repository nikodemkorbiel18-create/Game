"""Blender side of the voxel pipeline: meshes, materials, scenes, renders and FBX export.

Blender is Z-up and looks at a model's front from -Y. A Roblox-space point (x, y, z) maps
to Blender (-x, z, y), a proper rotation, so face winding is preserved. 1 Blender unit is
1 stud.
"""

from __future__ import annotations

import math
from collections import defaultdict

import bpy  # must come first: the bpy module provides bmesh and mathutils

import bmesh
from mathutils import Vector

from voxel import VOXEL, Mat, Model, hex_rgb, mesh_quads, shade


def to_blender(p) -> Vector:
    x, y, z = p
    return Vector((-x * VOXEL, z * VOXEL, y * VOXEL))


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear(color: str) -> tuple[float, float, float, float]:
    r, g, b = hex_rgb(color)
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


# -- scene ------------------------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def collection(name: str, parent=None):
    coll = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    parent = parent or bpy.context.scene.collection
    if coll.name not in parent.children:
        parent.children.link(coll)
    return coll


# -- materials --------------------------------------------------------------------------
def _principled(name: str):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    return mat, bsdf


def material_for(cls: str, mat: Mat, tint: str | None) -> bpy.types.Material:
    """One Blender material per object class: vertex colours, neon, glass or tinted shell."""
    if mat.tint is not None:
        name = f"Vox_Tint_{shade(tint, mat.tint)[1:]}"
    elif mat.surface == "Neon":
        name = f"Vox_Neon_{mat.color[1:]}"
    elif mat.see_through:
        name = f"Vox_Glass_{mat.color[1:]}_{round(mat.transparency * 100):02d}"
    else:
        name = "Vox_VertexColor"
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    m, bsdf = _principled(name)
    nodes, links = m.node_tree.nodes, m.node_tree.links
    if mat.tint is not None:
        bsdf.inputs["Base Color"].default_value = linear(shade(tint, mat.tint))
    elif mat.surface == "Neon":
        bsdf.inputs["Base Color"].default_value = linear(mat.color)
        bsdf.inputs["Emission Color"].default_value = linear(mat.color)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    elif mat.see_through:
        bsdf.inputs["Base Color"].default_value = linear(mat.color)
        bsdf.inputs["Alpha"].default_value = max(0.25, 1 - mat.transparency)
        bsdf.inputs["Roughness"].default_value = 0.08
        bsdf.inputs["Specular IOR Level"].default_value = 0.8
        m.surface_render_method = "BLENDED"
    else:
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def class_tags(mat: Mat) -> str:
    """Suffix naming a mesh piece that needs per-part settings in Roblox (see the import
    helper): orbiting, neon colour, glass colour/transparency, shell tint factor."""
    tags = []
    if mat.orbit:
        tags.append("Orbit")
    if mat.surface == "Neon":
        tags.append(f"Neon_{mat.color[1:]}")
    elif mat.see_through:
        tags.append(f"Glass_{mat.color[1:]}_{round(mat.transparency * 100):02d}")
    if mat.tint is not None:
        tags.append(f"Tint_{round(mat.tint * 100):03d}")
    return "_".join(tags)


# -- meshes -----------------------------------------------------------------------------
def build_model(model: Model, location=(0.0, 0.0, 0.0), coll=None, tint: str | None = None, suffix: str = ""):
    """Creates an empty named after the model with one mesh object per group and class.
    Each object's origin is its group's joint pivot, so limbs can be rotated or rigged."""
    tint = tint or model.preview_tint
    coll = coll or collection(model.name + suffix)
    root = bpy.data.objects.new(model.name + suffix, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.5
    root.location = location
    root["kind"] = model.kind
    coll.objects.link(root)
    objects = []
    for group, gvox in model.by_group().items():
        by_class: dict[str, set[str]] = defaultdict(set)
        for key in set(gvox.values()):
            by_class[class_tags(model.mats[key])].add(key)
        pivot = to_blender(model.groups.get(group, (0.0, 0.0, 0.0)))
        for cls, keys in sorted(by_class.items()):
            quads = mesh_quads(gvox, model.mats, lambda k, keys=keys: k in keys)
            if not quads:
                continue
            rbx_name = group + (f"__{cls}" if cls else "")
            mesh = bpy.data.meshes.new(f"{model.name}{suffix}.{rbx_name}")
            verts, faces, colors = [], [], []
            for corners, key in quads:
                start = len(verts)
                verts.extend(to_blender(c) - pivot for c in corners)
                faces.append(tuple(range(start, start + 4)))
                mat = model.mats[key]
                # Roblox multiplies vertex colours by the part's Color: pieces whose Color is
                # set in Studio (tinted shells, neon, glass) carry white vertex colours
                plain = mat.tint is None and mat.surface == "Plastic" and not mat.see_through
                colors.append(hex_rgb(mat.color) if plain else (1.0, 1.0, 1.0))
            mesh.from_pydata([tuple(v) for v in verts], [], faces)
            attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
            for poly, color in zip(mesh.polygons, colors):
                for loop in poly.loop_indices:
                    attr.data[loop].color_srgb = (*color, 1.0)
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            bm.to_mesh(mesh)
            bm.free()
            mesh.update()
            obj = bpy.data.objects.new(f"{model.name}{suffix}.{rbx_name}", mesh)
            obj.location = pivot
            obj.parent = root
            obj["rbx_name"] = rbx_name
            obj["group"] = group
            sample = model.mats[next(iter(keys))]
            obj.data.materials.append(material_for(cls, sample, tint))
            coll.objects.link(obj)
            objects.append(obj)
    return root, objects


# -- rendering --------------------------------------------------------------------------
def setup_render(samples: int = 48, size=(1200, 1200), background: str = "#AFBBCB"):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.compression = 100
    scene.render.dither_intensity = 0.0  # dithering noise makes PNGs several times larger
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    world = bpy.data.worlds.get("Studio") or bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = linear(background)
    bg.inputs["Strength"].default_value = 0.85
    scene.world = world
    return scene


def add_lights(target=(0.0, 0.0, 2.5)):
    coll = collection("Lighting")

    def sun(name, energy, rot_deg, angle_deg, color="#FFFFFF"):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = math.radians(angle_deg)
        data.color = linear(color)[:3]
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = [math.radians(a) for a in rot_deg]
        coll.objects.link(obj)
        return obj

    sun("Key", 3.2, (50, 0, -35), 8, "#FFF4E6")
    sun("Fill", 0.9, (65, 0, 60), 30, "#DCE8FF")
    sun("Rim", 1.6, (115, 0, 160), 10, "#FFFFFF")
    return coll


def add_floor(size=200.0, color="#C3CCD8"):
    coll = collection("Lighting")
    mesh = bpy.data.meshes.new("Floor")
    h = size / 2
    mesh.from_pydata([(-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0)], [], [(0, 1, 2, 3)])
    obj = bpy.data.objects.new("Floor", mesh)
    m, bsdf = _principled("Floor")
    bsdf.inputs["Base Color"].default_value = linear(color)
    bsdf.inputs["Roughness"].default_value = 0.9
    mesh.materials.append(m)
    coll.objects.link(obj)
    return obj


def world_bounds(objects):
    bpy.context.view_layer.update()  # matrix_world is stale until the depsgraph updates
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi


def frame_camera(objects, yaw_deg=-30.0, pitch_deg=14.0, margin=1.12, aspect=1.0, name="Camera", fit_height=False):
    """Orthographic camera looking at the objects from the front (-Y), turned by yaw.
    fit_height: keep the render width and set the height to the content's proportions."""
    lo, hi = world_bounds(objects)
    center = (lo + hi) / 2
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    direction = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    cam_data = bpy.data.cameras.get(name) or bpy.data.cameras.new(name)
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.get(name) or bpy.data.objects.new(name, cam_data)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    distance = (hi - lo).length * 2 + 10
    cam.location = center + direction * distance
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam_data.shift_x = cam_data.shift_y = 0.0
    bpy.context.view_layer.update()
    # fit the projected vertices (tighter than the bounding box when the view is turned)
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for obj in objects:
        if obj.type != "MESH":
            continue
        to_camera = inv @ obj.matrix_world
        for vertex in obj.data.vertices:
            local = to_camera @ vertex.co
            xs.append(local.x)
            ys.append(local.y)
    width, height = max(xs) - min(xs), max(ys) - min(ys)
    if fit_height:
        render = bpy.context.scene.render
        render.resolution_y = max(64, round(render.resolution_x * height / width * 1.18))
        aspect = render.resolution_x / render.resolution_y
    # ortho_scale and shift both measure the image's longer side (aspect = width / height)
    if aspect >= 1:
        cam_data.ortho_scale = max(width, height * aspect) * margin
    else:
        cam_data.ortho_scale = max(width / aspect, height) * margin
    cam_data.shift_x = ((max(xs) + min(xs)) / 2) / cam_data.ortho_scale
    cam_data.shift_y = ((max(ys) + min(ys)) / 2) / cam_data.ortho_scale
    cam_data.clip_end = distance * 4
    bpy.context.scene.camera = cam
    return cam


def render(path: str):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# -- FBX --------------------------------------------------------------------------------
def _marker(name: str, location) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    s = VOXEL / 2
    mesh.from_pydata(
        [(-s, -s, -s), (s, -s, -s), (s, s, -s), (-s, s, -s), (-s, -s, s), (s, -s, s), (s, s, s), (-s, s, s)],
        [],
        [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)],
    )
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export_fbx(root, path: str):
    """Exports one model's meshes with Roblox-facing names and vertex colours. The model is
    moved to the origin first. Two tiny marker cubes, one in front of the model and one
    above it, let the Studio import helper stand it up and face it the right way whatever
    axis conversion the importer applies."""
    old_location = root.location.copy()
    root.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    children = [obj for obj in root.children if obj.type == "MESH"]
    renamed = []
    for obj in children:
        renamed.append((obj, obj.name))
    for obj, _ in renamed:
        obj.name = "__tmp__" + obj["rbx_name"]
    for obj, _ in renamed:
        obj.name = obj["rbx_name"]
    lo, hi = world_bounds(children)
    center = (lo + hi) / 2
    markers = [
        _marker("FrontMarker", (center.x, lo.y - 1.0, center.z)),
        _marker("TopMarker", (center.x, center.y, hi.z + 1.0)),
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in children + markers:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = children[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,
        mesh_smooth_type="FACE",
        colors_type="SRGB",
        add_leaf_bones=False,
        bake_anim=False,
        use_custom_props=False,
    )
    for marker in markers:
        bpy.data.objects.remove(marker, do_unlink=True)
    for obj, original in renamed:
        obj.name = "__tmp__" + original
    for obj, original in renamed:
        obj.name = original
    root.location = old_location
    bpy.context.view_layer.update()
