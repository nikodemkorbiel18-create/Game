"""The 12 scenes. Each builder sets up the Blender scene and returns update(t_local)."""
import bpy, math, os
from mathutils import Vector
from lib import *

TEX = os.path.join(os.path.dirname(__file__), 'tex')

# global timeline (seconds) — matches the narration
TIMELINE = [
    ('hook', 0.0, 3.6), ('dock', 3.6, 13.4), ('lift', 13.4, 18.25), ('deck', 18.25, 21.05),
    ('offwheels', 21.05, 23.35), ('tanker', 23.35, 27.45), ('coins', 27.45, 32.45),
    ('mismatch', 32.45, 40.0), ('twistlock', 40.0, 47.2), ('patent', 47.2, 53.75),
    ('anycrane', 53.75, 59.4), ('today', 59.4, 65.6)]
HOOK_A = ((-9.5, 5.6, 13.5), (-0.6, 2.7, 0), 34)


def build_exhibit():
    room(size=60, wallZ=-30)
    lights(scale=1.2, sun_dir=(-0.5, 0.75, 0.6))
    plinth(w=9, h=1.4, d=4.4)
    container('#d9622b', corner='#d8d2c6', loc=B(0, 1.48, 0))
    k = 0
    for row in range(3):
        for i in range(-3, 4):
            for lv in range(4 - (1 if abs(i) > 2 else 0)):
                c = PALETTE[(k * 7 + row * 3) % len(PALETTE)]
                k += 1
                container(c, detail=(row == 0 and lv < 3), doors=False, loc=B(i * 6.4, lv * 2.62, -12 - row * 2.6))
    ship(L=60, Wd=10, Hh=4, loc=B(-8, 0, -24))
    gt = gantry(span=16, h=16, loc=B(27, 0, -16))
    gantry_set(gt, 0, 11)


def s_hook(cam):
    build_exhibit()
    return lambda t: cam_path(cam, t, [(0,) + HOOK_A, (3.6, (-6.2, 4.9, 6.4), (-2.7, 3.6, 0.8), 30)], focus=(-2.95, 3.9, 1.1))


def s_today(cam):
    build_exhibit()
    return lambda t: cam_path(cam, t, [(0, (10, 18, 34), (-4, 5, -14), 38), (3.6, (-8, 8, 20), (-1, 3, 0), 36), (6.2,) + HOOK_A], focus=(-2.95, 3.9, 1.1))


def dock_base(warm=False):
    room(size=80, wallZ=-40)
    sun = lights(scale=2.0, sun_dir=(-0.45, 0.7, 0.75), sun_color='#ffd4a0' if warm else '#ffe6c4')
    water(160, loc=B(0, 0.0, -30), sizey=60)
    deck = wood('#6e4a2c', '#a87a4e', rough=0.6, scale=0.8, grain_axis='X', coat=0.0, key='pier')
    for i in range(14):
        box(50, 0.25, 0.95, deck, loc=B(0, 1.72, -0.5 + i * 1.0), bevel=0.04)
    for x in range(-24, 25, 4):
        for z in (-0.6, 12.6):
            cyl(0.3, 0.3, 2.2, wood('#3e2814', '#5e3e22', rough=0.7, scale=1, key='pile'), loc=B(x, 0.75, z), seg=16, bevel=0.03)
    box(50, 0.3, 0.3, deck, loc=B(0, 1.5, -0.6), bevel=0.04)
    ship(L=40, Wd=9, Hh=4.5, hull='#2d3b4f', loc=B(2, 0, -6.5))
    return sun


