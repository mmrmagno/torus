import { donutFrame } from "/home/mmr/dev/priv/marc-os-blog/src/lib/donut.ts";
import { grid, step, W, H, ramp, LOOP, loopAngles } from "../../donut/donut.mjs";

function parse(html: string): number[] {
  const out: number[] = [];
  const re = /<span class="d(\d+)">([^<]*)<\/span>|([^<\n]+)|\n/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html))) {
    if (m[1] !== undefined) for (const _ of m[2]) out.push(Number(m[1]));
    else if (m[3] !== undefined) for (const _ of m[3]) out.push(-1);
  }
  return out;
}

const fail = (msg: string) => { console.error("FAIL: " + msg); Deno.exit(1); };
for (const [a, b] of [[1, 1], [2.3, 0.7], [5, 4]]) {
  const ref = parse(donutFrame(a, b));
  const ours = Array.from(grid(a, b));
  if (ref.length !== W * H) fail(`reference parse length ${ref.length}`);
  if (ours.join(",") !== ref.join(",")) fail(`grid mismatch at A=${a} B=${b}`);
}
const [a2, b2] = step(1, 1);
if (Math.abs(a2 - 1.07) > 1e-9 || Math.abs(b2 - 1.03) > 1e-9) fail("step");
const big = grid(1, 1, 120, 60);
if (big.length !== 7200 || !big.some((v) => v >= 0)) fail("scaled grid empty");
const pal = JSON.parse(Deno.readTextFileSync(new URL("../../theme/mocha.json", import.meta.url)));
const r = ramp(pal);
if (r.length !== 12) fail("ramp length");
if (r[8] !== pal.mauve || r[11] !== pal.lavender) fail(`ramp anchors ${r[8]} ${r[11]}`);
if (LOOP !== 628) fail("loop length");
const [la0, lb0] = loopAngles(0);
const [laN, lbN] = loopAngles(LOOP);
if (la0 !== 1 || lb0 !== 1) fail("loop start");
if (Math.abs((laN - la0) - 14 * Math.PI) > 1e-9 || Math.abs((lbN - lb0) - 6 * Math.PI) > 1e-9) fail("loop not periodic");
if (grid(...loopAngles(0)).join() !== grid(...loopAngles(LOOP)).join()) fail("loop frames differ at wrap");
const [la1, lb1] = loopAngles(1);
if (Math.abs(la1 - 1.07) > 1e-3 || Math.abs(lb1 - 1.03) > 1e-3) fail("loop speed drifts from the site");
console.log("donut ok");
