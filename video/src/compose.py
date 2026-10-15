"""Assemble: 24fps Cycles frames -> 1080x1920 (lanczos), caption overlays, voiceover + music."""
import json, subprocess, sys
D = '/tmp/claude-0/-home-user-Game/6bcd8953-5119-5cfc-8809-be01c57c648d/scratchpad'
out = sys.argv[1]
FPS = sys.argv[2] if len(sys.argv) > 2 else '24'
FR = sys.argv[3] if len(sys.argv) > 3 else 'bframes'
caps = json.load(open(f'{D}/caps1080/caps.json'))
inputs = ['-framerate', FPS, '-i', f'{D}/{FR}/f_%05d.png', '-i', f'{D}/vo.mp3', '-i', f'{D}/music.wav']
for p, _, _ in caps:
    inputs += ['-i', p]
fc = ['[0:v]scale=1080:1920:flags=lanczos,format=rgba[v0]']
for i, (p, a, b) in enumerate(caps):
    fc.append(f"[v{i}][{i + 3}:v]overlay=0:0:enable='between(t,{a:.3f},{b - 0.001:.3f})'[v{i + 1}]")
fc.append(f'[v{len(caps)}]format=yuv420p[vout]')
fc.append('[2:a]volume=0.16[m];[1:a]adelay=150|150[v];[v][m]amix=inputs=2:duration=longest:normalize=0,afade=t=out:st=64.6:d=1[a]')
cmd = ['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', ';'.join(fc), '-map', '[vout]', '-map', '[a]',
       '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-r', FPS, '-c:a', 'aac', '-b:a', '192k', '-t', '65.6', '-movflags', '+faststart', out]
subprocess.run(cmd, check=True)
print('composed', out)
