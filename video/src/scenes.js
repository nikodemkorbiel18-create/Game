import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const W = 720, H = 1280;
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H);
renderer.setPixelRatio(1);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
const envTex = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
const out = document.getElementById('out');
const ctx = out.getContext('2d');

// ---------- helpers ----------
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const ease = x => { x = clamp(x); return x * x * (3 - 2 * x); };
const seg = (t, a, b) => ease((t - a) / (b - a));
const lerp = (a, b, k) => a + (b - a) * k;
const V = (x, y, z) => new THREE.Vector3(x, y, z);
const matCache = {};
const M = (c, r = 0.6, m = 0, extra = {}) => {
  const k = c + '|' + r + '|' + m + JSON.stringify(extra);
  return matCache[k] ||= new THREE.MeshStandardMaterial({ color: c, roughness: r, metalness: m, ...extra });
};
function mesh(geo, mat, x = 0, y = 0, z = 0) {
  const o = new THREE.Mesh(geo, mat); o.position.set(x, y, z);
  o.castShadow = true; o.receiveShadow = true; return o;
}
const box = (w, h, d, mat, x, y, z) => mesh(new THREE.BoxGeometry(w, h, d), mat, x, y, z);
const cyl = (rt, rb, h, mat, x, y, z, seg = 24) => mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat, x, y, z);
function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  t.userData.canvas = c; return t;
}

// camera path: keys = [[time, [px,py,pz], [lx,ly,lz], fov]]
function camPath(cam, t, keys) {
  let i = 0; while (i < keys.length - 2 && t > keys[i + 1][0]) i++;
  const a = keys[i], b = keys[i + 1] || a;
  const k = b === a ? 0 : seg(t, a[0], b[0]);
  cam.position.set(lerp(a[1][0], b[1][0], k), lerp(a[1][1], b[1][1], k), lerp(a[1][2], b[1][2], k));
  cam.fov = lerp(a[3] || 35, b[3] || 35, k); cam.updateProjectionMatrix();
  cam.lookAt(lerp(a[2][0], b[2][0], k), lerp(a[2][1], b[2][1], k), lerp(a[2][2], b[2][2], k));
}

// ---------- shared textures ----------
const woodTex = canvasTex(512, 512, (g, w, h) => {
  const n = 8, sw = w / n;
  for (let i = 0; i < n; i++) {
    const l = 38 + (i * 37 % 9);
    g.fillStyle = `hsl(28,48%,${l}%)`; g.fillRect(i * sw, 0, sw, h);
    for (let k = 0; k < 40; k++) {
      g.strokeStyle = `rgba(60,30,10,${0.05 + Math.random() * 0.08})`; g.lineWidth = 1 + Math.random() * 2;
      const x = i * sw + Math.random() * sw; g.beginPath(); g.moveTo(x, 0);
      g.bezierCurveTo(x + 6, h / 3, x - 6, 2 * h / 3, x + 3, h); g.stroke();
    }
    g.fillStyle = 'rgba(30,14,4,0.75)'; g.fillRect(i * sw, 0, 3, h);
  }
});
woodTex.wrapS = woodTex.wrapT = THREE.RepeatWrapping;
const plankTex = canvasTex(512, 512, (g, w, h) => {
  const n = 6, sh = h / n;
  for (let i = 0; i < n; i++) {
    g.fillStyle = `hsl(30,35%,${44 + (i * 13 % 7)}%)`; g.fillRect(0, i * sh, w, sh);
    for (let k = 0; k < 30; k++) {
      g.strokeStyle = `rgba(50,25,8,${0.05 + Math.random() * 0.1})`; g.lineWidth = 1;
      const y = i * sh + Math.random() * sh; g.beginPath(); g.moveTo(0, y); g.lineTo(w, y + (Math.random() - .5) * 6); g.stroke();
    }
    g.fillStyle = 'rgba(25,12,4,0.8)'; g.fillRect(0, i * sh, w, 3);
  }
});
plankTex.wrapS = plankTex.wrapT = THREE.RepeatWrapping;

function plaqueTex(text, sub) {
  return canvasTex(1024, 256, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, '#e9c46a'); gr.addColorStop(0.5, '#b8862e'); gr.addColorStop(1, '#8a5e17');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.strokeStyle = '#5a3c0c'; g.lineWidth = 10; g.strokeRect(14, 14, w - 28, h - 28);
    g.strokeStyle = '#f6dc94'; g.lineWidth = 3; g.strokeRect(26, 26, w - 52, h - 52);
    g.fillStyle = '#4a300a'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.font = '600 92px Georgia, serif'; g.fillText(text, w / 2, sub ? h / 2 - 22 : h / 2 + 4);
    if (sub) { g.font = '500 44px Georgia, serif'; g.fillText(sub, w / 2, h / 2 + 62); }
  });
}

// ---------- room (tabletop diorama) ----------
function makeRoom(scene, { size = 60, wallZ = -25, floor = '#efe5d3', wallH = 40, sideX = null, wood = true } = {}) {
  const fl = mesh(new THREE.PlaneGeometry(size * 3, size * 3), M(floor, 0.85));
  fl.rotation.x = -Math.PI / 2; fl.castShadow = false; scene.add(fl);
  if (wood) {
    const t = woodTex.clone(); t.needsUpdate = true; t.repeat.set(size / 8, 1);
    const wall = mesh(new THREE.PlaneGeometry(size * 3, wallH), new THREE.MeshStandardMaterial({ map: t, roughness: 0.7 }), 0, wallH / 2, wallZ);
    wall.castShadow = false; scene.add(wall);
    // skirting rail
    scene.add(box(size * 3, 0.6, 0.4, M('#5b3518', 0.6), 0, 0.3, wallZ + 0.2));
    if (sideX !== null) {
      const t2 = woodTex.clone(); t2.needsUpdate = true; t2.repeat.set(size / 8, 1);
      const sw = mesh(new THREE.PlaneGeometry(size * 3, wallH), new THREE.MeshStandardMaterial({ map: t2, roughness: 0.7 }), sideX, wallH / 2, 0);
      sw.rotation.y = Math.PI / 2; sw.castShadow = false; scene.add(sw);
    }
  }
}
function makeLights(scene, { r = 40, dir = [18, 30, 22], color = '#fff1dc', intensity = 2.6, target = [0, 0, 0] } = {}) {
  const hemi = new THREE.HemisphereLight('#fff6e8', '#b39a7c', 1.25); scene.add(hemi);
  const d = new THREE.DirectionalLight(color, intensity);
  d.position.set(...dir); d.target.position.set(...target); scene.add(d.target);
  d.castShadow = true; d.shadow.mapSize.set(2048, 2048);
  const c = d.shadow.camera; c.left = -r; c.right = r; c.top = r; c.bottom = -r; c.near = 1; c.far = 200;
  d.shadow.bias = -0.0004; d.shadow.normalBias = 0.02; d.shadow.radius = 4;
  scene.add(d);
  const fill = new THREE.DirectionalLight('#dfe8ff', 0.5); fill.position.set(-20, 10, 15); scene.add(fill);
  return { hemi, key: d, fill };
}

