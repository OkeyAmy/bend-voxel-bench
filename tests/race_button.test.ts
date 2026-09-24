// Race button (G, scripted as the "race" option: pressed at frame 10) and distance fog.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { buildEngine, BUILD } from "../harness/build.ts";
import { readPpm, isSky } from "./lib/ppm.ts";

before(() => buildEngine());

function render(args: string[]): string {
  return execFileSync("systemd-run", ["--user", "--scope", "-q", "-p", "MemoryMax=4G", "-p", "MemorySwapMax=0", "--", "timeout", "600",
    `${BUILD}/voxel`, "--threads", "8", "--gpu", "off", "--", "render", ...args], { encoding: "utf8" });
}

// the race drops every mapchunk at frame 10; streaming refills one per frame, so the
// 25 around the player are back by frame 35; the race time is the sum of those loads
test("race button: 25 mapchunks regenerated, time = sum of their load times", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-rb-`);
  const out = render(["path", "60", "640", "480", `${dir}/a.ppm`, "race"]);
  const done = [...out.matchAll(/^race_done mapchunks (\d+) bend_ms (\d+)$/gm)];
  assert.equal(done.length, 1);
  assert.equal(Number(done[0][1]), 25);
  const loads = [...out.matchAll(/^race_load (\d+)$/gm)].map((m) => Number(m[1]));
  assert.equal(loads.length, 25);
  assert.equal(Number(done[0][2]), loads.reduce((a, b) => a + b, 0));
});

// fog blends terrain towards the sky with distance: terrain near the horizon (upper
// rows of the terrain) must be nearer the fog colour than terrain at the bottom
test("fog: far terrain is closer to the sky colour than near terrain", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-rb-`);
  render(["path", "1", "640", "480", `${dir}/f.ppm`, "nohud"]);
  const { w, h, px } = readPpm(`${dir}/f.ppm`);
  const fog = [134, 179, 230];
  const dist = (i: number) => Math.hypot(px[i] - fog[0], px[i + 1] - fog[1], px[i + 2] - fog[2]);
  // the first 20 rows (from the top) that contain terrain, and the last 20 rows
  const rows: number[] = [];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 3;
    if (!isSky(px[i], px[i + 1], px[i + 2])) { rows.push(y); break; }
  }
  const band = (ys: number[]) => {
    let s = 0, n = 0;
    for (const y of ys) for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 3;
      if (!isSky(px[i], px[i + 1], px[i + 2])) { s += dist(i); n++; }
    }
    return s / n;
  };
  const far = band(rows.slice(0, 20));
  const near = band(rows.slice(-20));
  assert.ok(far < near, `far ${far.toFixed(1)} vs near ${near.toFixed(1)}`);
});
