from PIL import Image, ImageDraw, ImageFont
import math, sys
d = sys.argv[1]
F = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
# clock face
im = Image.new('RGB', (1024, 1024), '#f3ead6'); g = ImageDraw.Draw(im)
g.ellipse((40, 40, 984, 984), outline='#3a2a1a', width=18)
f = ImageFont.truetype(F, 90)
for h in range(1, 13):
    a = math.radians(h * 30 - 90); r = 370
    g.text((512 + r * math.cos(a), 512 + r * math.sin(a)), str(h), font=f, fill='#2a1d10', anchor='mm')
for m in range(60):
    a = math.radians(m * 6); r1 = 455; r2 = 430 if m % 5 else 405
    g.line((512 + r1 * math.cos(a), 512 + r1 * math.sin(a), 512 + r2 * math.cos(a), 512 + r2 * math.sin(a)), fill='#2a1d10', width=6 if m % 5 == 0 else 3)
im.save(f'{d}/clock.png')
# blueprint
im = Image.new('RGB', (880, 1120), '#1f4e8c'); g = ImageDraw.Draw(im)
for x in range(0, 880, 40): g.line((x, 0, x, 1120), fill='#2a5c9c', width=1)
for y in range(0, 1120, 40): g.line((0, y, 880, y), fill='#2a5c9c', width=1)
w = '#e8f0ff'
g.rectangle((40, 40, 840, 1080), outline=w, width=5)
g.rectangle((200, 220, 680, 700), outline=w, width=6)
g.ellipse((330, 400, 550, 520), outline=w, width=6)
g.line((200, 220, 280, 160), fill=w, width=4); g.line((680, 220, 760, 160), fill=w, width=4); g.line((280, 160, 760, 160), fill=w, width=4); g.line((760, 160, 760, 640), fill=w, width=4); g.line((680, 700, 760, 640), fill=w, width=4)
g.line((200, 760, 680, 760), fill=w, width=3); g.text((440, 790), '178 mm', font=ImageFont.truetype(F, 34), fill=w, anchor='mm')
g.text((440, 900), 'CORNER FITTING', font=ImageFont.truetype(F, 54), fill=w, anchor='mm')
g.text((440, 980), 'TWISTLOCK  ·  FIG. 1', font=ImageFont.truetype(F, 34), fill=w, anchor='mm')
im.save(f'{d}/blueprint.png')
print('tex ok')
