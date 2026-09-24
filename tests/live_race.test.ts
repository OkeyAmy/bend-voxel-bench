// harness/live_race.ts: the Plan 1 race for the 100 mapchunks around a point.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { liveTxt, snap } from "../harness/live_race.ts";

// origins are -32 + 80k: 0 is in the mapchunk from -32, -33 in the one from -112
test("snap puts a coordinate on its mapchunk origin", () => {
  assert.equal(snap(0), -32);
  assert.equal(snap(-32), -32);
  assert.equal(snap(-33), -112);
  assert.equal(snap(400), 368);
});

// ms values are x 10 (one decimal kept in a whole number); parity and load x 100
test("liveTxt: the panel's numbers for a finished live race", () => {
  const txt = liveTxt({
    seed: 42, x0: -432, z0: 368, time: "2026-09-24T21:00:00.000Z",
    conditions: { power: "ac", governor: "performance", load1: 0.47 },
    lanes: [
      { id: "bend·1t", runs: [{ ok: true }], terrain: { median: 1350.4 } },
      { id: "bend·8t", runs: [{ ok: true }], terrain: { median: 530 } },
      { id: "luanti·1t", runs: [{ ok: true }], terrain: { median: 131.16 } },
      { id: "luanti·8t", runs: [{ ok: true }], terrain: { median: 165 }, wall: { median: 752.9 } },
    ],
    parity: { reference: "luanti·1t", lanes: { "bend·1t": { percent: 100 }, "bend·8t": { percent: 100 }, "luanti·8t": { percent: 99.995 } } },
  } as any);
  assert.equal(txt, "seed 42\nx0 -432\nz0 368\nbend1_ms10 13504\nbend8_ms10 5300\nluanti1_ms10 1312\n"
    + "luanti8_e2e_ms10 7529\nparity_pct 9999\npower ac\nload100 47\ngovernor performance\ntime 2026-09-24T21:00:00.000Z\nok 1\n");
});

test("a real live race at seed 42 around (0, 0), 1 run", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-live-`);
  execFileSync("node", ["harness/live_race.ts", "42", "0", "0", "--runs", "1", "--out", `${dir}/live.txt`], { stdio: "inherit" });
  const txt = readFileSync(`${dir}/live.txt`, "utf8");
  assert.match(txt, /^x0 -32$/m);
  assert.match(txt, /^parity_pct 10000$/m);
  assert.match(txt, /^ok 1$/m);
});
