// Bend engine vs Luanti's own noise code (tools/golden/golden.cpp, verbatim copies
// from Luanti 5.17.0). Expected values come from that program, never from Bend.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { bendBuild, buildGolden, BUILD } from "../harness/build.ts";

const sh = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: "utf8", maxBuffer: 1 << 30 });

// seed, mapchunk origin x, z: aligned origins, negative, far out, a negative seed
const CASES: [string, string, string][] = [
  ["42", "-32", "-32"], ["42", "48", "-112"], ["42", "-3232", "7968"],
  ["123456789", "-30032", "29968"], ["-7", "368", "368"], ["0", "-31952", "-31952"],
];

before(() => { buildGolden(); bendBuild("engine/tests/level_golden.bend", "level_golden"); });

for (const [s, x, z] of CASES) {
  test(`surface levels match Luanti: seed ${s} at ${x},${z}`, () => {
    const want = sh(`${BUILD}/golden`, [s, x, z]).trim().split("\n").map((l) => l.split(" ")[4]);
    const got = sh(`${BUILD}/level_golden`, ["--", s, x, z]).trim().split("\n");
    assert.deepEqual(got, want);
  });
}
