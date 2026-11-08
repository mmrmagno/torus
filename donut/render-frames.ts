import { grid, ramp, step, CHARS, W, H } from "./donut.mjs";

const [out, countArg, widthArg] = Deno.args;
if (!out || !countArg || !widthArg) {
  console.error("usage: render-frames.ts <out-dir> <count> <px-width> [background-name]");
  Deno.exit(1);
}
const count = Number(countArg);
const width = Number(widthArg);
const palette = JSON.parse(Deno.readTextFileSync(new URL("../theme/mocha.json", import.meta.url)));
const bgName = Deno.args[3] ?? "base";
const bg = bgName === "transparent" ? "none" : palette[bgName];
const colors: string[] = ramp(palette);

function markup(A: number, B: number): string {
  const g = grid(A, B);
  let s = "";
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      const lvl = g[r * W + c];
      s += lvl < 0 ? " " : `<span foreground="${colors[lvl]}">${CHARS[lvl]}</span>`;
    }
    if (r < H - 1) s += "\n";
  }
  return `<span font="JetBrainsMono Nerd Font Mono 24" font_features="liga 0, calt 0">${s}</span>`;
}

Deno.mkdirSync(out, { recursive: true });
let A = 1;
let B = 1;
for (let i = 0; i < count; i++) {
  const file = `${out}/frame-${String(i).padStart(4, "0")}.png`;
  const p = new Deno.Command("magick", {
    args: ["-background", bg, `pango:${markup(A, B)}`, "-resize", `${width}x`, file],
  }).outputSync();
  if (!p.success) {
    console.error(new TextDecoder().decode(p.stderr));
    Deno.exit(1);
  }
  [A, B] = step(A, B);
}
console.log(`${count} frames in ${out}`);