// ---------- props ----------
const ribCache = {};
function ribGeo(L, Hh, W) {
  const k = L + '_' + Hh + '_' + W; if (ribCache[k]) return ribCache[k];
  const parts = []; const n = Math.max(4, Math.round(L / 0.32));
  for (let i = 0; i < n; i++) {
    const x = -L / 2 + 0.25 + (i + 0.5) * (L - 0.5) / n;
    for (const s of [-1, 1]) {
      const g = new THREE.BoxGeometry(0.11, Hh - 0.3, 0.06); g.translate(x, Hh / 2, s * (W / 2 + 0.01)); parts.push(g);
    }
  }
  const nE = Math.max(3, Math.round(W / 0.32));
  for (let i = 0; i < nE; i++) {
    const z = -W / 2 + 0.25 + (i + 0.5) * (W - 0.5) / nE;
    const g = new THREE.BoxGeometry(0.06, Hh - 0.3, 0.11); g.translate(-L / 2 - 0.01, Hh / 2, z); parts.push(g);
  }
  return ribCache[k] = mergeGeometries(parts);
}
const holeGeoCache = {};
function makeContainer(color, { L = 6.06, Wd = 2.44, Hh = 2.59, detail = true, cornerColor = null, doors = true } = {}) {
  const g = new THREE.Group();
  const mat = M(color, 0.55, 0.15);
  g.add(box(L - 0.1, Hh - 0.1, Wd - 0.1, mat, 0, Hh / 2, 0));
  if (detail) {
    g.add(mesh(ribGeo(L, Hh, Wd), mat));
    // frame rails
    const fm = M(new THREE.Color(color).multiplyScalar(0.7).getStyle(), 0.5, 0.2);
    for (const y of [0.08, Hh - 0.08]) for (const z of [-Wd / 2, Wd / 2]) g.add(box(L, 0.16, 0.14, fm, 0, y, z));
    for (const x of [-L / 2, L / 2]) for (const z of [-Wd / 2, Wd / 2]) g.add(box(0.16, Hh, 0.16, fm, x, Hh / 2, z));
    if (doors) {
      const dm = M(new THREE.Color(color).multiplyScalar(0.85).getStyle(), 0.5, 0.15);
      g.add(box(0.05, Hh - 0.4, Wd - 0.3, dm, L / 2 + 0.03, Hh / 2, 0));
      for (const z of [-0.75, -0.35, 0.35, 0.75].map(v => v * Wd / 2.44)) g.add(box(0.07, Hh - 0.5, 0.05, M('#9a9a9a', 0.35, 0.8), L / 2 + 0.07, Hh / 2, z));
      g.add(box(0.06, Hh - 0.4, 0.04, M('#333', 0.5), L / 2 + 0.06, Hh / 2, 0));
    }
    // corner castings
    const cm = M(cornerColor || '#c8c8c8', 0.4, 0.6);
    const hm = M('#151515', 0.9);
    for (const x of [-1, 1]) for (const y of [0, 1]) for (const z of [-1, 1]) {
      const cx = x * (L / 2 - 0.08), cy = y ? Hh - 0.09 : 0.09, cz = z * (Wd / 2 - 0.08);
      g.add(box(0.2, 0.18, 0.2, cm, cx, cy, cz));
      // oval hole on side and end
      const hs = mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.02, 16), hm, cx, cy, cz + z * 0.1);
      hs.rotation.x = Math.PI / 2; hs.scale.set(1.6, 1, 1); g.add(hs);
      const he = mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.02, 16), hm, cx + x * 0.1, cy, cz);
      he.rotation.z = Math.PI / 2; he.scale.set(1, 1, 1.6); g.add(he);
    }
  }
  return g;
}
function makeWheel(r = 0.5, w = 0.35) {
  const g = new THREE.Group();
  const t = cyl(r, r, w, M('#1d1d1d', 0.9), 0, 0, 0, 20); t.rotation.x = Math.PI / 2; g.add(t);
  const h = cyl(r * 0.5, r * 0.5, w + 0.02, M('#b9b9b9', 0.4, 0.6), 0, 0, 0, 16); h.rotation.x = Math.PI / 2; g.add(h);
  return g;
}
function makeTruck({ cab = '#c0392b', trailer = 'bales', boxColor = '#2f6f9f', L = 9 } = {}) {
  const g = new THREE.Group();
  const cm = M(cab, 0.45, 0.2);
  // cab at +x
  const cabG = new THREE.Group();
  cabG.add(box(1.8, 1.7, 2.3, cm, 0, 1.75, 0));
  cabG.add(box(1.5, 1.0, 2.1, cm, 1.5, 1.25, 0));          // hood
  cabG.add(box(1.4, 0.15, 2.0, M('#2a2a2a', 0.6), 1.6, 0.75, 0));
  cabG.add(box(0.05, 0.7, 1.9, M('#2b3a44', 0.1, 0.3), 0.92, 2.15, 0)); // windscreen
  cabG.add(box(0.06, 0.6, 1.6, M('#c9c9c9', 0.3, 0.8), 2.27, 1.25, 0)); // grille
  for (const z of [-1, 1]) { const f = cyl(0.55, 0.55, 0.4, cm, 1.5, 0.75, z * 1.0, 16); f.rotation.x = Math.PI / 2; f.scale.set(1, 1, 1); cabG.add(f); }
  for (const z of [-1, 1]) { const hl = cyl(0.14, 0.14, 0.1, M('#fff7d0', 0.2, 0, { emissive: '#fff2b0', emissiveIntensity: 0.4 }), 2.3, 1.45, z * 0.75, 12); hl.rotation.z = Math.PI / 2; cabG.add(hl); }
  cabG.position.x = L / 2 - 0.4;
  g.add(cabG);
  for (const z of [-1, 1]) { const w = makeWheel(); w.position.set(1.5, 0.5, z * 1.05); cabG.add(w); const w2 = makeWheel(); w2.position.set(-0.2, 0.5, z * 1.05); cabG.add(w2); }
  // chassis
  const chassis = new THREE.Group();
  chassis.add(box(L - 1.2, 0.3, 2.0, M('#2a2a2a', 0.7), -0.7, 1.0, 0));
  for (const x of [-L / 2 + 0.5, -L / 2 + 1.7]) for (const z of [-1, 1]) { const w = makeWheel(); w.position.set(x, 0.5, z * 1.05); chassis.add(w); }
  g.add(chassis);
  let load = null;
  if (trailer === 'bales') {
    load = new THREE.Group();
    load.add(box(L - 1.2, 0.2, 2.3, M('#7a5230', 0.8), 0, 0, 0));
    for (const z of [-1, 1]) load.add(box(L - 1.2, 0.8, 0.08, M('#7a5230', 0.8), 0, 0.5, z * 1.12));
    for (let i = 0; i < 6; i++) for (let j = 0; j < 2; j++) for (let k = 0; k < 2; k++) load.add(makeBale(-L / 2 + 1.4 + i * 1.15, 0.45 + k * 0.7, -0.55 + j * 1.1));
    load.position.set(-0.7, 1.25, 0);
    g.add(load);
  } else if (trailer === 'box') {
    load = makeContainer(boxColor, { L: L - 1.4, Wd: 2.44, Hh: 2.59 });
    load.position.set(-0.75, 1.15, 0); g.add(load);
  }
  g.userData = { cab: cabG, chassis, load };
  return g;
}
function makeBale(x = 0, y = 0, z = 0) {
  const g = new THREE.Group(); g.position.set(x, y, z);
  g.add(box(1.05, 0.65, 1.0, M('#efe4c8', 0.95), 0, 0, 0));
  for (const dx of [-0.3, 0, 0.3]) g.add(box(0.04, 0.67, 1.02, M('#6b4a2a', 0.8), dx, 0, 0));
  return g;
}
function makeWorker({ shirt = '#3d5a80', hat = '#4a3a2a', coat = false } = {}) {
  const g = new THREE.Group();
  const body = mesh(new THREE.CapsuleGeometry(0.26, 0.6, 6, 12), M(shirt, 0.8), 0, 0.95, 0); g.add(body);
  const legs = mesh(new THREE.CapsuleGeometry(0.22, 0.4, 6, 12), M(coat ? '#3b3127' : '#2d3142', 0.8), 0, 0.45, 0); g.add(legs);
  g.add(mesh(new THREE.SphereGeometry(0.22, 16, 12), M('#e0ac84', 0.7), 0, 1.6, 0));
  g.add(cyl(0.2, 0.22, 0.14, M(hat, 0.8), 0, 1.78, 0, 16));
  if (coat) g.add(cyl(0.34, 0.34, 0.03, M(hat, 0.8), 0, 1.72, 0, 20));
  else g.add(box(0.25, 0.04, 0.2, M(hat, 0.8), 0.2, 1.73, 0));
  return g;
}
function hullGeo(L, Wd, Hh, bow = 0.18) {
  const s = new THREE.Shape();
  const b = L * bow;
  s.moveTo(-L / 2, -Wd / 2 * 0.85); s.lineTo(L / 2 - b, -Wd / 2);
  s.quadraticCurveTo(L / 2 - b * 0.2, -Wd / 2 * 0.7, L / 2, 0);
  s.quadraticCurveTo(L / 2 - b * 0.2, Wd / 2 * 0.7, L / 2 - b, Wd / 2);
  s.lineTo(-L / 2, Wd / 2 * 0.85); s.quadraticCurveTo(-L / 2 - Wd * 0.15, 0, -L / 2, -Wd / 2 * 0.85);
  const g = new THREE.ExtrudeGeometry(s, { depth: Hh, bevelEnabled: false, curveSegments: 12 });
  g.rotateX(-Math.PI / 2); return g; // extrudes along +y, shape in x/z
}
function makeShip({ L = 40, Wd = 8, Hh = 4, hull = '#26364a', band = '#a33a2a', deck = '#b9ae99', bridge = true, bridgeX = null } = {}) {
  const g = new THREE.Group();
  const lower = mesh(hullGeo(L, Wd, Hh * 0.45), M(band, 0.6)); g.add(lower);
  const upper = mesh(hullGeo(L, Wd, Hh * 0.55), M(hull, 0.55)); upper.position.y = Hh * 0.45; g.add(upper);
  const dk = mesh(hullGeo(L * 0.985, Wd * 0.96, 0.06), M(deck, 0.8)); dk.position.y = Hh; g.add(dk);
  if (bridge) {
    const bx = bridgeX ?? -L / 2 + L * 0.1;
    const wm = M('#f1ede4', 0.6);
    g.add(box(L * 0.1, 2.2, Wd * 0.8, wm, bx, Hh + 1.1, 0));
    g.add(box(L * 0.08, 1.6, Wd * 0.9, wm, bx, Hh + 3.0, 0));
    g.add(box(L * 0.081, 0.45, Wd * 0.91, M('#26323c', 0.2, 0.3), bx, Hh + 3.2, 0));
    g.add(box(L * 0.07, 0.3, Wd * 0.75, M('#f1ede4', 0.6), bx, Hh + 3.95, 0));
    const fun = cyl(0.8, 0.9, 2.6, M('#1f1f1f', 0.6), bx - L * 0.06, Hh + 2.6, 0, 20); g.add(fun);
    g.add(cyl(0.82, 0.82, 0.5, M(band, 0.6), bx - L * 0.06, Hh + 3.4, 0, 20));
  }
  return g;
}
function makeWater(size = 200, color = '#3f8ea3') {
  const geo = new THREE.PlaneGeometry(size, size, 60, 60);
  const m = mesh(geo, new THREE.MeshStandardMaterial({ color, roughness: 0.18, metalness: 0.15, flatShading: false }));
  m.rotation.x = -Math.PI / 2; m.castShadow = false;
  const base = geo.attributes.position.array.slice();
  m.userData.update = t => {
    const p = geo.attributes.position.array;
    for (let i = 0; i < p.length; i += 3) {
      const x = base[i], y = base[i + 1];
      p[i + 2] = 0.12 * Math.sin(x * 0.35 + t * 1.6) + 0.08 * Math.sin(y * 0.5 - t * 1.2);
    }
    geo.attributes.position.needsUpdate = true; geo.computeVertexNormals();
  };
  return m;
}
function makeGantry({ span = 14, h = 14, color = '#e3b23c' } = {}) {
  // portal crane: legs at z = ±span/2, beam along z at height h
  const g = new THREE.Group(); const m = M(color, 0.5, 0.2);
  for (const z of [-span / 2, span / 2]) for (const x of [-1.2, 1.2]) g.add(box(0.5, h, 0.5, m, x, h / 2, z));
  for (const z of [-span / 2, span / 2]) { g.add(box(3, 0.5, 0.6, m, 0, h - 0.25, z)); g.add(box(3, 0.4, 0.6, m, 0, 0.2, z)); }
  for (const x of [-1.2, 1.2]) g.add(box(0.6, 0.8, span + 4, m, x, h, 0));
  const trolley = box(3, 0.6, 1.4, M('#555', 0.5, 0.4), 0, h + 0.6, 0); g.add(trolley);
  const cable = cyl(0.04, 0.04, 1, M('#222', 0.5), 0, 0, 0, 6); g.add(cable);
  const spreader = makeSpreader(); g.add(spreader);
  g.userData = { trolley, cable, spreader, h };
  g.userData.set = (z, y) => { // spreader bottom at height y, trolley z
    trolley.position.z = z; spreader.position.set(0, y, z);
    const top = h + 0.3, bot = y + 0.5; cable.scale.y = Math.max(0.01, top - bot); cable.position.set(0, (top + bot) / 2, z);
  };
  return g;
}
function makeSpreader(L = 6.06, Wd = 2.44) {
  const g = new THREE.Group(); const m = M('#f2c14e', 0.5, 0.2);
  g.add(box(L, 0.3, 0.3, m, 0, 0.25, -Wd / 2 + 0.15)); g.add(box(L, 0.3, 0.3, m, 0, 0.25, Wd / 2 - 0.15));
  g.add(box(0.3, 0.3, Wd, m, -L / 2 + 0.15, 0.25, 0)); g.add(box(0.3, 0.3, Wd, m, L / 2 - 0.15, 0.25, 0));
  g.add(box(1.2, 0.5, 1.2, M('#3a3a3a', 0.6), 0, 0.5, 0));
  for (const x of [-1, 1]) for (const z of [-1, 1]) g.add(box(0.12, 0.25, 0.12, M('#888', 0.4, 0.7), x * (L / 2 - 0.08), 0, z * (Wd / 2 - 0.08)));
  return g;
}
function makePlinth({ w = 8, h = 1.2, d = 4, text = 'HOW IT CLICKED', sub = null } = {}) {
  const g = new THREE.Group();
  g.add(box(w, h, d, M('#4a2814', 0.45, 0.05), 0, h / 2, 0));
  g.add(box(w + 0.2, 0.12, d + 0.2, M('#3a1e0e', 0.4), 0, h, 0));
  const pl = mesh(new THREE.PlaneGeometry(w * 0.6, w * 0.15), new THREE.MeshStandardMaterial({ map: plaqueTex(text, sub), roughness: 0.3, metalness: 0.7 }), 0, h / 2, d / 2 + 0.01);
  g.add(pl);
  return g;
}
const PALETTE = ['#c4492f', '#2f6f9f', '#e09a2d', '#3d8a5a', '#8c3b6b', '#d9622b', '#5b6b7a', '#b8322a', '#1f7a8c', '#e0b33a'];