def s_dock(cam):
    sun = dock_base()
    g = box(1.6, 0.15, 6, wood('#7a5a35', '#a07a4d', key='gang'), loc=B(4, 3.4, -0.2), bevel=0.03)
    g.rotation_euler = (0.3, 0, 0)
    truck(cab='#7b2d26', trailer='bales', loc=B(-11, 1.85, 6))
    mc = worker(loc=B(-13.2, 1.85, 9.8), shirt='#6b4f3a', hat='#3a2e25', coat=True)
    mc.scale = (1.15,) * 3
    # clock post
    iron = mat('#2b2b2b', 0.35, 0.8)
    cyl(0.12, 0.12, 4.5, iron, loc=B(-10.2, 4.1, 9.6), seg=16)
    face = cyl(0.9, 0.9, 0.2, image_mat(os.path.join(TEX, 'clock.png'), 0.4, key='clock', axes='XY'), loc=B(-10.2, 6.6, 9.6), seg=48, rot=(math.pi / 2, 0, 0))
    obj(torus_mesh(0.9, 0.08), iron, loc=B(-10.2, 6.6, 9.6), rot=(math.pi / 2, 0, 0))
    hp = empty('hh', loc=B(-10.2, 6.6, 9.73)); box(0.08, 0.5, 0.03, mat('#111111', 0.4), loc=B(0, 0.22, 0), parent=hp)
    mp = empty('mh', loc=B(-10.2, 6.6, 9.775)); box(0.05, 0.75, 0.03, mat('#111111', 0.4), loc=B(0, 0.34, 0), parent=mp)
    # workers path (js coords)
    path = [(-11, 1.85, 4.2), (2, 1.85, 3.0), (4, 1.85, 2.4), (4, 4.6, -2.8), (6, 4.6, -5.5)]
    seglen = [math.dist(path[i], path[i + 1]) for i in range(len(path) - 1)]
    tot = sum(seglen)

    def at(u):
        d = u * tot
        for i, sl in enumerate(seglen):
            if d <= sl or i == len(seglen) - 1:
                k = clamp(d / sl)
                return [lerp(path[i][j], path[i + 1][j], k) for j in range(3)], path[i + 1]
            d -= sl
    shirts = ['#3d5a80', '#4f6d5a', '#7a5c3a', '#3d5a80', '#5b5b75', '#4f6d5a']
    ws = []
    for i in range(6):
        w = worker(shirt=shirts[i])
        b = bale(w, B(0, 2.28, 0), 0.7)
        ws.append((w, b))
    c0, c1 = Vector(hexrgb('#ffe6c4')[:3]), Vector(hexrgb('#ffb06a')[:3])

    def upd(t):
        set_water_time(t)
        for i, (w, b) in enumerate(ws):
            ph = (t * 0.09 + i / 6) % 1
            going = ph < 0.6
            u = ph / 0.6 if going else 1 - (ph - 0.6) / 0.4
            p, nxt = at(u)
            p2, _ = at(clamp(u + 0.01))   # forward tangent; side offset keeps directions apart
            if u > 0.99:
                p, _ = at(0.99)
            d = B(*p2) - B(*p)
            side = Vector((-d.y, d.x, 0)).normalized() * (0.55 if going else -0.55) if d.length > 1e-6 else Vector()
            w.location = B(p[0], p[1] + abs(math.sin(t * 9 + i)) * 0.08, p[2]) + side
            w.rotation_euler = (0, 0, math.atan2(d.y, d.x) + (0 if going else math.pi))
            b.hide_render = not going
        mp.rotation_euler = (0, t * 2.6, 0)     # blender Y = clock face normal
        hp.rotation_euler = (0, t * 0.22, 0)
        mc.rotation_euler = (0, 0, 0.6 + math.sin(t * 1.5) * 0.15)
        sun.data.color = c0.lerp(c1, seg(t, 2, 8))
        cam_path(cam, t, [(0, (-21, 8, 23), (-14, 3.2, 8), 34), (3.0, (-19, 9, 25), (-12, 3.2, 7), 36),
                          (6.2, (-10, 14, 30), (-4, 3, 2), 40), (9.8, (4, 16, 32), (0, 3, -1), 42)])
    return upd


