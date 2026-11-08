import { grid, ramp, CHARS, W, H } from "./donut.mjs";

const out = Deno.args[0];
if (!out) {
  console.error("usage: render-logo.ts <out-dir>");
  Deno.exit(1);
}
const palette = JSON.parse(Deno.readTextFileSync(new URL("../theme/mocha.json", import.meta.url)));
const colors: string[] = ramp(palette);
const slotOf = (lvl: number) => Math.min(9, Math.floor((lvl * 9) / 12) + 1);
const slotLevel = (slot: number) => Math.min(11, Math.round(((slot - 1) * 12) / 9 + 0.5));
const ansi = (hex: string) => {
  const n = parseInt(hex.slice(1), 16);
  return `38;2;${(n >> 16) & 255};${(n >> 8) & 255};${n & 255}`;
};

const g = grid(1, 1);
const lines: string[] = [];
for (let r = 0; r < H; r++) {
  let line = "";
  let cur = 0;
  for (let c = 0; c < W; c++) {
    const lvl = g[r * W + c];
    if (lvl < 0) {
      line += " ";
      continue;
    }
    const slot = slotOf(lvl);
    if (slot !== cur) {
      line += `$${slot}`;
      cur = slot;
    }
    line += CHARS[lvl] === "$" ? "$$" : CHARS[lvl];
  }
  lines.push(line.replace(/\s+$/, ""));
}

const logoColor: Record<string, string> = {};
for (let s = 1; s <= 9; s++) logoColor[String(s)] = ansi(colors[slotLevel(s)]);
const c = (name: string) => ansi(palette[name]);
const mod = (type: string, key: string, color: string, extra: Record<string, unknown> = {}) => ({
  type,
  key,
  keyColor: c(color),
  ...extra,
});

const config = {
  $schema: "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  logo: { type: "file", source: "~/.config/fastfetch/logo.txt", color: logoColor, padding: { right: 2 } },
  display: { separator: " : ", color: { keys: c("mauve"), title: c("lavender") } },
  modules: [
    { type: "custom", format: `{#${c("mauve")}}marc{#${c("subtext0")}} @ {#${c("lavender")}}os` },
    { type: "custom", format: `{#${c("surface2")}}────────────────────────────` },
    mod("os", "󰣇 os", "red", { format: "{2}" }),
    mod("kernel", "󰌽 kernel", "red", { format: "{2}" }),
    mod("packages", "󰏗 packages", "green"),
    mod("display", "󰍹 display", "green", { format: "{1}x{2} @ {3}Hz" }),
    mod("wm", "󱗃 wm", "yellow"),
    mod("terminal", "󰆍 terminal", "yellow"),
    mod("cpu", "󰻠 cpu", "blue"),
    mod("gpu", "󰊴 gpu", "blue"),
    mod("memory", "󰍛 memory", "sapphire"),
    mod("disk", "󱦟 disk", "sapphire", { folders: "/" }),
    mod("command", "󰃭 age", "lavender", {
      text: "b=$(stat -c %W /); printf '%d days, since %s' $(( ($(date +%s) - b) / 86400 )) \"$(date -d @$b '+%-d %b %Y')\"",
    }),
    mod("uptime", "󱫐 uptime", "lavender"),
    { type: "custom", format: "" },
    { type: "colors", symbol: "circle" },
  ],
};

Deno.mkdirSync(out, { recursive: true });
Deno.writeTextFileSync(`${out}/logo.txt`, lines.join("\n") + "\n");
Deno.writeTextFileSync(`${out}/config.jsonc`, JSON.stringify(config, null, 2) + "\n");
