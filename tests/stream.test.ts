// Streaming: voxel -- stream-order <seed> <px> <pz> <frames> <speed-tenths>
// prints "load <frame> <x> <z>" for every mapchunk loaded, then "loaded <n>".
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { buildEngine, BUILD } from "../harness/build.ts";
import { run } from "../harness/lib/exec.ts";

const CAP = ["--user", "--scope", "-q", "-p", "MemoryMax=4G", "-p", "MemorySwapMax=0", "--", "timeout", "300"];

function stream(args: string[]): string {
  return execFileSync("systemd-run", [...CAP, `${BUILD}/voxel`, "--threads", "8", "--", "stream-order", ...args], { encoding: "utf8" });
}

const loads = (out: string) => [...out.matchAll(/^load (\d+) (-?\d+) (-?\d+)$/gm)].map((m) => ({ f: Number(m[1]), x: Number(m[2]), z: Number(m[3]) }));

before(() => buildEngine());

// the mapchunk holding (0, 0) has origin (-32, -32): origins are -32 + 80k
test("standing still: own mapchunk first, then its 8 neighbours, 25 in all", () => {
  const out = stream(["42", "0", "0", "30", "0"]);
  const l = loads(out);
  assert.deepEqual(l[0], { f: 0, x: -32, z: -32 });
  const ring = new Set(l.slice(1, 9).map((c) => `${c.x},${c.z}`));
  const want = new Set<string>();
  for (const dx of [-80, 0, 80]) for (const dz of [-80, 0, 80]) if (dx || dz) want.add(`${-32 + dx},${-32 + dz}`);
  assert.deepEqual(ring, want);
  assert.equal(l.length, 25);
  assert.match(out, /^loaded 25$/m);
});

test("flying: never more than one mapchunk loaded in a frame", () => {
  const l = loads(stream(["42", "0", "0", "300", "20"]));
  const perFrame = new Map<number, number>();
  for (const c of l) perFrame.set(c.f, (perFrame.get(c.f) ?? 0) + 1);
  assert.ok([...perFrame.values()].every((n) => n === 1));
  assert.ok(l.length > 25, `only ${l.length} loads: the flight should reach new mapchunks`);
});

// 600 frames at 2 blocks/frame crosses 15 mapchunks: without dropping, memory would keep growing
test("flying far keeps memory flat (mapchunks behind are dropped)", async () => {
  const short = await run(`${BUILD}/voxel`, ["--threads", "8", "--", "stream-order", "42", "0", "0", "60", "20"]);
  const long = await run(`${BUILD}/voxel`, ["--threads", "8", "--", "stream-order", "42", "0", "0", "600", "20"]);
  assert.equal(long.code, 0);
  assert.match(long.stdout, /^loaded (\d+)$/m);
  const kept = Number(/^loaded (\d+)$/m.exec(long.stdout)![1]);
  assert.ok(kept <= 49, `${kept} mapchunks still loaded`);
  assert.ok(long.peakKb < 2 * short.peakKb, `peak ${long.peakKb} KB vs ${short.peakKb} KB`);
});
