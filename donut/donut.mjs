export const W = 40;
export const H = 20;
export const CHARS = '.,-~:;=!*#$@';

const R1 = 1;
const R2 = 2;
const K2 = 5;

export function grid(A, B, w = W, h = H) {
  const K1 = (w * K2 * 3) / (8 * (R1 + R2));
  const K1Y = K1 / 2;
  const tStep = w === W ? 0.07 : (0.07 * W) / w;
  const pStep = w === W ? 0.02 : (0.02 * W) / w;
  const size = w * h;
  const lum = new Int8Array(size).fill(-1);
  const zbuf = new Float32Array(size);
  const cA = Math.cos(A), sA = Math.sin(A);
  const cB = Math.cos(B), sB = Math.sin(B);

  for (let t = 0; t < 6.283; t += tStep) {
    const ct = Math.cos(t), st = Math.sin(t);
    const cx = R2 + R1 * ct;
    const cy = R1 * st;
    for (let p = 0; p < 6.283; p += pStep) {
      const cp = Math.cos(p), sp = Math.sin(p);
      const x = cx * (cB * cp + sA * sB * sp) - cy * cA * sB;
      const y = cx * (sB * cp - sA * cB * sp) + cy * cA * cB;
      const ooz = 1 / (K2 + cA * cx * sp + cy * sA);
      const xp = Math.floor(w / 2 + K1 * ooz * x);
      const yp = Math.floor(h / 2 - K1Y * ooz * y);
      if (xp < 0 || xp >= w || yp < 0 || yp >= h) continue;
      const L = cp * ct * sB - cA * ct * sp - sA * st + cB * (cA * st - ct * sA * sp);
      const i = yp * w + xp;
      if (L > 0 && ooz > zbuf[i]) {
        zbuf[i] = ooz;
        lum[i] = Math.min(11, Math.floor(L * 8));
      }
    }
  }
  return lum;
}

export function step(A, B) {
  return [A + 0.07, B + 0.03];
}

export const LOOP = 628;

export function loopAngles(i) {
  return [1 + (i * 14 * Math.PI) / LOOP, 1 + (i * 6 * Math.PI) / LOOP];
}

export const RAMP_MIX = [
  ['mauve', 0.28, 'base'],
  ['mauve', 0.36, 'base'],
  ['mauve', 0.44, 'base'],
  ['mauve', 0.52, 'base'],
  ['mauve', 0.60, 'base'],
  ['mauve', 0.68, 'base'],
  ['mauve', 0.77, 'base'],
  ['mauve', 0.88, 'base'],
  ['mauve', 1, 'base'],
  ['mauve', 0.70, 'lavender'],
  ['mauve', 0.40, 'lavender'],
  ['mauve', 0, 'lavender'],
];

