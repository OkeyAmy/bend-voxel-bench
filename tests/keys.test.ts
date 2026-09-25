// Play-mode input, without a window:
//   voxel -- keys-sim <frames> <key>...   keys: w a s d q e left right up down g esc
// holds the keys for <frames> frames from the start state (0, 60, 0, yaw 0, pitch 0) and prints
// "state <x> <y> <z> <yaw> <pitch>", or "quit" when esc is among them.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { buildEngine, BUILD } from "../harness/build.ts";

before(() => buildEngine());

function sim(args: string[]): { x: number; y: number; z: number; yaw: number; pitch: number } | "quit" {
  const out = execFileSync("systemd-run", ["--user", "--scope", "-q", "-p", "MemoryMax=2G", "-p", "MemorySwapMax=0", "--", "timeout", "60",
    `${BUILD}/voxel`, "--", "keys-sim", ...args], { encoding: "utf8" });
  if (/^quit$/m.test(out)) return "quit";
  const m = /^state (\S+) (\S+) (\S+) (\S+) (\S+)$/m.exec(out)!;
  return { x: Number(m[1]), y: Number(m[2]), z: Number(m[3]), yaw: Number(m[4]), pitch: Number(m[5]) };
}

test("holding W and S together cancels: no movement", () => {
  assert.deepEqual(sim(["30", "w", "s"]), { x: 0, y: 60, z: 0, yaw: 0, pitch: 0 });
});

test("no keys: nothing drifts", () => {
  assert.deepEqual(sim(["30"]), { x: 0, y: 60, z: 0, yaw: 0, pitch: 0 });
});

// yaw 0 looks along +z; W moves 0.6 blocks per frame forward: 10 frames = 6 blocks
test("W moves forward along the view direction", () => {
  const s = sim(["10", "w"]);
  assert.ok(s !== "quit");
  assert.ok(Math.abs(s.z - 6) < 1e-3 && Math.abs(s.x) < 1e-3, JSON.stringify(s));
});

// pitch changes 0.03 rad per frame and stops at 1.4
test("holding up for 200 frames stops the pitch at 1.4", () => {
  const s = sim(["200", "up"]);
  assert.ok(s !== "quit");
  assert.ok(Math.abs(s.pitch - 1.4) < 1e-6, JSON.stringify(s));
});

test("esc quits", () => {
  assert.equal(sim(["5", "esc"]), "quit");
});

// the ground rule, seen from play: keys-sim has no world loaded, so the ground is sea level
// (top 2) plus eye height 1.7; holding Q (down, 0.6 per frame) from 60 stops there
test("holding Q for 200 frames stops at the ground, y = 2 + 1.7", () => {
  const s = sim(["200", "q"]);
  assert.ok(s !== "quit");
  assert.ok(Math.abs(s.y - 3.7) < 1e-4, JSON.stringify(s));
});
