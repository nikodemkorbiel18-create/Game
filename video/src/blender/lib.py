"""Shared Blender helpers: materials, bevelled primitives, room, lights, camera, props.

Coordinates: helpers take three.js-style values so scene code ports directly:
  B(x, y, z) -> Blender (x, -z, y)   (y-up -> z-up, a proper rotation)
  box(w, h, d) -> Blender dims (w, d, h)
"""
import bpy, bmesh, math
from mathutils import Vector, Euler, Matrix

FONT_SERIF = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
PALETTE = ['#c4492f', '#2f6f9f', '#e09a2d', '#3d8a5a', '#8c3b6b', '#d9622b', '#5b6b7a', '#b8322a', '#1f7a8c', '#e0b33a']


def B(x, y, z):
    return Vector((x, -z, y))


def hexrgb(h, a=1.0):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]  # sRGB -> linear
    return (*c, a)


# ---------------------------------------------------------------- scene setup
def reset(res=(576, 1024), samples=32):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_adaptive_sampling = True
    s.cycles.adaptive_threshold = 0.02
    s.cycles.use_denoising = True
    try:
        s.cycles.denoiser = 'OPENIMAGEDENOISE'
        s.cycles.denoising_input_passes = 'RGB_ALBEDO_NORMAL'
        s.cycles.denoising_quality = 'HIGH'
    except Exception:
        pass
    s.cycles.max_bounces = 8
    s.cycles.diffuse_bounces = 3
    s.cycles.glossy_bounces = 3
    s.cycles.transmission_bounces = 6
    s.cycles.transparent_max_bounces = 6
    s.cycles.caustics_reflective = False
    s.cycles.caustics_refractive = False
    s.cycles.sample_clamp_indirect = 6
    s.render.use_persistent_data = True
    s.render.resolution_x, s.render.resolution_y = res
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'PNG'
    try:
        s.view_settings.view_transform = 'AgX'
        s.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        try:
            s.view_settings.look = 'Medium High Contrast'
        except Exception:
            pass
    s.view_settings.exposure = 0.35
    w = bpy.data.worlds.new('world')
    s.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get('Background') or w.node_tree.nodes.new('ShaderNodeBackground')
    bg.inputs['Color'].default_value = hexrgb('#e9dcc6')
    bg.inputs['Strength'].default_value = 0.8
    return s


COLL = None


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


# ---------------------------------------------------------------- materials
_mats = {}


def _new_mat(name):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    p = nt.nodes.get('Principled BSDF')
    if p is None:
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        p = nt.nodes.new('ShaderNodeBsdfPrincipled')
        o = nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(p.outputs[0], o.inputs['Surface'])
    return m, nt, p


def setin(p, name, v):
    if name in p.inputs:
        p.inputs[name].default_value = v


def mat(color, rough=0.5, metal=0.0, coat=0.0, emit=None, emit_s=0.0, key=None, transmission=0.0, alpha=1.0):
    k = key or (color, rough, metal, coat, emit, emit_s, transmission, alpha)
    if k in _mats:
        return _mats[k]
    m, nt, p = _new_mat('m%d' % len(_mats))
    setin(p, 'Base Color', hexrgb(color))
    setin(p, 'Roughness', rough)
    setin(p, 'Metallic', metal)
    setin(p, 'Coat Weight', coat)
    setin(p, 'Coat Roughness', 0.08)
    if transmission:
        setin(p, 'Transmission Weight', transmission)
        setin(p, 'IOR', 1.45)
    if emit:
        setin(p, 'Emission Color', hexrgb(emit))
        setin(p, 'Emission Strength', emit_s)
    if alpha < 1:
        setin(p, 'Alpha', alpha)
    _mats[k] = m
    return m


def _coords(nt, scale=1.0):
    tc = nt.nodes.new('ShaderNodeTexCoord')
    mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (scale, scale, scale)
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    return mp


