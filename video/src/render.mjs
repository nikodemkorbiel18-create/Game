// usage: node render.mjs preview t1,t2,...   |   node render.mjs full <outDir> [startFrame] [endFrame]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';

const root = path.dirname(new URL(import.meta.url).pathname);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.woff2': 'font/woff2' };
const server = http.createServer((req, res) => {
  const f = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(0);
const port = server.address().port;

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const page = await browser.newPage({ viewport: { width: 720, height: 1280 } });
page.on('console', m => { if (m.type() === 'error') console.error('PAGE:', m.text()); });
page.on('pageerror', e => console.error('PAGEERR:', e.message));
await page.goto(`http://localhost:${port}/index.html`);
await page.waitForFunction(() => window.ready === true, null, { timeout: 120000 });

const save = async (t, file) => {
  const url = await page.evaluate(t => window.renderFrame(t), t);
  fs.writeFileSync(file, Buffer.from(url.split(',')[1], 'base64'));
};
const [mode, arg, a2, a3] = process.argv.slice(2);
if (mode === 'preview') {
  fs.mkdirSync(path.join(root, 'prev'), { recursive: true });
  for (const t of arg.split(',').map(Number)) await save(t, path.join(root, 'prev', `t_${t.toFixed(2)}.jpg`));
} else {
  fs.mkdirSync(arg, { recursive: true });
  const dur = await page.evaluate(() => window.DURATION);
  const total = Math.round(dur * 30);
  const s = Number(a2 || 0), e = Math.min(total, Number(a3 || total));
  const t0 = Date.now();
  for (let i = s; i < e; i++) {
    await save(i / 30, path.join(arg, `f_${String(i).padStart(5, '0')}.jpg`));
    if (i % 100 === 0) console.log(i, '/', e, ((Date.now() - t0) / 1000).toFixed(0) + 's');
  }
}
await browser.close(); server.close();
