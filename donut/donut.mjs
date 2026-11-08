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
