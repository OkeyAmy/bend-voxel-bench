// G in the game runs harness/live_race.ts through Proc.run and shows the result.
// Headless: the render option "live" presses G at frame 5.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { buildEngine, BUILD } from "../harness/build.ts";
import { readPpm } from "./lib/ppm.ts";

before(() => buildEngine());

function render(args: string[], env: Record<string, string> = {}): string {
  return execFileSync("systemd-run", ["--user", "--scope", "-q", "-p", "MemoryMax=6G", "-p", "MemorySwapMax=0", "--",
    "env", ...Object.entries(env).map(([k, v]) => `${k}=${v}`), "timeout", "900",
    `${BUILD}/voxel`, "--threads", "8", "--gpu", "off", "--", "render", ...args], { encoding: "utf8" });
}

const white = (path: string) => {
  const { w, px } = readPpm(path);
  let n = 0;
  for (let y = 60; y < 110; y++) for (let x = 0; x < 760; x++) {
    const i = (y * w + x) * 3;
    if (px[i] > 230 && px[i + 1] > 230 && px[i + 2] > 230) n++;
  }
  return n;
};

test("live option: the race runs, finishes ok, and the panel shows it", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-lp-`);
  const out = render(["path", "8", "1280", "720", `${dir}/a.ppm`, "live"]);
  assert.match(out, /^live_race exit 0$/m);
  assert.match(readFileSync("out/live_race.txt", "utf8"), /^ok 1$/m);
  assert.ok(white(`${dir}/a.ppm`) >= 500);
});

test("live option with Luanti missing: a non-zero exit, and the frame still renders", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-lp-`);
  const out = render(["path", "8", "1280", "720", `${dir}/b.ppm`, "live"], { LUANTI: "/nonexistent/luantiserver" });
  const m = /^live_race exit (\d+)$/m.exec(out);
  assert.ok(m && Number(m[1]) !== 0, out);
  assert.match(out, /^frame_ms_median \d+/m);
});

import { existsSync, renameSync, rmSync } from "node:fs";

// a fresh checkout has no out/ (it's gitignored): G must still work
test("live race works without an out/ directory", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-lp-`);
  renameSync("out", "out.aside");
  try {
    const out = render(["path", "8", "1280", "720", `${dir}/c.ppm`, "live"]);
    assert.match(out, /^live_race exit 0$/m);
    assert.equal(existsSync("out/live_race.txt"), true);
  } finally {
    rmSync("out", { recursive: true, force: true });
    renameSync("out.aside", "out");
  }
});
