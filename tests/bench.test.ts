// Bend engine vs Luanti's own noise code (tools/golden/golden.cpp, verbatim copies
// from Luanti 5.17.0). Expected values come from that program, never from Bend.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { buildEngine, buildGolden, BUILD } from "../harness/build.ts";

const sh = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: "utf8", maxBuffer: 1 << 30 });

before(() => { buildGolden(); buildEngine(); });

// stone and water counts of a column with surface level L inside the mapchunk at y0:
// stone for y <= L, water for L < y <= 1 (water_level), air above
function counts(L: number, y0: number): string {
  const clamp = (n: number) => Math.max(0, Math.min(80, n));
  const stone = clamp(L - y0 + 1);
  const water = clamp(Math.min(1, y0 + 79) - Math.max(L + 1, y0) + 1);
  return `${stone} ${water}`;
}

test("counts() follows the stone/water/air rule", () => {
  assert.equal(counts(-2, -32), "31 3"); // stone -32..-2, water -1..1
  assert.equal(counts(10, -112), "80 0"); // whole mapchunk below the surface
  assert.equal(counts(-2, 48), "0 0"); // whole mapchunk in the air
});

test("bench dump: every block of the 100 mapchunks matches Luanti's levels", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-`);
  const out = sh(`${BUILD}/voxel`, ["--threads", "8", "--", "mapgen", "42", `${dir}/dump.txt`]);
  assert.match(out, /^mapgen_ms \d+$/m);
  const lines = readFileSync(`${dir}/dump.txt`, "utf8").trim().split("\n");
  assert.equal(lines.length, 100);
  const levels = new Map<string, number[]>();
  for (const line of lines) {
    const f = line.split(" ");
    const [x, y, z] = f.slice(0, 3).map(Number);
    const key = `${x} ${z}`;
    if (!levels.has(key)) levels.set(key, sh(`${BUILD}/golden`, ["42", String(x), String(z)]).trim().split("\n").map((l) => Number(l.split(" ")[4])));
    const L = levels.get(key)!;
    for (let i = 0; i < 6400; i++) assert.equal(`${f[3 + 2 * i]} ${f[4 + 2 * i]}`, counts(L[i], y), `mapchunk ${x} ${y} ${z} column ${i}`);
  }
});

test("bench is deterministic across thread counts", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-`);
  sh(`${BUILD}/voxel`, ["--threads", "1", "--", "mapgen", "42", `${dir}/a.txt`]);
  sh(`${BUILD}/voxel`, ["--threads", "8", "--", "mapgen", "42", `${dir}/b.txt`]);
  assert.equal(readFileSync(`${dir}/a.txt`, "utf8"), readFileSync(`${dir}/b.txt`, "utf8"));
});

test("bench rejects bad arguments with exit code 2", () => {
  assert.throws(() => sh(`${BUILD}/voxel`, ["--", "nope"]), (e: any) => e.status === 2);
  assert.throws(() => sh(`${BUILD}/voxel`, ["--", "mapgen", "abc", "x"]), (e: any) => e.status === 2 && /seed must be an integer/.test(e.stderr));
});

// the race area can move: mapchunks from origin (x0, -112, z0), 5 x 4 x 5 of them
test("bench dump at another origin (-432, 368) matches Luanti's levels", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-`);
  sh(`${BUILD}/voxel`, ["--threads", "8", "--", "mapgen", "42", `${dir}/dump.txt`, "-432", "368"]);
  const lines = readFileSync(`${dir}/dump.txt`, "utf8").trim().split("\n");
  assert.equal(lines.length, 100);
  assert.equal(lines[0].split(" ").slice(0, 3).join(" "), "-432 -112 368");
  const levels = new Map<string, number[]>();
  for (const line of lines) {
    const f = line.split(" ");
    const [x, y, z] = f.slice(0, 3).map(Number);
    const key = `${x} ${z}`;
    if (!levels.has(key)) levels.set(key, sh(`${BUILD}/golden`, ["42", String(x), String(z)]).trim().split("\n").map((l) => Number(l.split(" ")[4])));
    const L = levels.get(key)!;
    for (let i = 0; i < 6400; i++) assert.equal(`${f[3 + 2 * i]} ${f[4 + 2 * i]}`, counts(L[i], y), `mapchunk ${x} ${y} ${z} column ${i}`);
  }
});