def wood(c1='#7a4a26', c2='#a8703f', rough=0.42, scale=1.0, grain_axis='Z', coat=0.15, key=None, ring=2.0):
    """Procedural straight-grain wood: fine streaks along the grain + broad colour drift,
    offset per object (Object Info random) so shared meshes don't repeat."""
    k = key or ('wood', c1, c2, rough, scale, grain_axis, coat)
    if k in _mats:
        return _mats[k]
    m, nt, p = _new_mat('wood%d' % len(_mats))
    tc = nt.nodes.new('ShaderNodeTexCoord')
    oi = nt.nodes.new('ShaderNodeObjectInfo')
    off = nt.nodes.new('ShaderNodeVectorMath'); off.operation = 'MULTIPLY_ADD'
    nt.links.new(tc.outputs['Object'], off.inputs[0])
    off.inputs[1].default_value = (scale, scale, scale)
    rnd = nt.nodes.new('ShaderNodeMath'); rnd.operation = 'MULTIPLY'; rnd.inputs[1].default_value = 37.0
    nt.links.new(oi.outputs['Random'], rnd.inputs[0])
    nt.links.new(rnd.outputs[0], off.inputs[2])
    st = {'X': (0.03, 1, 1), 'Y': (1, 0.03, 1), 'Z': (1, 1, 0.03)}[grain_axis]
    mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = st
    nt.links.new(off.outputs[0], mp.inputs['Vector'])
    fine = nt.nodes.new('ShaderNodeTexNoise')
    fine.inputs['Scale'].default_value = 25.0
    fine.inputs['Detail'].default_value = 2.0
    fine.inputs['Roughness'].default_value = 0.5
    nt.links.new(mp.outputs[0], fine.inputs['Vector'])
    broad = nt.nodes.new('ShaderNodeTexNoise')
    broad.inputs['Scale'].default_value = 2.0
    broad.inputs['Detail'].default_value = 1.0
    nt.links.new(mp.outputs[0], broad.inputs['Vector'])
    mix = nt.nodes.new('ShaderNodeMath'); mix.operation = 'MULTIPLY_ADD'
    nt.links.new(fine.outputs['Fac'], mix.inputs[0]); mix.inputs[1].default_value = 0.55
    sc2 = nt.nodes.new('ShaderNodeMath'); sc2.operation = 'MULTIPLY'; sc2.inputs[1].default_value = 0.6
    nt.links.new(broad.outputs['Fac'], sc2.inputs[0])
    nt.links.new(sc2.outputs[0], mix.inputs[2])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.38
    ramp.color_ramp.elements[0].color = hexrgb(c1)
    ramp.color_ramp.elements[1].position = 0.72
    ramp.color_ramp.elements[1].color = hexrgb(c2)
    nt.links.new(mix.outputs[0], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    setin(p, 'Roughness', rough)
    setin(p, 'Coat Weight', coat)
    setin(p, 'Coat Roughness', 0.12)
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.05
    bump.inputs['Distance'].default_value = 0.002
    nt.links.new(fine.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    _mats[k] = m
    return m


def painted_metal(color, rough=0.48, corrugate=None, key=None, grime=0.06):
    """Painted steel with subtle mottling; corrugate=pitch (m) adds trapezoid corrugation bump on X/Y faces."""
    k = key or ('pm', color, rough, corrugate, grime)
    if k in _mats:
        return _mats[k]
    m, nt, p = _new_mat('pm%d' % len(_mats))
    tc = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 9.0
    noise.inputs['Detail'].default_value = 8.0
    nt.links.new(tc.outputs['Object'], noise.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    base = hexrgb(color)
    dark = tuple(c * (1 - grime * 2.5) for c in base[:3]) + (1,)
    light = tuple(min(1, c * (1 + grime)) for c in base[:3]) + (1,)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[0].color = dark
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = light
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    rr = nt.nodes.new('ShaderNodeMapRange')
    rr.inputs['To Min'].default_value = rough - 0.08
    rr.inputs['To Max'].default_value = rough + 0.12
    nt.links.new(noise.outputs['Fac'], rr.inputs['Value'])
    nt.links.new(rr.outputs['Result'], p.inputs['Roughness'])
    setin(p, 'Metallic', 0.35)
    if corrugate:
        sep = nt.nodes.new('ShaderNodeSeparateXYZ')
        nt.links.new(tc.outputs['Object'], sep.inputs[0])
        add = nt.nodes.new('ShaderNodeMath'); add.operation = 'ADD'
        nt.links.new(sep.outputs[0], add.inputs[0]); nt.links.new(sep.outputs[1], add.inputs[1])
        mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = 2 * math.pi / corrugate
        nt.links.new(add.outputs[0], mul.inputs[0])
        sn = nt.nodes.new('ShaderNodeMath'); sn.operation = 'SINE'
        nt.links.new(mul.outputs[0], sn.inputs[0])
        cl = nt.nodes.new('ShaderNodeMath'); cl.operation = 'MULTIPLY'; cl.use_clamp = False
        cl.inputs[1].default_value = 2.2
        nt.links.new(sn.outputs[0], cl.inputs[0])
        cp = nt.nodes.new('ShaderNodeClamp')
        cp.inputs['Min'].default_value = -1; cp.inputs['Max'].default_value = 1
        nt.links.new(cl.outputs[0], cp.inputs['Value'])
        bump = nt.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 1.0
        bump.inputs['Distance'].default_value = 0.03
        nt.links.new(cp.outputs[0], bump.inputs['Height'])
        nt.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    _mats[k] = m
    return m


def water_mat():
    k = 'water'
    if k in _mats:
        return _mats[k]
    m, nt, p = _new_mat('water')
    setin(p, 'Base Color', hexrgb('#2f7f93'))
    setin(p, 'Roughness', 0.04)
    setin(p, 'Coat Weight', 0.6)
    setin(p, 'Coat Roughness', 0.02)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.noise_dimensions = '4D'
    noise.inputs['Scale'].default_value = 0.35
    noise.inputs['Detail'].default_value = 4.0
    nt.links.new(tc.outputs['Object'], noise.inputs['Vector'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.35
    bump.inputs['Distance'].default_value = 0.4
    nt.links.new(noise.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    m['wnoise'] = noise.name
    _mats[k] = m
    return m


def set_water_time(t):
    m = _mats.get('water')
    if m:
        m.node_tree.nodes[m['wnoise']].inputs['W'].default_value = t * 0.25


def image_mat(path, rough=0.6, key=None, emit=0.0, axes='XY'):
    """Image projected from Generated coords (primitives here have no UVs)."""
    k = key or ('img', path)
    if k in _mats:
        return _mats[k]
    m, nt, p = _new_mat('img%d' % len(_mats))
    im = nt.nodes.new('ShaderNodeTexImage')
    im.image = bpy.data.images.load(path)
    im.extension = 'CLIP'
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    cmb = nt.nodes.new('ShaderNodeCombineXYZ')
    nt.links.new(tc.outputs['Generated'], sep.inputs[0])
    nt.links.new(sep.outputs[axes[0]], cmb.inputs['X'])
    nt.links.new(sep.outputs[axes[1]], cmb.inputs['Y'])
    nt.links.new(cmb.outputs[0], im.inputs['Vector'])
    nt.links.new(im.outputs['Color'], p.inputs['Base Color'])
    setin(p, 'Roughness', rough)
    if emit:
        nt.links.new(im.outputs['Color'], p.inputs['Emission Color'])
        setin(p, 'Emission Strength', emit)
    _mats[k] = m
    return m


def glow_mat(color, key):
    """Emission + transparency mix; returns material whose 'Fac' node controls visibility."""
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = hexrgb(color)
    em.inputs['Strength'].default_value = 3.0
    mx = nt.nodes.new('ShaderNodeMixShader')
    mx.inputs['Fac'].default_value = 0.0
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs['Surface'])
    m['mix'] = mx.name
    _mats[key] = m
    return m


def set_glow(m, v):
    m.node_tree.nodes[m['mix']].inputs['Fac'].default_value = max(0.0, min(1.0, v))


# ---------------------------------------------------------------- meshes
def _auto_smooth(bm, angle=35):
    lim = math.radians(angle)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) != 2 or e.calc_face_angle(0) > lim:
            e.smooth = False


def _finish(bm, name, smooth=None):
    if smooth:
        _auto_smooth(bm, smooth)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


_meshes = {}


def box_mesh(w, h, d):
    k = ('box', round(w, 4), round(h, 4), round(d, 4))
    if k in _meshes:
        return _meshes[k]
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= w; v.co.y *= d; v.co.z *= h
    _meshes[k] = _finish(bm, 'box')
    return _meshes[k]


def cyl_mesh(r1, r2, h, seg=32):
    """axis along Blender Z (= js Y)."""
    k = ('cyl', r1, r2, h, seg)
    if k in _meshes:
        return _meshes[k]
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r2, radius2=r1, depth=h)
    _meshes[k] = _finish(bm, 'cyl', smooth=40)
    return _meshes[k]


def sphere_mesh(r, seg=32):
    k = ('sph', r, seg)
    if k in _meshes:
        return _meshes[k]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    _meshes[k] = _finish(bm, 'sph', smooth=80)
    return _meshes[k]


def torus_mesh(R, r, seg=48, rseg=16):
    k = ('tor', R, r, seg, rseg)
    if k in _meshes:
        return _meshes[k]
    bm = bmesh.new()
    vs = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            row.append(bm.verts.new((x, y, z)))
        vs.append(row)
    for i in range(seg):
        for j in range(rseg):
            bm.faces.new((vs[i][j], vs[(i + 1) % seg][j], vs[(i + 1) % seg][(j + 1) % rseg], vs[i][(j + 1) % rseg]))
    _meshes[k] = _finish(bm, 'tor', smooth=80)
    return _meshes[k]


def capsule_mesh(r, length, seg=24):
    k = ('cap', r, length)
    if k in _meshes:
        return _meshes[k]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2 + 1, radius=r)
    for v in bm.verts:
        v.co.z += length / 2 if v.co.z > 1e-6 else (-length / 2 if v.co.z < -1e-6 else 0)
    _meshes[k] = _finish(bm, 'cap', smooth=80)
    return _meshes[k]


def extrude_mesh(pts2d, h, holes=None, name='ext'):
    """Polygon in Blender XY extruded along +Z by h."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, 0)) for x, y in pts2d]
    top = [bm.verts.new((x, y, h)) for x, y in pts2d]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    n = len(pts2d)
    for i in range(n):
        bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, smooth=30)


# ---------------------------------------------------------------- objects
def empty(name='grp', loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    link(o)
    if parent:
        o.parent = parent
    return o


def obj(mesh, material=None, loc=(0, 0, 0), parent=None, bevel=0.0, bseg=3, name='o', rot=None, scale=None):
    o = bpy.data.objects.new(name, mesh)
    link(o)
    if material is not None:
        if len(o.data.materials) == 0:
            o.data.materials.append(material)
        else:
            o.material_slots[0].link = 'OBJECT'
            o.material_slots[0].material = material
    o.location = loc
    if rot is not None:
        o.rotation_euler = rot
    if scale is not None:
        o.scale = scale
    if parent:
        o.parent = parent
    if bevel > 0:
        md = o.modifiers.new('bev', 'BEVEL')
        md.width = bevel
        md.segments = bseg
        md.limit_method = 'ANGLE'
        md.angle_limit = math.radians(40)
    return o


def _setmat(o, material):
    """Material per object (mesh data may be shared)."""
    if len(o.data.materials) == 0:
        o.data.materials.append(None)
    o.material_slots[0].link = 'OBJECT'
    o.material_slots[0].material = material


def box(w, h, d, material, loc=(0, 0, 0), parent=None, bevel=0.0, bseg=3, rot=None):
    o = bpy.data.objects.new('box', box_mesh(w, h, d))
    link(o)
    _setmat(o, material)
    o.location = loc
    if rot is not None:
        o.rotation_euler = rot
    if parent:
        o.parent = parent
    if bevel > 0:
        md = o.modifiers.new('bev', 'BEVEL')
        md.width = min(bevel, min(w, h, d) * 0.45)
        md.segments = bseg
        md.limit_method = 'ANGLE'
    return o


def cyl(r1, r2, h, material, loc=(0, 0, 0), parent=None, seg=32, rot=None, bevel=0.0):
    o = bpy.data.objects.new('cyl', cyl_mesh(r1, r2, h, seg))
    link(o)
    _setmat(o, material)
    o.location = loc
    if rot is not None:
        o.rotation_euler = rot
    if parent:
        o.parent = parent
    if bevel > 0:
        md = o.modifiers.new('bev', 'BEVEL')
        md.width = bevel
        md.segments = 2
        md.limit_method = 'ANGLE'
        md.harden_normals = False
    return o


def sphere(r, material, loc=(0, 0, 0), parent=None, scale=None):
    o = bpy.data.objects.new('sph', sphere_mesh(r))
    link(o); _setmat(o, material); o.location = loc
    if scale:
        o.scale = scale
    if parent:
        o.parent = parent
    return o


def text(body, size, material, loc=(0, 0, 0), parent=None, extrude=0.0, rot=(math.pi / 2, 0, 0), font=FONT_SERIF, align='CENTER'):
    cu = bpy.data.curves.new('txt', 'FONT')
    cu.body = body
    cu.font = bpy.data.fonts.load(font, check_existing=True)
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.align_y = 'CENTER'
    try:
        cu.bevel_depth = extrude * 0.25 if extrude else 0
    except Exception:
        pass
    o = bpy.data.objects.new('txt', cu)
    link(o)
    o.data.materials.append(material)
    o.location = loc
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    return o


# ---------------------------------------------------------------- environment
def room(size=60, wallZ=-25, floor='#efe6d8', wallH=40, wood_wall=True, floor_mat=None):
    """Cream tabletop + wall of vertical wooden slats (real grooves)."""
    fm = floor_mat or mat(floor, 0.55, coat=0.05)
    # floor top sits 2 mm below y=0 so nothing resting at y=0 shares a plane with it
    obj(box_mesh(size * 4, 1, size * 4), fm, loc=B(0, -0.502, 0), name='floor')
    if wood_wall:
        slat_w = max(0.6, size / 45.0)
        wm = wood('#8a5530', '#c99258', rough=0.4, scale=1.0 / slat_w, grain_axis='Z', coat=0.3, key=('wallwood', slat_w))
        # dark backing board fully behind the slats (no shared faces)
        back = box(size * 4, wallH + 0.5, 0.2, mat('#2a170a', 0.8), loc=B(0, wallH / 2, wallZ - slat_w * 0.125 - 0.11))
        n = int(size * 3 / slat_w)
        x0 = -n * slat_w / 2
        meshw = box_mesh(slat_w * 0.93, wallH, slat_w * 0.25)
        for i in range(n):
            o = obj(meshw, wm, loc=B(x0 + i * slat_w, wallH / 2, wallZ), name='slat')
            o.modifiers.new('bev', 'BEVEL').width = slat_w * 0.04
        # skirting
        box(size * 4, slat_w * 0.6, slat_w * 0.4, wood('#4a2a12', '#6e4220', rough=0.4, key='skirt'), loc=B(0, slat_w * 0.3, wallZ + slat_w * 0.3), bevel=0.02)


def lights(scale=1.0, sun_dir=(-0.55, 0.65, 0.55), sun=3.2, sun_color='#ffe6c4', window=True, fill=True, sun_angle=4.0):
    """Warm window sun (with mullion shadows) + soft fill. scale ~ scene size in metres / 10."""
    ld = bpy.data.lights.new('sun', 'SUN')
    ld.energy = sun
    ld.angle = math.radians(sun_angle)
    ld.color = hexrgb(sun_color)[:3]
    so = bpy.data.objects.new('sun', ld)
    link(so)
    d = Vector(sun_dir).normalized()
    so.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    if window:
        # window mullion grid floating up toward the sun: casts soft window-frame shadows
        c = d * 30 * scale
        g = empty('window', loc=c)
        g.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        mm = mat('#000000', 1.0)
        W = 14 * scale
        for i in range(-2, 3):
            box(0.35 * scale, W, 0.2 * scale, mm, loc=(i * W / 4, 0, 0), parent=g, rot=(math.pi / 2, 0, 0))
            box(W, 0.35 * scale, 0.2 * scale, mm, loc=(0, i * W / 4, 0), parent=g, rot=(0, 0, 0))
        for o in g.children:
            o.visible_camera = False
            o.visible_glossy = False
            o.visible_diffuse = False
    if fill:
        la = bpy.data.lights.new('fill', 'AREA')
        la.energy = 900 * scale * scale
        la.size = 18 * scale
        la.color = hexrgb('#dfe9ff')[:3]
        lo = bpy.data.objects.new('fill', la)
        link(lo)
        lo.location = Vector((14, -30, 18)) * scale
        lo.rotation_euler = (lo.location * -1).normalized().to_track_quat('-Z', 'Y').to_euler()
    return so


# ---------------------------------------------------------------- camera
def camera(fstop=2.8):
    cd = bpy.data.cameras.new('cam')
    cd.sensor_fit = 'VERTICAL'
    cd.sensor_height = 24
    cd.dof.use_dof = True
    cd.dof.aperture_fstop = fstop
    cd.dof.aperture_blades = 6
    co = bpy.data.objects.new('cam', cd)
    link(co)
    bpy.context.scene.camera = co
    co.data.clip_start = 0.02
    co.data.clip_end = 2000
    return co


def _sm(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def seg(t, a, b):
    return _sm((t - a) / (b - a))


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def lerp(a, b, k):
    return a + (b - a) * k


def cam_path(co, t, keys, focus=None):
    """keys: [(time, (px,py,pz)js, (lx,ly,lz)js, fov_deg)] — three.js style, converted."""
    i = 0
    while i < len(keys) - 2 and t > keys[i + 1][0]:
        i += 1
    a = keys[i]
    b = keys[i + 1] if i + 1 < len(keys) else a
    k = 0 if b is a else seg(t, a[0], b[0])
    p = [lerp(a[1][j], b[1][j], k) for j in range(3)]
    l = [lerp(a[2][j], b[2][j], k) for j in range(3)]
    fov = lerp(a[3], b[3], k)
    P, L = B(*p), B(*l)
    co.location = P
    co.rotation_euler = (L - P).to_track_quat('-Z', 'Y').to_euler()
    co.data.angle = math.radians(fov)
    co.data.dof.focus_distance = ((B(*focus) if focus else L) - P).length


# ---------------------------------------------------------------- props
def container(color, L=6.06, Wd=2.44, Hh=2.59, detail=True, corner='#a9a59d', doors=True, parent=None, loc=(0, 0, 0)):
    """ISO container, js-style dims: L along x, Hh up, Wd depth. Origin bottom-centre."""
    g = empty('container', loc=loc, parent=parent)
    pm = painted_metal(color, corrugate=0.28 if detail else 0.28)
    body = box(L - 0.12, Hh - 0.2, Wd - 0.12, pm, loc=B(0, Hh / 2, 0), parent=g, bevel=0.02, bseg=2)
    if not detail:
        fr = painted_metal(color, rough=0.5, key=('frame', color))
        box(L, 0.18, Wd, fr, loc=B(0, 0.09, 0), parent=g, bevel=0.02)
        box(L, 0.18, Wd, fr, loc=B(0, Hh - 0.09, 0), parent=g, bevel=0.02)
        return g
    fr = painted_metal(color, rough=0.45, key=('frame', color), grime=0.18)
    for y in (0.1, Hh - 0.1):
        for z in (-Wd / 2 + 0.07, Wd / 2 - 0.07):
            box(L - 0.3, 0.2, 0.14, fr, loc=B(0, y, z), parent=g, bevel=0.02)
        for x in (-L / 2 + 0.07, L / 2 - 0.07):
            box(0.14, 0.2, Wd - 0.3, fr, loc=B(x, y, 0), parent=g, bevel=0.02)
    for x in (-L / 2 + 0.08, L / 2 - 0.08):
        for z in (-Wd / 2 + 0.08, Wd / 2 - 0.08):
            box(0.15, Hh - 0.3, 0.15, fr, loc=B(x, Hh / 2, z), parent=g, bevel=0.02)
    if doors:
        dm = painted_metal(color, rough=0.5, key=('door', color), grime=0.16)
        for z in (-Wd / 4, Wd / 4):
            box(0.06, Hh - 0.44, Wd / 2 - 0.12, dm, loc=B(L / 2 - 0.02, Hh / 2, z), parent=g, bevel=0.015)
        steel = mat('#9c9c98', 0.35, 1.0)
        for z in [v * Wd / 2.44 for v in (-0.85, -0.4, 0.4, 0.85)]:
            cyl(0.03, 0.03, Hh - 0.35, steel, loc=B(L / 2 + 0.06, Hh / 2, z), parent=g, seg=12)
            box(0.06, 0.05, 0.22, steel, loc=B(L / 2 + 0.1, Hh * 0.45, z + 0.11), parent=g, bevel=0.01)
            for yy in (0.4, Hh - 0.4):
                box(0.06, 0.12, 0.1, steel, loc=B(L / 2 + 0.06, yy, z), parent=g)
    # corner castings with oval holes
    cm = painted_metal(corner, rough=0.45, key=('casting', corner), grime=0.1)
    hole = mat('#141210', 0.8)
    for sx in (-1, 1):
        for top in (0, 1):
            for sz in (-1, 1):
                # castings stand 5 mm proud of the rails on every face (no shared planes)
                cx, cy, cz = sx * (L / 2 - 0.09), (Hh - 0.1) if top else 0.1, sz * (Wd / 2 - 0.09)
                box(0.19, 0.21, 0.19, cm, loc=B(cx, cy, cz), parent=g, bevel=0.012, bseg=2)
                cyl(0.028, 0.028, 0.02, hole, loc=B(cx, cy, cz + sz * 0.095), parent=g, rot=(math.pi / 2, 0, 0), seg=16).scale = (1.7, 1, 1)
                h2 = cyl(0.028, 0.028, 0.02, hole, loc=B(cx + sx * 0.095, cy, cz), parent=g, seg=16)
                h2.rotation_euler = (0, math.pi / 2, 0); h2.scale = (1, 1.7, 1)
                if top:
                    h3 = cyl(0.028, 0.028, 0.02, hole, loc=B(cx, cy + 0.103, cz), parent=g, seg=16)
                    h3.scale = (1.7, 1, 1)
    return g


def wheel(parent, loc, r=0.5, w=0.36):
    g = empty('wheel', loc=loc, parent=parent)
    tire = obj(torus_mesh(r - 0.15, 0.15, 40, 14), mat('#1c1c1c', 0.85), parent=g, rot=(math.pi / 2, 0, 0))
    tire.scale = (1, 1, w / 0.3)
    cyl(r - 0.17, r - 0.17, w * 0.8, mat('#2a2a2a', 0.6, 0.3), parent=g, rot=(math.pi / 2, 0, 0), seg=28)
    cyl(r * 0.45, r * 0.45, w * 0.84, mat('#c9c6bf', 0.25, 1.0), parent=g, rot=(math.pi / 2, 0, 0), seg=24, bevel=0.02)
    return g


def bale(parent, loc, s=1.0):
    g = empty('bale', loc=loc, parent=parent)
    g.scale = (s, s, s)
    box(1.05, 0.65, 1.0, mat('#eadfc4', 0.95, key='bale'), parent=g, bevel=0.08, bseg=3)
    rope = mat('#6b4a2a', 0.8)
    for dx in (-0.3, 0, 0.3):
        box(0.045, 0.67, 1.02, rope, loc=B(dx, 0, 0), parent=g, bevel=0.015)
    return g


def truck(cab='#7b2d26', trailer='bales', box_color='#2f6f9f', L=9, parent=None, loc=(0, 0, 0)):
    """1950s tractor-trailer, js layout (length along x, cab at +x). Origin at ground."""
    g = empty('truck', loc=loc, parent=parent)
    cm = painted_metal(cab, rough=0.3, key=('cab', cab), grime=0.05)
    chrome = mat('#d6d3cc', 0.15, 1.0)
    cg = empty('cab', loc=B(L / 2 - 0.4, 0, 0), parent=g)
    box(1.8, 1.75, 2.3, cm, loc=B(0, 1.75, 0), parent=cg, bevel=0.18, bseg=4)
    box(1.6, 1.0, 1.9, cm, loc=B(1.55, 1.3, 0), parent=cg, bevel=0.22, bseg=4)        # hood
    for z in (-1, 1):
        f = cyl(0.62, 0.62, 0.5, cm, loc=B(1.45, 0.72, z * 1.0), parent=cg, rot=(math.pi / 2, 0, 0), seg=32, bevel=0.06)
        f.scale = (1, 1, 1)
    glass = mat('#1d2a33', 0.05, 0.0, coat=1.0)
    box(0.06, 0.62, 1.95, glass, loc=B(0.9, 2.2, 0), parent=cg, bevel=0.03)
    for z in (-1, 1):
        box(0.95, 0.55, 0.05, glass, loc=B(0.1, 2.2, z * 1.16), parent=cg, bevel=0.02)
    box(0.07, 0.75, 1.3, chrome, loc=B(2.36, 1.3, 0), parent=cg, bevel=0.03)          # grille
    for zz in range(-5, 6):
        box(0.05, 0.7, 0.04, mat('#3a3a3a', 0.5, 0.5), loc=B(2.4, 1.3, zz * 0.11), parent=cg)
    box(0.2, 0.22, 2.4, chrome, loc=B(2.42, 0.62, 0), parent=cg, bevel=0.08)           # bumper
    for z in (-1, 1):
        cyl(0.17, 0.17, 0.14, chrome, loc=B(2.3, 1.62, z * 0.78), parent=cg, rot=(0, math.pi / 2, 0), seg=24, bevel=0.03)
        cyl(0.13, 0.13, 0.16, mat('#fff8de', 0.05, emit='#fff1c2', emit_s=0.6), loc=B(2.32, 1.62, z * 0.78), parent=cg, rot=(0, math.pi / 2, 0), seg=24)
    box(0.25, 0.08, 2.2, cm, loc=B(-0.2, 2.67, 0), parent=cg, bevel=0.03)
    cyl(0.07, 0.07, 1.6, chrome, loc=B(-1.05, 2.4, -1.0), parent=cg, seg=12)           # exhaust stack
    for z in (-1, 1):
        wheel(cg, B(1.5, 0.5, z * 1.05))
        wheel(cg, B(-0.25, 0.5, z * 1.05))
    ch = empty('chassis', parent=g)
    box(L - 1.25, 0.3, 1.6, mat('#262626', 0.6, 0.3), loc=B(-0.725, 0.98, 0), parent=ch, bevel=0.03)
    for x in (-L / 2 + 0.5, -L / 2 + 1.7):
        for z in (-1, 1):
            wheel(ch, B(x, 0.5, z * 1.05))
    load = None
    if trailer == 'bales':
        load = empty('load', loc=B(-0.76, 1.25, 0), parent=g)
        wd = wood('#6a4222', '#9b6a3d', rough=0.6, scale=2.0, grain_axis='X', key='bed')
        box(L - 1.2, 0.2, 2.3, wd, parent=load, bevel=0.03)
        for z in (-1, 1):
            for yy in (0.35, 0.75):
                box(L - 1.2, 0.18, 0.08, wd, loc=B(0, yy, z * 1.12), parent=load, bevel=0.02)
        for x in range(-int(L / 2) + 1, int(L / 2) - 1, 2):
            for z in (-1, 1):
                box(0.1, 0.9, 0.1, wd, loc=B(x + 0.4, 0.45, z * 1.12), parent=load, bevel=0.02)
        for i in range(6):
            for j in range(2):
                for kk in range(2):
                    bale(load, B(-L / 2 + 1.4 + i * 1.15, 0.45 + kk * 0.68, -0.55 + j * 1.1))
    elif trailer == 'box':
        load = container(box_color, L=L - 1.4, parent=g, loc=B(-0.75, 1.14, 0))
    g['cab'] = cg.name
    g['chassis'] = ch.name
    g['load'] = load.name if load else ''
    return g


def worker(parent=None, loc=(0, 0, 0), shirt='#3d5a80', hat='#4a3a2a', coat=False):
    """Painted wooden peg-doll figure (diorama style)."""
    g = empty('worker', loc=loc, parent=parent)
    obj(capsule_mesh(0.27, 0.62), mat(shirt, 0.45, coat=0.3, key=('peg', shirt)), loc=B(0, 0.98, 0), parent=g)
    obj(capsule_mesh(0.23, 0.4), mat('#3b3127' if coat else '#2d3142', 0.45, coat=0.3), loc=B(0, 0.45, 0), parent=g)
    sphere(0.23, mat('#e3b08a', 0.4, coat=0.3, key='skin'), loc=B(0, 1.62, 0), parent=g)
    hm = mat(hat, 0.5, coat=0.2, key=('hat', hat))
    cyl(0.19, 0.21, 0.16, hm, loc=B(0, 1.8, 0), parent=g, seg=24, bevel=0.03)
    if coat:
        cyl(0.36, 0.36, 0.03, hm, loc=B(0, 1.73, 0), parent=g, seg=32, bevel=0.01)
    else:
        box(0.26, 0.04, 0.24, hm, loc=B(0.2, 1.75, 0), parent=g, bevel=0.015)
    return g


def hull_pts(L, Wd, bow=0.18, n=10):
    """Top-view hull outline in Blender XY (x along length, y across)."""
    b = L * bow
    pts = []
    pts.append((-L / 2, -Wd / 2 * 0.86))
    pts.append((L / 2 - b, -Wd / 2))
    for i in range(1, n):
        u = i / n
        pts.append((L / 2 - b + b * u, -Wd / 2 * math.cos(u * math.pi / 2) ** 0.8))
    pts.append((L / 2, 0))
    for i in range(n - 1, 0, -1):
        u = i / n
        pts.append((L / 2 - b + b * u, Wd / 2 * math.cos(u * math.pi / 2) ** 0.8))
    pts.append((L / 2 - b, Wd / 2))
    pts.append((-L / 2, Wd / 2 * 0.86))
    for i in range(1, n):
        u = i / n
        pts.append((-L / 2 - Wd * 0.12 * math.sin(u * math.pi), Wd / 2 * 0.86 * math.cos(u * math.pi)))
    return pts


def ship(L=40, Wd=8, Hh=4, hull='#26364a', band='#a33a2a', deck='#b9ae99', bridge=True, bridge_x=None, parent=None, loc=(0, 0, 0), portholes=True):
    g = empty('ship', loc=loc, parent=parent)
    pts = hull_pts(L, Wd)
    # lower band: slightly inset outline, overlaps up into the upper hull (its sides stay hidden inside)
    lo = obj(extrude_mesh([(x * 0.997, y * 0.993) for x, y in pts], Hh * 0.45 + 0.05), painted_metal(band, rough=0.4, key=('hullb', band)), parent=g)
    lo.modifiers.new('bev', 'BEVEL').width = 0.05
    up = obj(extrude_mesh(pts, Hh * 0.55), painted_metal(hull, rough=0.35, key=('hull', hull), grime=0.1), loc=(0, 0, Hh * 0.45), parent=g)
    up.modifiers.new('bev', 'BEVEL').width = 0.05
    pts2 = [(x * 0.985, y * 0.95) for x, y in pts]
    obj(extrude_mesh(pts2, 0.08), wood('#8a6a45', '#b08a5e', rough=0.6, scale=1.2, grain_axis='X', key='deck'), loc=(0, 0, Hh - 0.02), parent=g)
    # gunwale
    rail = mat('#e9e4d8', 0.4)
    if portholes:
        pm = mat('#e8e0cc', 0.1, emit='#ffe2a0', emit_s=0.2)
        b = L * 0.18
        for i in range(int(L / 3)):
            x = -L / 2 + 2 + i * 3
            if x > L / 2 - b - 0.5:
                break
            hw = Wd / 2 * lerp(0.86, 1.0, (x + L / 2) / (L - b))   # hull half-width here
            for sy in (-1, 1):
                c = cyl(0.18, 0.18, 0.06, pm, loc=(x, sy * (hw + 0.012), Hh * 0.75), parent=g, rot=(math.pi / 2, 0, 0), seg=16)
    if bridge:
        bx = bridge_x if bridge_x is not None else -L / 2 + L * 0.1
        wm = painted_metal('#f1ede4', rough=0.4, key='white', grime=0.04)
        win = mat('#1d2a33', 0.05, coat=1.0)
        box(L * 0.1, 2.2, Wd * 0.8, wm, loc=B(bx, Hh + 1.15, 0), parent=g, bevel=0.08)
        box(L * 0.08, 1.6, Wd * 0.9, wm, loc=B(bx, Hh + 3.03, 0), parent=g, bevel=0.08)
        box(L * 0.081, 0.45, Wd * 0.91, win, loc=B(bx + 0.01, Hh + 3.2, 0), parent=g, bevel=0.03)
        box(L * 0.07, 0.3, Wd * 0.75, wm, loc=B(bx, Hh + 3.95, 0), parent=g, bevel=0.05)
        fx = bx - L * 0.06
        cyl(0.8, 0.95, 2.8, mat('#1f1f1f', 0.5), loc=B(fx, Hh + 2.7, 0), parent=g, seg=32, bevel=0.04)
        cyl(0.83, 0.83, 0.55, painted_metal(band, rough=0.4, key=('hullb', band)), loc=B(fx, Hh + 3.5, 0), parent=g, seg=32)
        cyl(0.07, 0.07, 7.2, rail, loc=B(L * 0.3, Hh + 3.45, 0), parent=g, seg=10)
        cyl(0.05, 0.05, 4, rail, loc=B(L * 0.3, Hh + 5.5, 0), parent=g, seg=10, rot=(math.pi / 2, 0, 0))
    return g


def water(size=200, loc=(0, 0, 0), sizey=None):
    return obj(box_mesh(size, 0.4, sizey or size), water_mat(), loc=loc, name='water')


def gantry(span=14, h=14, color='#e3b23c', parent=None, loc=(0, 0, 0)):
    """Portal crane, js layout: legs at z=±span/2, beam along z. Use gantry_set(g, z, y)."""
    g = empty('gantry', loc=loc, parent=parent)
    m = painted_metal(color, rough=0.38, key=('crane', color), grime=0.02)
    for z in (-span / 2, span / 2):
        for x in (-1.2, 1.2):
            box(0.5, h, 0.5, m, loc=B(x, h / 2, z), parent=g, bevel=0.04)
        box(3.1, 0.5, 0.64, m, loc=B(0, h - 0.27, z), parent=g, bevel=0.05)
        box(3.1, 0.45, 0.64, m, loc=B(0, 0.24, z), parent=g, bevel=0.05)
        # cross bracing
        L2 = math.hypot(2.4, h * 0.5)
        a = math.atan2(h * 0.5, 2.4)
        for s in (-1, 1):
            box(L2, 0.18, 0.18, m, loc=B(0, h * 0.5, z + s * 0.1), parent=g, rot=(0, s * a, 0))
    for x in (-1.2, 1.2):
        box(0.6, 0.8, span + 1.6, m, loc=B(x, h, 0), parent=g, bevel=0.05)
    cab_m = painted_metal('#f1ede4', rough=0.4, key='white', grime=0.04)
    box(1.6, 1.4, 1.4, cab_m, loc=B(2.2, h - 1.0, span / 2 - 1), parent=g, bevel=0.06)
    trolley = box(3.0, 0.6, 1.4, mat('#4a4a4a', 0.5, 0.4), loc=B(0, h + 0.6, 0), parent=g, bevel=0.05)
    cables = [cyl(0.03, 0.03, 1, mat('#222222', 0.4, 0.5), parent=g, seg=8) for _ in range(2)]
    sp = spreader(parent=g)
    g['h'] = h
    g['trolley'] = trolley.name
    g['sp'] = sp.name
    g['cables'] = ','.join(c.name for c in cables)
    return g


def spreader(L=6.06, Wd=2.44, parent=None, loc=(0, 0, 0)):
    g = empty('spreader', loc=loc, parent=parent)
    m = painted_metal('#f2c14e', rough=0.38, key='spreader', grime=0.03)
    box(L, 0.3, 0.3, m, loc=B(0, 0.25, -Wd / 2 + 0.15), parent=g, bevel=0.03)
    box(L, 0.3, 0.3, m, loc=B(0, 0.25, Wd / 2 - 0.15), parent=g, bevel=0.03)
    box(0.32, 0.34, Wd + 0.04, m, loc=B(-L / 2 + 0.15, 0.25, 0), parent=g, bevel=0.03)
    box(0.32, 0.34, Wd + 0.04, m, loc=B(L / 2 - 0.15, 0.25, 0), parent=g, bevel=0.03)
    box(1.2, 0.5, 1.2, mat('#3a3a3a', 0.5, 0.3), loc=B(0, 0.5, 0), parent=g, bevel=0.05)
    for x in (-1, 1):
        for z in (-1, 1):
            cyl(0.04, 0.04, 0.22, mat('#888888', 0.3, 1.0), loc=B(x * (L / 2 - 0.09), 0.02, z * (Wd / 2 - 0.09)), parent=g, seg=12)
    return g


def gantry_set(g, z, y):
    """trolley at local js-z, spreader bottom at local js-y."""
    h = g['h']
    tr = bpy.data.objects[g['trolley']]
    sp = bpy.data.objects[g['sp']]
    tr.location = B(0, h + 0.6, z)
    sp.location = B(0, y, z)
    top, bot = h + 0.4, y + 0.7
    ln = max(0.01, top - bot)
    for i, n in enumerate(g['cables'].split(',')):
        c = bpy.data.objects[n]
        c.location = B(0, (top + bot) / 2, z + (i - 0.5) * 0.5)
        c.scale = (1, 1, ln)


def plinth(w=8, h=1.2, d=4, label='HOW IT CLICKED', sub=None, parent=None, loc=(0, 0, 0)):
    g = empty('plinth', loc=loc, parent=parent)
    mah = wood('#3a1c0c', '#6a3418', rough=0.25, scale=1.5, grain_axis='X', coat=0.6, key='mahogany')
    box(w, h, d, mah, loc=B(0, h / 2, 0), parent=g, bevel=0.04)
    box(w + 0.2, 0.14, d + 0.2, mah, loc=B(0, h + 0.02, 0), parent=g, bevel=0.05)
    box(w + 0.15, 0.12, d + 0.15, mah, loc=B(0, 0.065, 0), parent=g, bevel=0.04)
    brass = mat('#c9a14a', 0.22, 1.0, key='brass')
    pw, ph = w * 0.62, w * 0.14
    box(pw, ph, 0.05, brass, loc=B(0, h / 2, d / 2 + 0.028), parent=g, bevel=0.02)
    box(pw - 0.12, ph - 0.12, 0.02, mat('#a37f33', 0.3, 1.0, key='brass2'), loc=B(0, h / 2, d / 2 + 0.05), parent=g, bevel=0.005)
    text(label, ph * (0.42 if not sub else 0.36), mat('#3e2a0a', 0.45, 0.6, key='engrave'), loc=B(0, h / 2 + (0.06 * ph if sub else 0), d / 2 + 0.062), parent=g, extrude=0.004)
    if sub:
        text(sub, ph * 0.2, mat('#3e2a0a', 0.45, 0.6, key='engrave'), loc=B(0, h / 2 - ph * 0.25, d / 2 + 0.062), parent=g, extrude=0.003)
    return g


def coin(parent=None, loc=(0, 0, 0), r=0.8, t=0.12):
    gold = mat('#d8a93c', 0.22, 1.0, key='gold')
    o = cyl(r, r, t, gold, loc=loc, parent=parent, seg=48, bevel=0.025)
    return o
