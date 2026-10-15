"""usage: python render.py <scene> <outdir> [--fps 30] [--samples 32] [--res 576x1024] [--times t1,t2 (local)] [--every N]"""
import sys, os, time, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lib, scenes

ap = argparse.ArgumentParser()
ap.add_argument('scene'); ap.add_argument('out')
ap.add_argument('--fps', type=float, default=30); ap.add_argument('--samples', type=int, default=32)
ap.add_argument('--res', default='576x1024'); ap.add_argument('--times', default=None)
ap.add_argument('--every', type=int, default=1)
a = ap.parse_args()
res = tuple(int(v) for v in a.res.split('x'))
lib.reset(res=res, samples=a.samples)
cam = lib.camera(fstop=2.8)
upd = scenes.BUILDERS[a.scene](cam)
start, end = [(s, e) for n, s, e in scenes.TIMELINE if n == a.scene][0]
os.makedirs(a.out, exist_ok=True)
sc = bpy.context.scene
if a.times:
    jobs = [(float(t), os.path.join(a.out, f'{a.scene}_{float(t):.2f}.png')) for t in a.times.split(',')]
else:
    import math
    i0, i1 = math.ceil(start * a.fps - 1e-9), math.ceil(end * a.fps - 1e-9)
    if a.scene == 'today':
        i1 = round(end * a.fps)
    jobs = [(i / a.fps - start, os.path.join(a.out, f'f_{i:05d}.png')) for i in range(i0, i1, a.every)]
for t, path in jobs:
    if os.path.exists(path) and not a.times:
        continue
    t0 = time.time()
    upd(t)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print(f'RENDERED {path} {time.time() - t0:.1f}s', flush=True)