function toLinear(c) {
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function fromLinear(c) {
  return c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055;
}

function hexToOklab(hex) {
  const n = parseInt(hex.slice(1), 16);
  const r = toLinear(((n >> 16) & 255) / 255);
  const g = toLinear(((n >> 8) & 255) / 255);
  const b = toLinear((n & 255) / 255);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}

function oklabToHex([L, a, b]) {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  const rgb = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
  return '#' + rgb
    .map((c) => Math.round(Math.min(1, Math.max(0, fromLinear(c))) * 255).toString(16).padStart(2, '0'))
    .join('');
}

export function mix(a, p, b) {
  if (p >= 1) return a;
  if (p <= 0) return b;
  const x = hexToOklab(a);
  const y = hexToOklab(b);
  return oklabToHex(x.map((v, i) => v * p + y[i] * (1 - p)));
}

export function ramp(palette) {
  return RAMP_MIX.map(([a, p, b]) => mix(palette[a], p, palette[b]));
}

const DAY = [
  [0, 'lavender'],
  [5, 'blue'],
  [7, 'peach'],
  [11, 'sky'],
  [16, 'mauve'],
  [19, 'pink'],
  [22, 'lavender'],
  [24, 'lavender'],
];

export function living(palette, hour, art, on) {
  if (!on) return palette;
  const h = ((hour % 24) + 24) % 24;
  let i = 0;
  while (i < DAY.length - 2 && DAY[i + 1][0] <= h) i++;
  const [h0, a] = DAY[i];
  const [h1, b] = DAY[i + 1];
  const tod = mix(palette[a], 1 - (h - h0) / (h1 - h0), palette[b]);
  let accent = mix(palette.mauve, 0.55, tod);
  if (/^#[0-9a-f]{6}$/i.test(art || '')) accent = mix(accent, 0.6, art);
  return Object.assign({}, palette, { mauve: accent, lavender: mix(palette.lavender, 0.7, accent) });
}

function xbox(px, py, pz, bx, by, bz) {
  const qx = Math.abs(px) - bx, qy = Math.abs(py) - by, qz = Math.abs(pz) - bz;
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0), oz = Math.max(qz, 0);
  return Math.hypot(ox, oy, oz) + Math.min(Math.max(qx, Math.max(qy, qz)), 0);
}

function xcap(px, py, pz, z0, z1, r) {
  const z = pz - Math.min(Math.max(pz, z0), z1);
  return Math.hypot(px, py, z) - r;
}

function xship(x, y, z) {
  const body = xbox(x, y, z - 0.2, 0.16, 0.17, 1.35) - 0.04;
  const nose = xcap(x, y * 1.15, z, 1.2, 2.1, 0.12);
  const cockpit = Math.hypot(x * 2.6, (y - 0.2) * 3.0, z - 0.35) - 0.42;
  const mx = Math.abs(x), my = Math.abs(y);
  const a = 0.4, ca = Math.cos(a), sa = Math.sin(a);
  const wx = mx * ca + my * sa, wy = -mx * sa + my * ca;
  const wing = xbox(wx - 1.1, wy, z + 0.75, 0.95, 0.03, 0.42 - 0.12 * (wx - 0.2));
  const engine = xcap(mx - 0.36, my - 0.17, z, -1.35, -0.25, 0.13);
  const gun = xcap(mx - 2.05 * ca, my - 2.05 * sa, z, -1.0, 1.25, 0.05);
  return Math.min(body, nose, cockpit, wing, engine, gun);
}

export function xwing(A, B, w = W, h = H) {
  const K = 5;
  const cy = Math.cos(A), sy = Math.sin(A);
  const tilt = 0.35 * Math.sin(B), cx = Math.cos(tilt), sx = Math.sin(tilt);
  const scene = (x, y, z) => {
    z -= K;
    const rx = x * cy + z * sy, rz = -x * sy + z * cy;
    return xship(rx, y * cx - rz * sx, y * sx + rz * cx);
  };
  const k1 = (w * K * 3) / (8 * 2.25);
  const lum = new Int8Array(w * h).fill(-1);
  const lx = 0.35, ly = 0.8, lz = -0.6, ln = Math.hypot(lx, ly, lz);
  for (let r = 0; r < h; r++) {
    for (let c = 0; c < w; c++) {
      let dx = (c + 0.5 - w / 2) / k1, dy = -(r + 0.5 - h / 2) / (k1 * 0.5), dz = 1;
      const dl = Math.hypot(dx, dy, dz);
      dx /= dl; dy /= dl; dz /= dl;
      let s = K - 3;
      let hit = false;
      for (let i = 0; i < 72; i++) {
        const d = scene(dx * s, dy * s, dz * s);
        if (d < 0.002) { hit = true; break; }
        s += d;
        if (s > K + 3) break;
      }
      if (!hit) continue;
      const px = dx * s, py = dy * s, pz = dz * s, e = 0.002;
      let nx = scene(px + e, py, pz) - scene(px - e, py, pz);
      let ny = scene(px, py + e, pz) - scene(px, py - e, pz);
      let nz = scene(px, py, pz + e) - scene(px, py, pz - e);
      const nl = Math.hypot(nx, ny, nz) || 1;
      const L = 0.18 + 0.82 * Math.max((nx * lx + ny * ly + nz * lz) / (nl * ln), 0);
      lum[r * w + c] = Math.min(11, Math.floor(L * 11.99));
    }
  }
  return lum;
}