// ---------- scenes ----------
const scenes = [];
function addScene(start, end, build) {
  const scene = new THREE.Scene(); scene.background = new THREE.Color('#d9c8ad'); scene.environment = envTex; scene.environmentIntensity = 0.45;
  const cam = new THREE.PerspectiveCamera(35, W / H, 0.05, 2000);
  const update = build(scene, cam);
  scenes.push({ start, end, scene, cam, update });
}

// Exhibit (S1 and S12 share a layout)
function buildExhibit(scene, withStack) {
  makeRoom(scene, { size: 60, wallZ: -30 });
  makeLights(scene, { r: 30, dir: [14, 26, 20] });
  const pl = makePlinth({ w: 9, h: 1.4, d: 4.4 }); scene.add(pl);
  const c = makeContainer('#d9622b', { cornerColor: '#d8d2c6' }); c.position.y = 1.46; scene.add(c);
  if (withStack) {
    let k = 0;
    for (let row = 0; row < 3; row++) for (let i = -3; i <= 3; i++) for (let lv = 0; lv < 4 - (Math.abs(i) > 2 ? 1 : 0); lv++) {
      const b = makeContainer(PALETTE[(k++ * 7 + row * 3) % PALETTE.length], { detail: row === 0 && lv < 3, doors: false });
      b.position.set(i * 6.4, lv * 2.62, -12 - row * 2.6); scene.add(b);
    }
    const s = makeShip({ L: 60, Wd: 10, Hh: 4 }); s.position.set(-8, 0, -24); scene.add(s);
    const gnt = makeGantry({ span: 16, h: 16 }); gnt.rotation.y = 0; gnt.position.set(14, 0, -16); gnt.userData.set(0, 11); scene.add(gnt);
  }
  return c;
}
const HOOK_A = [[-6.4, 5.4, 5.6], [-2.4, 3.5, 0.6], 30];
addScene(0, 3.6, (scene, cam) => {
  buildExhibit(scene, true);
  return t => camPath(cam, t, [[0, ...HOOK_A], [3.6, [-8.5, 6.2, 11.5], [-0.6, 3.0, 0], 32]]);
});