def s_lift(cam):
    dock_base(warm=True)
    crane = gantry(span=26, h=18, color='#9b8a6a', loc=B(2, 0, 0))
    bpy.data.objects[crane['sp']].hide_render = True
    tr = truck(cab='#7b2d26', trailer='bales')
    rope = mat('#2a2a2a', 0.6)
    slings = []
    for x in (-3, 3):
        for z in (-1, 1):
            slings.append((cyl(0.03, 0.03, 1, rope, seg=8), (x, z * 1.1)))
    bulb = sphere(0.5, mat('#fff4c2', 0.2, emit='#ffe680', emit_s=6.0, key='bulb'))

    def upd(t):
        set_water_time(t + 9)
        up, over, down = seg(t, 1.4, 2.8), seg(t, 2.6, 3.9), seg(t, 3.8, 4.8)
        y = 1.85 + up * 9 - down * (9 - 2.65)
        z = lerp(6, -6.5, over)
        tr.location = B(2, y, z)
        tr.rotation_euler = (0, 0, math.sin(t * 2) * 0.03 * up * (1 - down))
        gantry_set(crane, z, y + 5.2)
        hook = B(2, y + 5.2, z)
        for s, (x, zz) in slings:
            a = B(2 + x, y + 2.4, z + zz)
            s.location = (a + hook) / 2
            d = hook - a
            s.scale = (1, 1, d.length)
            s.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        sc = seg(t, 0.1, 0.5) * (1 - seg(t, 1.4, 1.7)) + 0.001
        bulb.location = B(-2, 6 + math.sin(t * 3) * 0.2, 7)
        bulb.scale = (sc,) * 3
        cam_path(cam, t, [(0, (-14, 7, 30), (0, 5, 2), 36), (4.85, (-4, 13, 34), (2, 6, -2), 38)])
    return upd


def s_deck(cam):
    room(size=80, wallZ=-40, wood_wall=False, floor_mat=water_mat())
    lights(scale=2.0, sun_dir=(-0.3, 0.85, 0.4))
    ship(L=40, Wd=10, Hh=4.5, hull='#2d3b4f', bridge_x=-17)
    glows = []
    for i in range(3):
        x, z = -6 + i * 10.5, (2.4 if i % 2 else -2.4)
        truck(cab=['#7b2d26', '#2d5a7b', '#6b6b2d'][i], trailer='box', box_color=PALETTE[i + 2], L=8, loc=B(x, 4.55, z))
        gm = glow_mat('#ff3b2f', 'glow%d' % i)
        obj(box_mesh(2.9, 2.8, 2.7), gm, loc=B(x + 4.6, 4.55 + 1.4, z))
        obj(box_mesh(7.0, 1.1, 2.7), gm, loc=B(x - 0.7, 4.55 + 0.55, z))
        glows.append(gm)

    def upd(t):
        set_water_time(t + 14)
        for g in glows:
            set_glow(g, seg(t, 0.9, 1.4) * (0.12 + 0.04 * math.sin(t * 8)))
        cam_path(cam, t, [(0, (4, 34, 18), (4, 4, 0), 40), (2.8, (8, 30, 12), (4, 4, 0), 36)])
    return upd


def s_offwheels(cam):
    room(size=50, wallZ=-20)
    lights(scale=1.2)
    tr = truck(cab='#2d5a7b', trailer='box', box_color='#c4492f', L=9)
    crane = gantry(span=10, h=10, loc=B(-0.75, 0, 0))
    load, cab, ch = bpy.data.objects[tr['load']], bpy.data.objects[tr['cab']], bpy.data.objects[tr['chassis']]
    cab0 = cab.location.copy()

    def upd(t):
        up, drive = seg(t, 0.3, 1.3), seg(t, 1.0, 2.3)
        y = 1.14 + up * 3.2
        load.location = B(-0.75, y, 0)
        gantry_set(crane, 0, y + 2.59 - 0.05)
        cab.location = cab0 + Vector((drive * 14, 0, 0))
        ch.location = Vector((drive * 14, 0, 0))
        cam_path(cam, t, [(0, (-9, 5, 17), (0, 3, 0), 38), (2.3, (-11, 7, 19), (0, 4.2, 0), 38)])
    return upd


