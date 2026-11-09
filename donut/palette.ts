const env = (k: string) => {
  try {
    return Deno.env.get(k);
  } catch {
    return undefined;
  }
};

const read = (path: string) => {
  try {
    return JSON.parse(Deno.readTextFileSync(path));
  } catch {
    return undefined;
  }
};

export function activePalette(): Record<string, string> {
  const fixed = env("TORUS_PALETTE");
  if (fixed) return JSON.parse(Deno.readTextFileSync(fixed));
  const home = env("HOME");
  const state = env("XDG_STATE_HOME") || (home ? `${home}/.local/state` : "");
  const live = state ? read(`${state}/torus/theme/qs-colors.json`) : undefined;
  return live ?? JSON.parse(Deno.readTextFileSync(new URL("../theme/mocha.json", import.meta.url)));
}