// S2: 1937 dock, workers carry bales one by one
addScene(3.6, 13.4, (scene, cam) => {
  makeRoom(scene, { size: 80, wallZ: -40 });
  const L = makeLights(scene, { r: 40, dir: [20, 28, 18] });
  const water = makeWater(160, '#4b8fa0'); water.position.y = 0.2; scene.add(water);
  // pier
  const pt = plankTex.clone(); pt.needsUpdate = true; pt.repeat.set(6, 3);
  const pier = box(50, 0.5, 14, new THREE.MeshStandardMaterial({ map: pt, roughness: 0.8 }), 0, 1.6, 6); scene.add(pier);
  for (let x = -24; x <= 24; x += 4) for (const z of [-0.6, 12.6]) scene.add(cyl(0.3, 0.3, 2, M('#5a3a22', 0.9), x, 0.8, z, 10));
  const ship = makeShip({ L: 40, Wd: 9, Hh: 4.5, hull: '#2d3b4f' }); ship.position.set(2, 0, -6.5); scene.add(ship);
  // gangplank
  const gp = box(1.6, 0.15, 6, M('#8a6a45', 0.8), 4, 3.4, -0.2); gp.rotation.x = -0.3; scene.add(gp);
  const truck = makeTruck({ cab: '#7b2d26', trailer: 'bales' }); truck.position.set(-11, 1.85, 6); scene.add(truck);
  const mc = makeWorker({ shirt: '#6b4f3a', hat: '#3a2e25', coat: true }); mc.position.set(-13.2, 1.85, 9.8); mc.rotation.y = 0.6; mc.scale.setScalar(1.15); scene.add(mc);
  // clock post
  const post = cyl(0.12, 0.12, 4.5, M('#2b2b2b', 0.5, 0.4), -10.2, 4.1, 9.6, 10); scene.add(post);
  const face = cyl(0.9, 0.9, 0.2, M('#f6f0e0', 0.6), -10.2, 6.6, 9.6, 32); face.rotation.x = Math.PI / 2; scene.add(face);
  const rim = mesh(new THREE.TorusGeometry(0.9, 0.08, 8, 32), M('#2b2b2b', 0.4, 0.5), -10.2, 6.6, 9.72); scene.add(rim);
  const hHand = box(0.08, 0.5, 0.03, M('#111'), 0, 0.25, 0), mHand = box(0.05, 0.75, 0.03, M('#111'), 0, 0.37, 0);
  const hp = new THREE.Group(); hp.add(hHand); hp.position.set(-10.2, 6.6, 9.82); scene.add(hp);
  const mp = new THREE.Group(); mp.add(mHand); mp.position.set(-10.2, 6.6, 9.85); scene.add(mp);
  // workers loop
  const path = [V(-11, 1.85, 4.2), V(2, 1.85, 3.0), V(4, 1.85, 2.4), V(4, 4.6, -2.8), V(6, 4.6, -5.5)];
  const curve = new THREE.CatmullRomCurve3(path);
  const workers = [];
  for (let i = 0; i < 6; i++) {
    const w = makeWorker({ shirt: ['#3d5a80', '#4f6d5a', '#7a5c3a', '#3d5a80', '#5b5b75', '#4f6d5a'][i] });
    const b = makeBale(0, 2.25, 0); b.scale.setScalar(0.7); w.add(b); w.userData.bale = b;
    scene.add(w); workers.push(w);
  }
  const sky0 = new THREE.Color('#fff1dc'), sky1 = new THREE.Color('#ffb36b');
  return t => {
    water.userData.update(t);
    workers.forEach((w, i) => {
      const ph = ((t * 0.09 + i / 6) % 1);
      const going = ph < 0.6; const u = going ? ph / 0.6 : 1 - (ph - 0.6) / 0.4;
      const p = curve.getPoint(u); w.position.copy(p);
      w.position.y += Math.abs(Math.sin(t * 9 + i)) * 0.08;
      const p2 = curve.getPoint(clamp(u + (going ? 0.01 : -0.01)));
      w.lookAt(p2.x, w.position.y, p2.z); w.rotateY(-Math.PI / 2);
      w.userData.bale.visible = going;
    });
    mp.rotation.z = -t * 2.6; hp.rotation.z = -t * 0.22;
    mc.rotation.y = 0.6 + Math.sin(t * 1.5) * 0.15;
    L.key.color.copy(sky0).lerp(sky1, seg(t, 2, 8));
    camPath(cam, t, [
      [0, [-21, 8, 23], [-14, 3.2, 8], 34],
      [3.0, [-19, 9, 25], [-12, 3.2, 7], 36],
      [6.2, [-10, 14, 30], [-4, 3, 2], 40],
      [9.8, [4, 16, 32], [0, 3, -1], 42]]);
  };
});

