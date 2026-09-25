import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { BEND, BEND_CAP } from "../harness/build.ts";

function runBend(args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync(BEND_CAP[0], [...BEND_CAP.slice(1), BEND, ...args], {
      encoding: "utf8",
      maxBuffer: 1 << 30,
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, BEND_NO_TELEMETRY: "1" },
    });
    return { status: 0, out };
  } catch (e) {
    const err = e as { status?: number; stdout?: string; stderr?: string };
    return { status: err.status ?? 1, out: `${err.stdout ?? ""}${err.stderr ?? ""}` };
  }
}

test("proof gate: bend engine/PROOF.bend checks every law", () => {
  const { status, out } = runBend(["engine/PROOF.bend"]);
  assert.equal(status, 0, out);
  assert.match(out, /All terms check\./);
});

test("broken proof fails the gate", () => {
  const { status, out } = runBend(["tests/fixtures/laws_open/PROOF.bend"]);
  assert.notEqual(status, 0, "a ?TODO proof must not pass the gate");
  assert.match(out, /TODO found/);
});

test("every law in LAWS.bend has a proof in PROOF.bend", () => {
  const laws = [...readFileSync("engine/LAWS.bend", "utf8").matchAll(/^law (\w+):/gm)].map((m) => m[1]);
  const proof = readFileSync("engine/PROOF.bend", "utf8");
  assert.ok(laws.length >= 7, `expected at least 7 laws, found ${laws.length}`);
  for (const name of laws) {
    assert.ok(proof.includes(`def Laws.${name}(`), `missing proof for law ${name}`);
  }
});

import { cpSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";

// The Bend2 claim, on this game: an AI change that lets the camera fly through the
// hills ("noclip": a fixed floor instead of the ground under the camera) cannot be
// built. A copy of the engine gets the change; the gate refuses it.
test("an AI change that lets the camera through the ground is refused by the gate", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-law-`);
  cpSync("engine", `${dir}/engine`, { recursive: true });
  const game = readFileSync(`${dir}/engine/game.bend`, "utf8");
  const dive = game.replace("G.move(s, G.ground(w, G.rawx(s), G.rawz(s)))", "G.move(s, 2.0)");
  assert.notEqual(dive, game, "the noclip change did not apply: G.step changed shape");
  writeFileSync(`${dir}/engine/game.bend`, dive);
  const { status, out } = runBend([`${dir}/engine/PROOF.bend`]);
  assert.notEqual(status, 0);
  assert.match(out, /LAWS\.ground_(stops_fall|keeps_height)/);
});
