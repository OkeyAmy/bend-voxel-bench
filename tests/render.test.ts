// Headless render probe: ./build/voxel --threads 8 --gpu off -- render <scene> <frames> <w> <h> <out.ppm> [diag]
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { buildEngine, BUILD } from "../harness/build.ts";

export function render(args: string[]): string {
  return execFileSync(`${BUILD}/voxel`, ["--threads", "8", "--gpu", "off", "--", "render", ...args], { encoding: "utf8" });
}

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

before(() => buildEngine());

test("render probe prints its timing line and writes a 640x480 PPM", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-r-`);
  const out = render(["hills1", "5", "640", "480", `${dir}/a.ppm`]);
  assert.match(out, /^frame_ms_median \d+ build_ms_median \d+ draw_ms_median \d+ tris \d+$/m);
  const img = readPpm(`${dir}/a.ppm`);
  assert.equal(img.w, 640);
  assert.equal(img.h, 480);
  assert.equal(img.px.length, 640 * 480 * 3);
});

test("render is deterministic", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-r-`);
  render(["hills1", "1", "640", "480", `${dir}/a.ppm`]);
  render(["hills1", "1", "640", "480", `${dir}/b.ppm`]);
  assert.equal(readFileSync(`${dir}/a.ppm`, "utf8"), readFileSync(`${dir}/b.ppm`, "utf8"));
});

// the spike measured 1 such pixel once the winding was right, and 18,731 with it wrong
test("gap test: no sky showing through terrain compared with both-winding render", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-r-`);
  render(["hills1", "1", "640", "480", `${dir}/n.ppm`]);
  render(["hills1", "1", "640", "480", `${dir}/d.ppm`, "diag"]);
  assert.ok(skyWhereTerrain(readPpm(`${dir}/n.ppm`).px, readPpm(`${dir}/d.ppm`).px) <= 5);
});