// S3: lift the whole truck onto the ship
addScene(13.4, 18.25, (scene, cam) => {
  makeRoom(scene, { size: 80, wallZ: -40 });
  makeLights(scene, { r: 40, dir: [20, 28, 18], color: '#ffd9a8' });
  const water = makeWater(160, '#4b8fa0'); water.position.y = 0.2; scene.add(water);
  const pt = plankTex.clone(); pt.needsUpdate = true; pt.repeat.set(6, 3);
  scene.add(box(50, 0.5, 14, new THREE.MeshStandardMaterial({ map: pt, roughness: 0.8 }), 0, 1.6, 6));
  const ship = makeShip({ L: 40, Wd: 9, Hh: 4.5, hull: '#2d3b4f' }); ship.position.set(2, 0, -6.5); scene.add(ship);
  const crane = makeGantry({ span: 26, h: 18, color: '#9b8a6a' }); crane.position.set(2, 0, 0); scene.add(crane);
  const truck = makeTruck({ cab: '#7b2d26', trailer: 'bales' }); scene.add(truck);
  // slings
  const sl = new THREE.Group(); for (const x of [-3, 3]) for (const z of [-1, 1]) { const s = cyl(0.03, 0.03, 1, M('#333'), 0, 0, 0, 4); s.userData.o = V(x, 0, z * 1.1); sl.add(s); } scene.add(sl);
  const think = mesh(new THREE.SphereGeometry(0.5, 16, 12), M('#fff4c2', 0.3, 0, { emissive: '#ffe680', emissiveIntensity: 1.2 }));
  scene.add(think);
  return t => {
    water.userData.update(t + 9);
    // 0-1.6 thinking bulb, 1.6-4.8 lift and move
    const up = seg(t, 1.4, 2.8), over = seg(t, 2.6, 3.9), down = seg(t, 3.8, 4.8);
    const y = 1.85 + up * 9 - down * (9 - 2.65), z = lerp(6, -6.5, over);
    truck.position.set(2, y, z); truck.rotation.y = Math.sin(t * 2) * 0.03 * up * (1 - down);
    crane.userData.set(z, y + 5.2);
    crane.userData.spreader.visible = false;
    sl.children.forEach(s => {
      const a = s.userData.o.clone().applyEuler(truck.rotation).add(truck.position).add(V(0, 2.4, 0));
      const b = V(0, y + 5.2, z); const mid = a.clone().add(b).multiplyScalar(0.5);
      s.position.copy(mid); s.scale.y = a.distanceTo(b); s.lookAt(b); s.rotateX(Math.PI / 2);
    });
    think.position.set(-2, 6 + Math.sin(t * 3) * 0.2, 7); think.scale.setScalar(seg(t, 0.1, 0.5) * (1 - seg(t, 1.4, 1.7)) + 0.001);
    camPath(cam, t, [[0, [-14, 7, 30], [0, 5, 2], 36], [4.85, [-4, 13, 34], [2, 6, -2], 38]]);
  };
});

// S4: wheels and cabs wasted space (top-down deck)
addScene(18.25, 21.05, (scene, cam) => {
  makeRoom(scene, { size: 80, wallZ: -40, wood: false, floor: '#4b8fa0' });
  makeLights(scene, { r: 30, dir: [10, 30, 12], color: '#ffe2bd' });
  const water = makeWater(160, '#4b8fa0'); water.position.y = 0.2; scene.add(water);
  const ship = makeShip({ L: 40, Wd: 10, Hh: 4.5, hull: '#2d3b4f', bridge: true, bridgeX: -17 }); scene.add(ship);
  const reds = [];
  for (let i = 0; i < 3; i++) {
    const tr = makeTruck({ cab: ['#7b2d26', '#2d5a7b', '#6b6b2d'][i], trailer: 'box', boxColor: PALETTE[i + 2], L: 8 }); tr.position.set(-6 + i * 10.5, 4.5, i % 2 ? 2.4 : -2.4); scene.add(tr);
    // highlight wasted volumes: cab and under-trailer
    const hm = new THREE.MeshBasicMaterial({ color: '#ff3b2f', transparent: true, opacity: 0.0, depthWrite: false });
    const h1 = new THREE.Mesh(new THREE.BoxGeometry(2.8, 2.7, 2.6), hm); h1.position.set(tr.position.x + 4.6, 4.5 + 1.35, tr.position.z); scene.add(h1);
    const h2 = new THREE.Mesh(new THREE.BoxGeometry(7.0, 1.1, 2.6), hm); h2.position.set(tr.position.x - 0.7, 4.5 + 0.55, tr.position.z); scene.add(h2);
    reds.push(hm);
  }
  return t => {
    water.userData.update(t + 14);
    reds.forEach(m => m.opacity = seg(t, 0.9, 1.4) * (0.55 + 0.15 * Math.sin(t * 8)));
    camPath(cam, t, [[0, [4, 34, 18], [4, 4, 0], 40], [2.8, [8, 30, 12], [4, 4, 0], 36]]);
  };
});

// S5: take the boxes off the wheels
addScene(21.05, 23.35, (scene, cam) => {
  makeRoom(scene, { size: 50, wallZ: -20 });
  makeLights(scene, { r: 20, dir: [14, 24, 16] });
  const tr = makeTruck({ cab: '#2d5a7b', trailer: 'box', boxColor: '#c4492f', L: 9 }); scene.add(tr);
  const crane = makeGantry({ span: 10, h: 10 }); crane.position.set(-0.75, 0, 0); scene.add(crane);
  const load = tr.userData.load;
  return t => {
    const up = seg(t, 0.3, 1.3), drive = seg(t, 1.0, 2.3);
    load.position.y = 1.15 + up * 3.2;
    crane.userData.set(0, load.position.y + 2.59 - 0.05);
    tr.userData.cab.position.x = 9 / 2 - 0.4 + drive * 14;
    tr.userData.chassis.position.x = drive * 14;
    camPath(cam, t, [[0, [-9, 5, 17], [0, 3, 0], 38], [2.3, [-11, 7, 19], [0, 4.2, 0], 38]]);
  };
});