def s_tanker(cam):
    room(size=160, wallZ=-90)
    lights(scale=5.0, sun_dir=(-0.4, 0.7, 0.6))
    water(500, loc=B(0, 0, 0))
    sh = empty('tanker')
    ship(L=120, Wd=16, Hh=6, hull='#2a2f38', band='#8f2f24', bridge_x=-50, parent=sh, portholes=False)
    wm = painted_metal('#f1ede4', rough=0.4, key='white', grime=0.04)
    box(14, 4, 13, wm, loc=B(46, 8.03, 0), parent=sh, bevel=0.2)
    steel = painted_metal('#6d6a62', rough=0.5, key='spar')
    box(83.6, 0.4, 15, steel, loc=B(-1.8, 7.6, 0), parent=sh, bevel=0.08)
    for x in range(-42, 39, 8):
        for z in (-7, 7):
            box(0.4, 1.6, 0.4, steel, loc=B(x, 6.82, z), parent=sh)
    boxes = []
    n = 0
    for i in range(15):
        for j in range(4):
            if n >= 58 or (i == 0 and j in (0, 3)):
                continue
            c = container(PALETTE[(i * 4 + j * 3) % len(PALETTE)], L=5.2, Wd=3.3, Hh=2.8, detail=False, parent=sh)
            p = B(-39 + i * 5.5, 7.81, -5.4 + j * 3.6)
            boxes.append((c, p, n / 58))
            n += 1

    def upd(t):
        set_water_time(t)
        for c, p, k in boxes:
            a = 0.2 + k * 1.4
            kk = seg(t, a, a + 0.4)
            c.location = p + Vector((0, 0, (1 - kk) * 25))
            c.hide_render = kk < 0.001
            for ch in c.children:
                ch.hide_render = kk < 0.001
        sail = max(0, t - 1.8) * 6
        sh.location = Vector((sail, 0, math.sin(t * 1.2) * 0.15))
        sh.rotation_euler = (math.sin(t * 1.1) * 0.01, 0, 0)
        cam_path(cam, t, [(0, (70, 55, 110), (0, 6, 0), 34), (1.8, (70, 40, 95), (0, 6, 0), 36), (4.1, (100, 22, 70), (16, 6, 0), 40)])
    return upd


def s_coins(cam):
    room(size=30, wallZ=-12)
    lights(scale=0.6)
    plinth(w=6, h=1.2, d=3.5, label='COST PER TON')
    N = 58
    coins = [coin(loc=B(math.sin(i * 2.1) * 0.03, 1.355 + i * 0.125, math.cos(i * 1.7) * 0.03)) for i in range(N)]
    for c in coins:
        c['p0'] = tuple(c.location)
    card = mat('#f4ead2', 0.7, key='card')
    tag = empty('tag', loc=B(1.9, 2.6, 1.0))
    tag.rotation_euler = (0, 0, -0.25)
    box(2.4, 1.2, 0.03, card, parent=tag, bevel=0.01)
    box(2.3, 1.1, 0.036, mat('#7a5a2a', 0.6), loc=B(0, 0, 0), parent=tag)
    box(2.2, 1.0, 0.044, card, parent=tag)
    price = text('$5.86', 0.62, mat('#3a2a12', 0.5, key='ink'), loc=B(0.15, -0.03, 0.03), parent=tag, extrude=0.0)
    green = mat('#2e7d32', 0.5, key='inkg')
    cyl(0.01, 0.01, 1.2, mat('#444444'), loc=B(1.4, 3.0, 0.8), rot=(0, 1.0, 0), seg=6)

    def upd(t):
        k = seg(t, 1.0, 4.2)
        val = lerp(5.86, 0.16, k)
        keep = max(2, round(lerp(N, 2, k)))
        for i, c in enumerate(coins):
            gone = i >= keep
            dt = (k * N - (N - i)) if gone else 0
            c.hide_render = gone and dt >= 3
            p0 = Vector(c['p0'])
            if gone:
                m = min(3, dt)
                c.location = p0 + Vector((m * 1.4, 0, m * 0.8))
                c.rotation_euler = (0, dt, 0)
                c.scale = (max(0.01, 1 - dt / 3),) * 3
            else:
                c.location = p0; c.rotation_euler = (0, 0, 0); c.scale = (1, 1, 1)
        price.data.body = '$%.2f' % val
        price.material_slots[0].material = green if k > 0.98 else mat('#3a2a12', 0.5, key='ink')
        cam_path(cam, t, [(0, (3, 7.5, 14), (0.4, 4.0, 0), 34), (5, (2, 4.5, 11), (0.6, 2.4, 0), 34)])
    return upd


