"""Z-fighting audit: finds coincident (coplanar, overlapping) faces between objects.
usage: python audit.py <scene> [n_times]
Reports SAME (same-facing coincident faces -> visible flicker) and CONTACT (opposite-facing flush contact)."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import lib, scenes

EPS = 5e-4          # surfaces closer than 0.5 mm in the same plane count as coincident


def label(o):
    chain = []
    p = o
    while p is not None:
        chain.append(p.name.split('.')[0])
        p = p.parent
    m = o.material_slots[0].material.name if o.material_slots and o.material_slots[0].material else '-'
    d = o.dimensions
    return '/'.join(reversed(chain)) + f'[{m}]' + (f'<{d.x:.2f}x{d.y:.2f}x{d.z:.2f} @{o.location.x:.2f},{o.location.y:.2f},{o.location.z:.2f}>' if os.environ.get('AUDIT_DIMS') else '')


def collect():
    dg = bpy.context.evaluated_depsgraph_get()
    items = []
    for o in bpy.context.scene.objects:
        if o.type not in ('MESH', 'FONT') or o.hide_render:
            continue
        if not o.visible_camera:
            continue
        eo = o.evaluated_get(dg)
        try:
            me = eo.to_mesh()
        except RuntimeError:
            continue
        mw = eo.matrix_world
        verts = [mw @ v.co for v in me.vertices]
        polys = [tuple(p.vertices) for p in me.polygons]
        eo.to_mesh_clear()
        if not polys:
            continue
        lo = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
        hi = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
        items.append((o, verts, polys, BVHTree.FromPolygons(verts, polys), lo, hi))
    return items


def check(items):
    found = {}
    n = len(items)
    # sort-and-sweep on x for AABB pairs
    order = sorted(range(n), key=lambda i: items[i][4].x)
    for ai in range(n):
        A = items[order[ai]]
        for bi in range(ai + 1, n):
            Bt = items[order[bi]]
            if Bt[4].x > A[5].x + EPS:
                break
            if (Bt[4].y > A[5].y + EPS or Bt[5].y < A[4].y - EPS or Bt[4].z > A[5].z + EPS or Bt[5].z < A[4].z - EPS):
                continue
            for (X, Y) in ((A, Bt), (Bt, A)):
                o, verts, polys, _, _, _ = X
                tree = Y[3]
                for poly in polys:
                    pts = [verts[i] for i in poly]
                    c = sum(pts, Vector()) / len(pts)
                    nrm = (pts[1] - pts[0]).cross(pts[2] - pts[0])
                    if nrm.length < 1e-12:
                        continue
                    nrm.normalize()
                    samples = [c] + [c.lerp(p, 0.8) for p in pts[:4]]
                    for s in samples:
                        hit = None
                        for d in (nrm, -nrm):
                            loc, hn, idx, dist = tree.ray_cast(s - d * EPS, d, 2 * EPS)
                            if loc is not None and abs(hn.dot(nrm)) > 0.999:
                                hit = 'SAME' if hn.dot(nrm) > 0 else 'CONTACT'
                                break
                        if hit:
                            key = (hit, label(X[0]), label(Y[0]))
                            if key not in found:
                                found[key] = tuple(round(v, 2) for v in s)
                            break
    return found


if __name__ == '__main__':
    name = sys.argv[1]
    nt = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    lib.reset(res=(64, 64), samples=1)
    cam = lib.camera()
    upd = scenes.BUILDERS[name](cam)
    start, end = [(s, e) for n_, s, e in scenes.TIMELINE if n_ == name][0]
    allf = {}
    for k in range(nt):
        t = (end - start) * (k + 0.5) / nt if nt > 1 else 0
        if k == nt - 1:
            t = end - start - 0.01
        upd(t)
        bpy.context.view_layer.update()
        for key, loc in check(collect()).items():
            allf.setdefault(key, (t, loc))
    for (kind, a, b), (t, loc) in sorted(allf.items()):
        print(f'{kind:7s} t={t:5.2f} @{loc}  {a}  <->  {b}')
    print(f'AUDIT {name}: {sum(1 for k in allf if k[0]=="SAME")} same-facing, {sum(1 for k in allf if k[0]=="CONTACT")} contact')
