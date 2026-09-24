import { readFileSync } from "node:fs";

// P3 PPM -> width, height, flat [r, g, b, r, g, b, ...]
export function readPpm(path: string): { w: number; h: number; px: number[] } {
  const f = readFileSync(path, "utf8").split(/\s+/).filter((s) => s !== "");
  if (f[0] !== "P3") throw new Error("not a P3 PPM");
  return { w: Number(f[1]), h: Number(f[2]), px: f.slice(4).map(Number) };
}

// the sky is a blue gradient: blue high and above red and green
export const isSky = (r: number, g: number, b: number) => b >= 200 && b > r && b > g;

// pixels that are sky in `a` but terrain in `b`
export function skyWhereTerrain(a: number[], b: number[]): number {
  let n = 0;
  for (let i = 0; i < a.length; i += 3) if (isSky(a[i], a[i + 1], a[i + 2]) && !isSky(b[i], b[i + 1], b[i + 2])) n++;
  return n;
}