def s_mismatch(cam):
    room(size=60, wallZ=-16)
    lights(scale=1.4)
    specs = [('#3d8a5a', 5.0, 2.2, 2.2, 'ring'), ('#8c3b6b', 7.5, 2.9, 2.6, 'bar'),
             ('#2f6f9f', 4.0, 3.2, 2.4, 'post'), ('#e09a2d', 6.5, 2.5, 2.0, 'ring')]
    x = -14
    boxes = []
    hm = mat('#3a3a3a', 0.35, 0.9)
    for i, (c, L, H, W, hook) in enumerate(specs):
        g = container(c, L=L, Hh=H, Wd=W, doors=(i % 2 == 0), loc=B(x + L / 2, 0, 0))
        for dx in (-L / 3, L / 3):
            if hook == 'ring':
                obj(torus_mesh(0.28, 0.07), hm, loc=B(dx, H + 0.28, 0), parent=g, rot=(math.pi / 2, 0, 0))
            elif hook == 'bar':
                box(0.15, 0.4, W * 0.8, hm, loc=B(dx, H + 0.185, 0), parent=g, bevel=0.03)
            else:
                cyl(0.12, 0.12, 0.6, hm, loc=B(dx, H + 0.285, 0), parent=g, seg=16)
                sphere(0.2, hm, loc=B(dx, H + 0.65, 0), parent=g)
        boxes.append(g)
        x += L + 1.4
    crane = gantry(span=10, h=11)

    def upd(t):
        target = boxes[1]
        crane.location = B(lerp(-12, target.location.x, seg(t, 3.6, 4.6)), 0, 0)
        down, up = seg(t, 4.6, 5.4), seg(t, 6.3, 7.2)
        sy = lerp(7, 2.9 + 0.45, down) + up * 4
        gantry_set(crane, 0.6 * down * (1 - up), sy)
        bpy.data.objects[crane['sp']].rotation_euler = (0, 0, 0.12 * down * (1 - up))
        wob = max(0, math.sin((t - 5.4) * 14)) * math.exp(-(t - 5.4) * 2.5) if t > 5.4 else 0
        target.rotation_euler = (0, -wob * 0.05, 0)
        cam_path(cam, t, [(0, (-16, 7, 17), (-10, 2, 0), 36), (3.4, (6, 8, 22), (0, 2.4, 0), 38), (7.5, (-2, 7, 16), (-4.5, 3.6, 0), 36)])
    return upd


