"""Render each caption to a transparent PNG and print an ffmpeg overlay filter.
usage: python captions.py <outdir> <width> <height>"""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CAPS = [
    ('Every shipping container', 0.0), ('on Earth has the same', 1.8), ('steel corners.', 2.7),
    ('In 1937,', 3.78), ('trucker Malcolm McLean', 5.25), ('waited all day', 6.69), ('at a New Jersey dock,', 8.14),
    ('as workers unloaded', 9.63), ('his cotton bales,', 10.72), ('one by one.', 12.05),
    ('So, he wondered...', 13.54), ('why not lift the whole truck', 15.0), ('onto the ship?', 16.6),
    ('But, wheels and cabs', 18.34), ('wasted precious space.', 19.41),
    ('So, he took the boxes', 21.16), ('off the wheels,', 22.42), ('and in 1956,', 23.44), ('an old tanker sailed', 24.84), ('with fifty-eight of them.', 25.9),
    ('Loading costs fell', 27.56), ('from nearly six dollars a ton,', 28.51), ('to sixteen cents.', 30.71),
    ('But, every company', 32.57), ('built different boxes,', 33.7), ('with different hooks.', 35.06), ('A crane in one port', 36.66), ("couldn't lift a box", 37.96), ('from another.', 38.71),
    ('So, engineer', 40.11), ('Keith Tantlinger', 40.76), ('designed a steel corner', 41.5), ('with an oval hole,', 43.01), ('and a twistlock', 44.72), ('that turns,', 45.84), ('and locks.', 46.73),
    ('But,', 47.3), ('rivals would have to pay', 48.05), ('to use it.', 49.07),
    ('So, McLean', 50.42), ('gave the patents away,', 50.9), ('for free.', 52.58),
    ('Now, one crane', 53.87), ('could lift any box,', 54.7), ('onto any ship,', 56.25), ('truck,', 57.65), ('or train.', 58.28),
    ('Today, almost everything', 59.55), ('you own', 61.25), ('once rode in a steel box,', 61.67), ('locked at the same steel corners.', 63.25),
]
END = 65.6

out, W, H = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
os.makedirs(out, exist_ok=True)
font = ImageFont.truetype(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'jost500.ttf'), round(W * 0.072))
maxw = W * 0.62


def wrap(text):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if font.getlength(t) > maxw and cur:
            lines.append(cur); cur = w
        else:
            cur = t
    lines.append(cur)
    return lines


entries = []
for i, (txt, t0) in enumerate(CAPS):
    t1 = CAPS[i + 1][1] if i + 1 < len(CAPS) else END
    lines = wrap(txt)
    lh = font.size * 1.12
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    yc = H * 0.665
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ds, dt = ImageDraw.Draw(sh), ImageDraw.Draw(img)
    for j, l in enumerate(lines):
        y = yc + (j - (len(lines) - 1) / 2) * lh
        ds.text((W / 2, y + W * 0.004), l, font=font, fill=(0, 0, 0, 200), anchor='mm', stroke_width=round(W * 0.006), stroke_fill=(0, 0, 0, 200))
    sh = sh.filter(ImageFilter.GaussianBlur(W * 0.008))
    for j, l in enumerate(lines):
        y = yc + (j - (len(lines) - 1) / 2) * lh
        dt.text((W / 2, y), l, font=font, fill=(255, 255, 255, 255), anchor='mm', stroke_width=max(1, round(W * 0.0018)), stroke_fill=(40, 30, 20, 160))
    comp = Image.alpha_composite(sh, img)
    p = os.path.join(out, f'cap_{i:02d}.png')
    comp.save(p)
    entries.append((p, t0, t1))
json.dump(entries, open(os.path.join(out, 'caps.json'), 'w'))
print(len(entries), 'captions')