// S6: 1956 tanker with 58 boxes sails
addScene(23.35, 27.45, (scene, cam) => {
  makeRoom(scene, { size: 160, wallZ: -90, wood: true });
  makeLights(scene, { r: 90, dir: [40, 60, 40] });
  const water = makeWater(500, '#3f8ea3'); water.position.y = 0.2; scene.add(water);
  const ship = new THREE.Group(); scene.add(ship);
  const hull = makeShip({ L: 120, Wd: 16, Hh: 6, hull: '#2a2f38', band: '#8f2f24', bridgeX: -50 }); ship.add(hull);
  hull.add(box(14, 4, 13, M('#f1ede4', 0.6), 46, 8, 0)); // forward house (tanker)
  // spar deck
  ship.add(box(84, 0.4, 15, M('#6d6a62', 0.6, 0.3), -2, 7.6, 0));
  for (let x = -42; x <= 38; x += 8) for (const z of [-7, 7]) ship.add(box(0.4, 1.6, 0.4, M('#6d6a62'), x, 6.8, z));
  const boxes = []; let n = 0;
  for (let i = 0; i < 15 && n < 58; i++) for (let j = 0; j < 4 && n < 58; j++) {
    if ((i === 0 && j === 0) || (i === 0 && j === 3)) continue;
    const b = makeContainer(PALETTE[(i * 4 + j * 3) % PALETTE.length], { L: 5.2, Wd: 3.3, Hh: 2.8, detail: false });
    b.userData.p = V(-39 + i * 5.5, 7.8, -5.4 + j * 3.6); b.userData.k = n / 58; ship.add(b); boxes.push(b); n++;
  }
  const label = mesh(new THREE.PlaneGeometry(20, 5), new THREE.MeshBasicMaterial({ map: canvasTex(1024, 256, (g, w, h) => { g.fillStyle = '#fff'; g.font = '700 150px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('58', w / 2, h / 2); }), transparent: true }));
  return t => {
    water.userData.update(t);
    boxes.forEach(b => { const a = 0.2 + b.userData.k * 1.4; const k = seg(t, a, a + 0.4); b.position.copy(b.userData.p); b.position.y += (1 - k) * 25; b.visible = k > 0.001; });
    const sail = seg(t, 1.8, 4.1) * 0 + Math.max(0, t - 1.8) * 6;
    ship.position.set(sail, Math.sin(t * 1.2) * 0.15, 0); ship.rotation.x = Math.sin(t * 1.1) * 0.01;
    camPath(cam, t, [[0, [70, 55, 110], [0, 6, 0], 34], [1.8, [70, 40, 95], [0, 6, 0], 36], [4.1, [100, 22, 70], [16, 6, 0], 40]]);
  };
});

// S7: cost per ton falls
addScene(27.45, 32.45, (scene, cam) => {
  makeRoom(scene, { size: 30, wallZ: -12 });
  makeLights(scene, { r: 12, dir: [8, 14, 10] });
  const pl = makePlinth({ w: 6, h: 1.2, d: 3.5, text: 'COST PER TON' }); scene.add(pl);
  const coins = [];
  const N = 58;
  for (let i = 0; i < N; i++) {
    const c = cyl(0.8, 0.8, 0.12, M('#d4a73a', 0.3, 0.9), Math.sin(i * 2.1) * 0.03, 1.32 + i * 0.125, Math.cos(i * 1.7) * 0.03, 40);
    scene.add(c); coins.push(c);
  }
  const tag = canvasTex(512, 256, () => { });
  const tagM = mesh(new THREE.PlaneGeometry(2.4, 1.2), new THREE.MeshStandardMaterial({ map: tag, roughness: 0.6 }), 1.9, 2.6, 1.0);
  tagM.rotation.y = -0.25; scene.add(tagM);
  const str = cyl(0.01, 0.01, 1.2, M('#444'), 1.4, 3.0, 0.8, 4); str.rotation.z = 1.0; scene.add(str);
  let lastTxt = '';
  return t => {
    const k = seg(t, 1.0, 4.2);
    const val = lerp(5.86, 0.16, k);
    const keep = Math.max(2, Math.round(lerp(N, 2, k)));
    coins.forEach((c, i) => {
      const gone = i >= keep; const dt = gone ? (k * N - (N - i)) : 0;
      c.visible = !gone || dt < 3;
      if (gone) { c.position.x = 0.03 + Math.min(3, dt) * 1.4; c.position.y = 1.32 + i * 0.125 + Math.min(3, dt) * 0.8; c.rotation.z = dt; c.scale.setScalar(Math.max(0.01, 1 - dt / 3)); }
    });
    const txt = '$' + val.toFixed(2);
    if (txt !== lastTxt) {
      lastTxt = txt; const g = tag.userData.canvas.getContext('2d');
      g.fillStyle = '#f4ead2'; g.fillRect(0, 0, 512, 256); g.strokeStyle = '#7a5a2a'; g.lineWidth = 10; g.strokeRect(8, 8, 496, 240);
      g.beginPath(); g.arc(50, 128, 18, 0, 7); g.fillStyle = '#d9c8ad'; g.fill();
      g.fillStyle = k > 0.98 ? '#2e7d32' : '#3a2a12'; g.font = '700 130px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(txt, 280, 135);
      tag.needsUpdate = true;
    }
    camPath(cam, t, [[0, [3, 7.5, 14], [0.4, 4.0, 0], 34], [5, [2, 4.5, 11], [0.6, 2.4, 0], 34]]);
  };
});

// S8: different boxes, different hooks; crane can't lift
addScene(32.45, 40.0, (scene, cam) => {
  makeRoom(scene, { size: 60, wallZ: -16 });
  makeLights(scene, { r: 25, dir: [14, 24, 18] });
  const specs = [
    { c: '#3d8a5a', L: 5.0, H: 2.2, W: 2.2, hook: 'ring' },
    { c: '#8c3b6b', L: 7.5, H: 2.9, W: 2.6, hook: 'bar' },
    { c: '#2f6f9f', L: 4.0, H: 3.2, W: 2.4, hook: 'post' },
    { c: '#e09a2d', L: 6.5, H: 2.5, W: 2.0, hook: 'ring' }];
  let x = -14; const boxes = [];
  specs.forEach((s, i) => {
    const b = makeContainer(s.c, { L: s.L, Hh: s.H, Wd: s.W, detail: true, doors: i % 2 === 0 });
    b.position.set(x + s.L / 2, 0, 0); scene.add(b); boxes.push(b);
    const hm = M('#3a3a3a', 0.5, 0.6);
    for (const dx of [-s.L / 3, s.L / 3]) {
      if (s.hook === 'ring') { const r = mesh(new THREE.TorusGeometry(0.28, 0.07, 8, 16), hm, dx, s.H + 0.28, 0); b.add(r); }
      if (s.hook === 'bar') { b.add(box(0.15, 0.4, s.W * 0.8, hm, dx, s.H + 0.2, 0)); }
      if (s.hook === 'post') { b.add(cyl(0.12, 0.12, 0.6, hm, dx, s.H + 0.3, 0, 10)); b.add(mesh(new THREE.SphereGeometry(0.2, 12, 8), hm, dx, s.H + 0.65, 0)); }
    }
    x += s.L + 1.4;
  });
  const crane = makeGantry({ span: 10, h: 11 }); scene.add(crane);
  return t => {
    // crane travels to box 2 (bar hooks), lowers; spreader doesn't match; box wobbles; spreader rises
    const target = boxes[1];
    const cx = lerp(-12, target.position.x, seg(t, 3.6, 4.6));
    crane.position.x = cx;
    const down = seg(t, 4.6, 5.4), up = seg(t, 6.3, 7.2);
    const sy = lerp(7, 2.9 + 0.45, down) + up * 4;
    crane.userData.set(0.6 * down * (1 - up), sy);
    crane.userData.spreader.rotation.y = 0.12 * down * (1 - up);
    const wob = Math.max(0, Math.sin((t - 5.4) * 14)) * Math.exp(-(t - 5.4) * 2.5) * (t > 5.4 ? 1 : 0);
    target.rotation.z = wob * 0.05;
    camPath(cam, t, [[0, [-16, 7, 17], [-10, 2, 0], 36], [3.4, [6, 8, 22], [0, 2.4, 0], 38], [7.5, [-2, 7, 16], [-4.5, 3.6, 0], 36]]);
  };
});

// S9: corner casting with oval hole + twistlock (cutaway macro, units = 0.1 m)
function castingGeo() {
  // a hollow cube 2x2x2 with oval holes on top and bottom, open front (cutaway)
  const parts = [];
  const plate = (hole) => {
    const s = new THREE.Shape(); s.moveTo(-1, -1); s.lineTo(1, -1); s.lineTo(1, 1); s.lineTo(-1, 1); s.lineTo(-1, -1);
    if (hole) { const h = new THREE.Path(); h.absellipse(0, 0, 0.62, 0.32, 0, Math.PI * 2, true); s.holes.push(h); }
    const g = new THREE.ExtrudeGeometry(s, { depth: 0.25, bevelEnabled: true, bevelSize: 0.04, bevelThickness: 0.04, bevelSegments: 2, curveSegments: 28 });
    return g;
  };
  const top = plate(true); top.rotateX(-Math.PI / 2); top.translate(0, 0.875, 0); parts.push(top);
  const bot = plate(true); bot.rotateX(-Math.PI / 2); bot.translate(0, -1.0, 0); parts.push(bot);
  const back = new THREE.BoxGeometry(2, 2, 0.25); back.translate(0, 0, -0.875); parts.push(back);
  const l = new THREE.BoxGeometry(0.25, 2, 2); l.translate(-0.875, 0, 0); parts.push(l);
  const r = new THREE.BoxGeometry(0.25, 2, 2); r.translate(0.875, 0, 0); parts.push(r);
  return mergeGeometries(parts.map(p => p.toNonIndexed()));
}
function makeTwistlock() {
  const g = new THREE.Group(); const m = M('#c9a227', 0.3, 0.85);
  const cone = (y, flip) => { const c = mesh(new THREE.ConeGeometry(0.55, 0.9, 32), m, 0, y * 1.2, 0); c.scale.set(1, 1, 0.5); if (flip) c.rotation.x = Math.PI; return c; };
  const head = new THREE.Group(); head.add(cone(0.75, false)); head.add(cyl(0.28, 0.28, 0.7, m, 0, 0.3, 0, 20)); g.add(head);
  const foot = new THREE.Group(); foot.add(cone(-0.75, true)); foot.add(cyl(0.28, 0.28, 0.7, m, 0, -0.3, 0, 20)); g.add(foot);
  const flange = box(1.6, 0.18, 1.1, m, 0, 0, 0); g.add(flange);
  const handle = box(0.12, 0.12, 1.4, m, 0, 0, 0.8); g.add(handle);
  g.userData = { head, foot, handle };
  return g;
}
addScene(40.0, 47.2, (scene, cam) => {
  scene.background = new THREE.Color('#d9c8ad');
  makeRoom(scene, { size: 30, wallZ: -14 });
  makeLights(scene, { r: 12, dir: [6, 12, 9] });
  const cm = M('#b9b4aa', 0.38, 0.75);
  const geo = castingGeo();
  const lower = mesh(geo, cm, 0, 2.0, 0); scene.add(lower);
  const upper = mesh(geo, cm, 0, 4.4, 0); scene.add(upper);
  // container walls attached (partial, red, ribbed)
  const wm = M('#c4492f', 0.55, 0.15);
  const lw = new THREE.Group(); lw.add(box(9, 0.3, 1.6, wm, -5.5, 2.6, -0.1)); lw.add(box(9, 2.6, 0.3, wm, -5.5, 1.6, -0.85)); lw.add(box(1.6, 2.0, 0.3, wm, 0, 0, -0.85));
  scene.add(lw);
  const uwG = new THREE.Group(); uwG.add(box(9, 0.3, 1.6, wm, -5.5, -0.6, -0.1)); uwG.add(box(9, 2.6, 0.3, wm, -5.5, 0.4, -0.85)); upper.add(uwG);
  scene.add(box(2.4, 2.0, 2.4, M('#7d6b55', 0.8), 0, 0, 0)); // stand
  const tl = makeTwistlock(); scene.add(tl);
  tl.position.set(0, 3.27, 0);
  const glow = mesh(new THREE.TorusGeometry(1.2, 0.05, 8, 48), new THREE.MeshBasicMaterial({ color: '#ffe9a0', transparent: true, opacity: 0, depthWrite: false }), 0, 3.3, 0);
  glow.rotation.x = Math.PI / 2; scene.add(glow);
  return t => {
    // upper casting descends (t 3.2-4.8) onto twistlock; head turns (5.8-6.6); lock pulse at ~6.8
    const d = seg(t, 3.4, 4.8);
    upper.position.y = lerp(7.2, 4.4, d);
    const turn = seg(t, 5.8, 6.6) * Math.PI / 2;
    tl.userData.head.rotation.y = turn; tl.userData.handle.rotation.y = 0; tl.userData.handle.position.x = Math.sin(turn) * 0.8; tl.userData.handle.position.z = Math.cos(turn) * 0.8; tl.userData.handle.rotation.y = turn;
    const pulse = seg(t, 6.7, 6.9) * (1 - seg(t, 6.9, 7.3));
    glow.material.opacity = pulse; glow.scale.setScalar(1 + seg(t, 6.7, 7.3) * 0.6);
    if (t > 6.75 && t < 6.95) upper.position.y = 4.4 - 0.04 * Math.sin((t - 6.75) * 30);
    camPath(cam, t, [
      [0, [-14, 9, 18], [-4, 3, 0], 34],
      [1.4, [-6, 6.5, 11], [-1, 3.5, 0], 34],
      [3.0, [1.5, 5.5, 8.2], [0, 4.0, 0], 32],
      [5.6, [3.2, 5.0, 7.2], [0, 4.1, 0], 30],
      [7.2, [2.2, 6.2, 7.0], [0, 4.1, 0], 30]]);
  };
});

// S10: rivals pay -> patents given away free
addScene(47.2, 53.75, (scene, cam) => {
  makeRoom(scene, { size: 30, wallZ: -12 });
  makeLights(scene, { r: 14, dir: [8, 14, 10] });
  const pl = makePlinth({ w: 5, h: 1.6, d: 3, text: 'PATENT' }); scene.add(pl);
  const cm = M('#b9b4aa', 0.38, 0.75);
  const cast = mesh(castingGeo(), cm, 0, 2.45, 0); cast.scale.setScalar(0.8); scene.add(cast);
  const tl = makeTwistlock(); tl.scale.setScalar(0.8); tl.position.set(0, 3.5, 0); scene.add(tl);
  // rival boxes waiting
  const rivals = [];
  for (let i = 0; i < 4; i++) { const b = makeContainer(PALETTE[i * 2 + 1], { L: 2.4, Wd: 1.2, Hh: 1.2, detail: false }); b.position.set(-7 + i * 4.6 - (i > 1 ? 0 : 0), 0, -4 + (i % 2) * 0.6); if (i === 1 || i === 2) b.position.x += i === 1 ? -0.5 : 7; scene.add(b); rivals.push(b); }
  // coins dropping into dish
  const dish = cyl(1.2, 0.9, 0.3, M('#8a6a2a', 0.4, 0.7), 2.2, 1.75, 1.0, 32); scene.add(dish);
  const coins = []; for (let i = 0; i < 8; i++) { const c = cyl(0.3, 0.3, 0.06, M('#d4a73a', 0.3, 0.9), 0, 0, 0, 24); scene.add(c); coins.push(c); }
  // stamp tag
  const tag = canvasTex(512, 200, () => { }); let state = '';
  const tagM = mesh(new THREE.PlaneGeometry(2.2, 0.86), new THREE.MeshStandardMaterial({ map: tag, roughness: 0.6, side: THREE.DoubleSide }), -2.4, 3.4, 1.2); tagM.rotation.y = 0.3; scene.add(tagM);
  // blueprint sheets
  const bp = canvasTex(256, 320, (g, w, h) => {
    g.fillStyle = '#1f4e8c'; g.fillRect(0, 0, w, h); g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = 3;
    g.strokeRect(12, 12, w - 24, h - 24); g.strokeRect(60, 70, 136, 136); g.beginPath(); g.ellipse(128, 138, 40, 20, 0, 0, 7); g.stroke();
    g.font = '600 26px Georgia'; g.fillStyle = '#fff'; g.textAlign = 'center'; g.fillText('PATENT', 128, 260);
  });
  const sheets = [];
  for (let i = 0; i < 14; i++) {
    const s = mesh(new THREE.PlaneGeometry(1.1, 1.4), new THREE.MeshStandardMaterial({ map: bp, side: THREE.DoubleSide, roughness: 0.8 }));
    s.castShadow = true; s.userData.dir = V(Math.cos(i * 2.4) * (4 + (i % 3) * 2), 3 + (i % 4) * 1.4, Math.sin(i * 2.4) * 3 + 2); s.visible = false; scene.add(s); sheets.push(s);
  }
  return t => {
    // t 0-3.2 rivals pay; 3.2+ free
    coins.forEach((c, i) => {
      const a = 0.9 + i * 0.28, k = clamp((t - a) / 0.45);
      c.visible = t > a && t < 3.3; c.position.set(2.2 + Math.sin(i) * 0.4, lerp(7, 1.95 + i * 0.03, k * k), 1.0 + Math.cos(i) * 0.3); c.rotation.x = (1 - k) * 4;
    });
    const s = t < 3.25 ? 'pay' : 'free';
    if (s !== state) {
      state = s; const g = tag.userData.canvas.getContext('2d');
      g.fillStyle = '#f4ead2'; g.fillRect(0, 0, 512, 200);
      g.strokeStyle = s === 'pay' ? '#8f2f24' : '#2e7d32'; g.lineWidth = 12; g.strokeRect(10, 10, 492, 180);
      g.fillStyle = g.strokeStyle; g.font = '700 96px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(s === 'pay' ? 'ROYALTY' : 'FREE', 256, 104); tag.needsUpdate = true;
    }
    const pop = seg(t, 3.25, 3.45); tagM.scale.setScalar(t < 3.25 ? 1 : 0.8 + 0.2 * pop + 0.15 * Math.sin(pop * Math.PI));
    sheets.forEach((sh, i) => {
      const a = 3.3 + i * 0.07, k = clamp((t - a) / 2.4);
      sh.visible = t > a; const e = 1 - Math.pow(1 - k, 2);
      sh.position.set(sh.userData.dir.x * e, 3.6 + sh.userData.dir.y * e - k * k * 1.5, sh.userData.dir.z * e);
      sh.rotation.set(k * 5 + i, k * 3, k * 2 + i * 0.5);
    });
    rivals.forEach((b, i) => { b.position.y = Math.max(0, Math.sin((t - 1.0 - i * 0.2) * 6)) * 0.25 * (t > 1 && t < 3.2 ? 1 : 0) + (t > 4 ? Math.abs(Math.sin((t - 4) * 5 + i)) * 0.4 * (1 - seg(t, 5.5, 6.5)) : 0); });
    camPath(cam, t, [[0, [-3, 6, 12], [0, 2.8, 0], 36], [3.2, [-1, 5.2, 10], [0, 3, 0], 36], [6.55, [0, 7.5, 16], [0, 3.5, 0], 40]]);
  };
});

// S11: any crane, any box, onto ship, truck, train (laid out front-to-back for vertical frame)
addScene(53.75, 59.4, (scene, cam) => {
  makeRoom(scene, { size: 90, wallZ: -60 });
  makeLights(scene, { r: 45, dir: [25, 35, 25] });
  const water = makeWater(80, '#3f8ea3'); water.position.set(0, 0.25, -58); scene.add(water);
  scene.add(box(90, 1.4, 40, M('#cfc6b4', 0.9), 0, 0.7, 0)); // quay slab z -20..20
  const ship = makeShip({ L: 34, Wd: 8, Hh: 3.6, hull: '#26364a' }); ship.position.set(0, 0, -26); scene.add(ship);
  const truck = makeTruck({ cab: '#2d5a7b', trailer: 'none', L: 8 }); truck.position.set(0, 1.4, -6); scene.add(truck);
  for (const z of [-0.75, 0.75]) scene.add(box(60, 0.15, 0.15, M('#777', 0.4, 0.8), 0, 1.5, 8 + z));
  for (let i = -14; i < 14; i++) scene.add(box(0.4, 0.12, 2.6, M('#5a3a22'), i * 2, 1.45, 8));
  const car = new THREE.Group(); car.add(box(7.5, 0.4, 2.6, M('#4a4a4a', 0.6), 0, 1.0, 0));
  for (const x of [-2.8, 2.8]) for (const z of [-0.75, 0.75]) { const w = cyl(0.42, 0.42, 0.2, M('#222'), x, 0.5, z, 16); w.rotation.x = Math.PI / 2; car.add(w); }
  car.position.set(0, 1.4, 8); scene.add(car);
  const targets = [{ z: -26, y: 3.6, land: 2.6 }, { z: -6, y: 1.4 + 1.15, land: 3.9 }, { z: 8, y: 1.4 + 1.2, land: 4.6 }];
  const cranes = [], loads = [];
  targets.forEach((tg, i) => {
    const c = makeGantry({ span: 12, h: 13 }); c.position.set(0, 0, tg.z); scene.add(c); cranes.push(c);
    const bx = makeContainer(PALETTE[[0, 1, 2][i] * 3 % PALETTE.length]); bx.position.set(0, 0, tg.z); scene.add(bx); loads.push(bx);
  });
  return t => {
    water.userData.update(t);
    targets.forEach((tg, i) => {
      const k = seg(t, tg.land - 1.4, tg.land);
      const y = lerp(tg.y + 6, tg.y, k);
      loads[i].position.y = y; cranes[i].userData.set(0, y + 2.59 - 0.05);
    });
    camPath(cam, t, [[0, [18, 20, 30], [0, 3, -14], 44], [5.65, [12, 16, 32], [0, 3, -8], 44]]);
  };
});

// S12: today — pull through the port to the exhibit corner (loops to S1)
addScene(59.4, 65.6, (scene, cam) => {
  buildExhibit(scene, true);
  return t => camPath(cam, t, [[0, [10, 18, 34], [-4, 5, -14], 38], [3.6, [-6, 8, 14], [-2, 3, 0], 34], [6.2, ...HOOK_A]]);
});

// ---------- captions ----------
const CAPS = [
  ['Every shipping container', 0.0], ['on Earth has the same', 1.8], ['steel corners.', 2.7],
  ['In 1937,', 3.78], ['trucker Malcolm McLean', 5.25], ['waited all day', 6.69], ['at a New Jersey dock,', 8.14],
  ['as workers unloaded', 9.63], ['his cotton bales,', 10.72], ['one by one.', 12.05],
  ['So, he wondered...', 13.54], ['why not lift the whole truck', 15.0], ['onto the ship?', 16.6],
  ['But, wheels and cabs', 18.34], ['wasted precious space.', 19.41],
  ['So, he took the boxes', 21.16], ['off the wheels,', 22.42], ['and in 1956,', 23.44], ['an old tanker sailed', 24.84], ['with fifty-eight of them.', 25.9],
  ['Loading costs fell', 27.56], ['from nearly six dollars a ton,', 28.51], ['to sixteen cents.', 30.71],
  ['But, every company', 32.57], ['built different boxes,', 33.7], ['with different hooks.', 35.06], ['A crane in one port', 36.66], ["couldn't lift a box", 37.96], ['from another.', 38.71],
  ['So, engineer', 40.11], ['Keith Tantlinger', 40.76], ['designed a steel corner', 41.5], ['with an oval hole,', 43.01], ['and a twistlock', 44.72], ['that turns,', 45.84], ['and locks.', 46.73],
  ['But,', 47.3], ['rivals would have to pay', 48.05], ['to use it.', 49.07],
  ['So, McLean', 50.42], ['gave the patents away,', 50.9], ['for free.', 52.58],
  ['Now, one crane', 53.87], ['could lift any box,', 54.7], ['onto any ship,', 56.25], ['truck,', 57.65], ['or train.', 58.28],
  ['Today, almost everything', 59.55], ['you own', 61.25], ['once rode in a steel box,', 61.67], ['locked at the same steel corners.', 63.25],
];
function wrap(text, maxW) {
  const words = text.split(' '); const lines = []; let cur = '';
  for (const w of words) { const t = cur ? cur + ' ' + w : w; if (ctx.measureText(t).width > maxW && cur) { lines.push(cur); cur = w; } else cur = t; }
  lines.push(cur); return lines;
}
function drawCaption(t) {
  let c = null; for (const k of CAPS) if (t >= k[1]) c = k[0];
  if (!c) return;
  ctx.save();
  ctx.font = '500 38px Jost'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  const lines = wrap(c, 400); const lh = 44; const y0 = H * 0.66 - (lines.length - 1) * lh / 2;
  lines.forEach((l, i) => {
    ctx.shadowColor = 'rgba(0,0,0,0.55)'; ctx.shadowBlur = 10; ctx.shadowOffsetY = 2;
    ctx.fillStyle = '#ffffff'; ctx.fillText(l, W / 2, y0 + i * lh);
    ctx.shadowBlur = 3; ctx.fillText(l, W / 2, y0 + i * lh);
  });
  ctx.restore();
}
const vign = (() => { const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, H * 0.75); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(20,10,0,0.28)'); return g; })();

window.renderFrame = (t) => {
  const s = scenes.find(s => t >= s.start && t < s.end) || scenes[scenes.length - 1];
  s.update(t - s.start);
  renderer.render(s.scene, s.cam);
  ctx.drawImage(renderer.domElement, 0, 0);
  ctx.fillStyle = vign; ctx.fillRect(0, 0, W, H);
  drawCaption(t);
  return out.toDataURL('image/jpeg', 0.93);
};
window.DURATION = 65.6;
document.fonts.load('500 44px Jost').then(() => { window.ready = true; });