def casting_mesh():
    """Hollow corner casting 2x2x2 (js units), oval holes top & bottom, open front for cutaway."""
    import bmesh
    from lib import _finish
    bm = bmesh.new()

    def plate(z0, hole=True):
        # square plate with oval hole, built as ring of quads between outer square and ellipse
        n = 48
        th = 0.25
        outer, inner = [], []
        for i in range(n):
            a = 2 * math.pi * i / n
            ex, ey = 0.62 * math.cos(a), 0.32 * math.sin(a)
            # project onto square boundary
            s = 1.0 / max(abs(math.cos(a)), abs(math.sin(a)))
            ox, oy = math.cos(a) * s, math.sin(a) * s
            outer.append((ox, oy)); inner.append((ex, ey))
        layers = []
        for z in (z0, z0 + th):
            layers.append(([bm.verts.new((x, y, z)) for x, y in outer], [bm.verts.new((x, y, z)) for x, y in inner]))
        (ob, ib), (ot, it) = layers
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ob[j], ob[i], ib[i], ib[j]))
            bm.faces.new((ot[i], ot[j], it[j], it[i]))
            bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
            bm.faces.new((ib[j], ib[i], it[i], it[j]))
    plate(0.75)
    plate(-1.0)

    def slab(x0, x1, y0, y1, z0, z1):
        vs = [bm.verts.new((x, y, z)) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
        idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for f in idx:
            bm.faces.new([vs[i] for i in f])
    slab(-1, 1, 0.75, 1, -0.75, 0.75)     # back (blender +y = away from camera)
    slab(-1, -0.75, -1, 0.75, -0.75, 0.75)  # left
    slab(0.75, 1, -1, 0.75, -0.75, 0.75)    # right
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, 'casting', smooth=50)


def twistlock(parent=None, loc=(0, 0, 0), sc=1.0):
    g = empty('twistlock', loc=loc, parent=parent)
    g.scale = (sc,) * 3
    m = mat('#c9a227', 0.22, 1.0, key='tlgold')
    head = empty('head', parent=g)
    c = cyl(0.0, 0.55, 0.9, m, loc=B(0, 0.9, 0), parent=head, seg=48); c.scale = (1, 0.5, 1)
    cyl(0.28, 0.28, 0.63, m, loc=B(0, 0.335, 0), parent=head, seg=32)
    foot = empty('foot', parent=g)
    c2 = cyl(0.55, 0.0, 0.9, m, loc=B(0, -0.9, 0), parent=foot, seg=48); c2.scale = (1, 0.5, 1)
    cyl(0.28, 0.28, 0.63, m, loc=B(0, -0.335, 0), parent=foot, seg=32)
    box(1.6, 0.18, 1.1, m, parent=g, bevel=0.04)
    handle = empty('handle', parent=g)
    box(0.12, 0.12, 1.4, m, loc=B(0, 0, 0.8), parent=handle, bevel=0.03)
    sphere(0.1, m, loc=B(0, 0, 1.5), parent=handle)
    return g, head, handle


def s_twistlock(cam):
    room(size=30, wallZ=-14)
    lights(scale=0.6, sun_dir=(-0.4, 0.6, 0.7))
    steel = mat('#b9b4aa', 0.32, 0.85, key='caststeel')
    cm = casting_mesh()
    lower = obj(cm, steel, loc=B(0, 2.0, 0))
    lower.modifiers.new('bev', 'BEVEL').width = 0.03
    upper = obj(cm, steel, loc=B(0, 7.2, 0))
    upper.modifiers.new('bev', 'BEVEL').width = 0.03
    wm = painted_metal('#c4492f', corrugate=0.6, key='bigwall')
    box(9, 0.3, 1.6, wm, loc=B(-5.47, 2.6, -0.1), bevel=0.04)
    box(9.06, 2.6, 0.3, wm, loc=B(-5.52, 1.6, -0.85), bevel=0.04)
    box(9, 0.3, 1.6, wm, loc=B(-5.47, -0.6, -0.1), parent=upper, bevel=0.04)
    box(9.06, 2.6, 0.3, wm, loc=B(-5.52, 0.4, -0.85), parent=upper, bevel=0.04)
    box(2.4, 1.03, 2.4, wood('#5a3a1c', '#8a5a2e', key='stand'), loc=B(0, 0.515, 0), bevel=0.05)
    tl, head, handle = twistlock(loc=B(0, 3.27, 0))
    gm = glow_mat('#ffe9a0', 'lockglow')
    ring = obj(torus_mesh(1.2, 0.05), gm, loc=B(0, 3.3, 0))

    def upd(t):
        d = seg(t, 3.4, 4.8)
        y = lerp(7.2, 4.4, d)
        if 6.75 < t < 6.95:
            y = 4.4 - 0.04 * math.sin((t - 6.75) * 30)
        upper.location = B(0, y, 0)
        turn = seg(t, 5.8, 6.6) * math.pi / 2
        head.rotation_euler = (0, 0, turn)
        handle.rotation_euler = (0, 0, turn)
        pulse = seg(t, 6.7, 6.9) * (1 - seg(t, 6.9, 7.3))
        set_glow(gm, pulse)
        ring.scale = (1 + seg(t, 6.7, 7.3) * 0.6,) * 3
        cam_path(cam, t, [(0, (-14, 9, 18), (-4, 3, 0), 34), (1.4, (-6, 6.5, 11), (-1, 3.5, 0), 34),
                          (3.0, (1.5, 5.5, 8.2), (0, 4.0, 0), 32), (5.6, (3.2, 5.0, 7.2), (0, 4.1, 0), 30),
                          (7.2, (2.2, 6.2, 7.0), (0, 4.1, 0), 30)])
    return upd


def s_patent(cam):
    room(size=30, wallZ=-12)
    lights(scale=0.7)
    plinth(w=5, h=1.6, d=3, label='PATENT')
    steel = mat('#b9b4aa', 0.32, 0.85, key='caststeel')
    cast = obj(casting_mesh(), steel, loc=B(0, 2.45, 0), scale=(0.8,) * 3)
    cast.modifiers.new('bev', 'BEVEL').width = 0.03
    twistlock(loc=B(0, 3.5, 0), sc=0.8)
    rivals = []
    for i, xx in enumerate((-7.5, -3.6, 4.1, 7.2)):
        rivals.append(container(PALETTE[i * 2 + 1], L=2.4, Wd=1.2, Hh=1.2, detail=False, loc=B(xx, 0, -4 + (i % 2) * 0.6)))
    cyl(1.2, 0.9, 0.3, mat('#8a6a2a', 0.3, 1.0, key='dish'), loc=B(2.2, 1.765, 1.0), seg=48, bevel=0.04)
    coins = [coin(r=0.3, t=0.06) for _ in range(8)]
    card = mat('#f4ead2', 0.7, key='card')
    tag = empty('tag', loc=B(-2.4, 3.4, 1.2))
    tag.rotation_euler = (0, 0, 0.3)
    box(2.2, 0.86, 0.03, card, parent=tag, bevel=0.01)
    word = text('ROYALTY', 0.34, mat('#8f2f24', 0.5, key='inkr'), loc=B(0, -0.02, 0.035), parent=tag)
    border = box(2.1, 0.76, 0.036, mat('#8f2f24', 0.5, key='inkr'), parent=tag)
    box(2.0, 0.66, 0.044, card, parent=tag)
    bp = image_mat(os.path.join(TEX, 'blueprint.png'), 0.7, key='bp', axes='XZ')
    sheets = []
    for i in range(14):
        s = box(1.1, 1.4, 0.01, bp)
        s.hide_render = True
        sheets.append((s, (math.cos(i * 2.4) * (4 + (i % 3) * 2), 3 + (i % 4) * 1.4, math.sin(i * 2.4) * 3 + 2)))

    def upd(t):
        for i, c in enumerate(coins):
            a = 0.9 + i * 0.28
            k = clamp((t - a) / 0.45)
            c.hide_render = not (a < t < 3.3)
            c.location = B(2.2 + math.sin(i) * 0.4, lerp(7, 1.95 + i * 0.03, k * k), 1.0 + math.cos(i) * 0.3)
            c.rotation_euler = ((1 - k) * 4, 0, 0)
        free = t >= 3.25
        word.data.body = 'FREE' if free else 'ROYALTY'
        inkm = mat('#2e7d32', 0.5, key='inkg') if free else mat('#8f2f24', 0.5, key='inkr')
        word.material_slots[0].material = inkm
        border.material_slots[0].material = inkm
        pop = seg(t, 3.25, 3.45)
        s = 1 if not free else 0.8 + 0.2 * pop + 0.15 * math.sin(pop * math.pi)
        tag.scale = (s,) * 3
        for i, (sh, d) in enumerate(sheets):
            a = 3.3 + i * 0.07
            k = clamp((t - a) / 2.4)
            sh.hide_render = t <= a
            e = 1 - (1 - k) ** 2
            sh.location = B(d[0] * e, 3.6 + d[1] * e - k * k * 1.5, d[2] * e)
            sh.rotation_euler = (k * 5 + i, k * 3, k * 2 + i * 0.5)
        for i, b in enumerate(rivals):
            hop = max(0, math.sin((t - 1.0 - i * 0.2) * 6)) * 0.25 if 1 < t < 3.2 else 0
            if t > 4:
                hop += abs(math.sin((t - 4) * 5 + i)) * 0.4 * (1 - seg(t, 5.5, 6.5))
            b.location.z = hop
        cam_path(cam, t, [(0, (-3, 6, 12), (0, 2.8, 0), 36), (3.2, (-1, 5.2, 10), (0, 3, 0), 36), (6.55, (0, 7.5, 16), (0, 3.5, 0), 40)])
    return upd


def s_anycrane(cam):
    room(size=90, wallZ=-60)
    lights(scale=2.2)
    water(80, loc=B(0, 0.05, -58), sizey=80)
    box(90, 1.45, 40, mat('#d7cfbf', 0.7, key='quay'), loc=B(0, 0.675, 0), bevel=0.1)
    ship(L=34, Wd=8, Hh=3.6, hull='#26364a', loc=B(0, 0, -26))
    truck(cab='#2d5a7b', trailer='none', L=8, loc=B(0, 1.405, -6))
    rail = mat('#8a8a88', 0.3, 1.0)
    tie = wood('#4a2e18', '#6a4426', key='tie')
    for z in (-0.75, 0.75):
        box(60, 0.15, 0.15, rail, loc=B(0, 1.55, 8 + z))
    for i in range(-14, 14):
        box(0.4, 0.12, 2.6, tie, loc=B(i * 2, 1.465, 8), bevel=0.02)
    car = empty('car', loc=B(0, 1.4, 8))
    box(7.5, 0.4, 2.6, painted_metal('#4a4a4a', key='flatcar'), loc=B(0, 1.0, 0), parent=car, bevel=0.05)
    for x in (-2.8, 2.8):
        for z in (-0.75, 0.75):
            cyl(0.42, 0.42, 0.2, mat('#222222', 0.5, 0.6), loc=B(x, 0.5, z), parent=car, rot=(math.pi / 2, 0, 0), seg=24, bevel=0.02)
    targets = [(-26, 3.6 + 0.07, 2.6), (-6, 1.405 + 1.15, 3.9), (8, 1.4 + 1.21, 4.6)]
    cr, ld = [], []
    for i, (z, y, land) in enumerate(targets):
        cr.append(gantry(span=12, h=13, loc=B(0, 0, z)))
        ld.append(container(PALETTE[(i * 3) % len(PALETTE)], loc=B(0, 0, z)))

    def upd(t):
        set_water_time(t)
        for i, (z, y0, land) in enumerate(targets):
            k = seg(t, land - 1.4, land)
            y = lerp(y0 + 6, y0, k)
            ld[i].location = B(0, y, z)
            gantry_set(cr[i], 0, y + 2.59 - 0.05)
        cam_path(cam, t, [(0, (18, 20, 30), (0, 3, -14), 44), (5.65, (12, 16, 32), (0, 3, -8), 44)])
    return upd


BUILDERS = {'hook': s_hook, 'dock': s_dock, 'lift': s_lift, 'deck': s_deck, 'offwheels': s_offwheels,
            'tanker': s_tanker, 'coins': s_coins, 'mismatch': s_mismatch, 'twistlock': s_twistlock,
            'patent': s_patent, 'anycrane': s_anycrane, 'today': s_today}
