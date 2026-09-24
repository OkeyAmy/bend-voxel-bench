// The race panel: harness/hud_export.ts turns race results into out/race.txt, and the
// render probe draws the panel (white text) in the top-left corner.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, copyFileSync, rmSync, existsSync, renameSync } from "node:fs";
import { tmpdir } from "node:os";
import { raceTxt } from "../harness/hud_export.ts";
import { buildEngine, BUILD } from "../harness/build.ts";
import { readPpm } from "./lib/ppm.ts";

before(() => buildEngine());

// per mapchunk = median over 100 mapchunks, in whole microseconds:
// 1350 ms / 100 = 13500 us; 131.1 ms / 100 = 1311 us; parity 100 % x 100 = 10000
test("hud_export writes the race numbers per mapchunk in microseconds", () => {
  const txt = raceTxt(JSON.parse(readFileSync("tests/fixtures/race-results.json", "utf8")));
  assert.equal(txt, "luanti_us_per_mapchunk 1311\nbend1_us_per_mapchunk 13500\nbend8_us_per_mapchunk 5300\nparity_pct 10000\ncommit 6c3dcc9\n");
});

function render(args: string[]): string {
  return execFileSync("systemd-run", ["--user", "--scope", "-q", "-p", "MemoryMax=4G", "-p", "MemorySwapMax=0", "--", "timeout", "300",
    `${BUILD}/voxel`, "--threads", "8", "--gpu", "off", "--", "render", ...args], { encoding: "utf8" });
}

// white text strokes: all channels above 230 (sky is blue-dominant, no snow in that corner)
function whiteInBox(path: string): number {
  const { w, px } = readPpm(path);
  let n = 0;
  for (let y = 0; y < 90; y++) for (let x = 0; x < 400; x++) {
    const i = (y * w + x) * 3;
    if (px[i] > 230 && px[i + 1] > 230 && px[i + 2] > 230) n++;
  }
  return n;
}

test("the panel draws text in the top-left corner, and nothing with nohud", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-h-`);
  copyFileSync("tests/fixtures/race-results.json", `${dir}/r.json`);
  execFileSync("node", ["harness/hud_export.ts", `${dir}/r.json`, "out/race.txt"]);
  render(["path", "3", "1280", "720", `${dir}/a.ppm`]);
  render(["path", "3", "1280", "720", `${dir}/b.ppm`, "nohud"]);
  assert.ok(whiteInBox(`${dir}/a.ppm`) >= 500, `only ${whiteInBox(`${dir}/a.ppm`)} white pixels`);
  assert.equal(whiteInBox(`${dir}/b.ppm`), 0);
});

test("a missing race file is reported and the frame still renders", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-h-`);
  // set it aside on the same disk (a rename can't cross into /tmp)
  const saved = existsSync("out/race.txt");
  if (saved) renameSync("out/race.txt", "out/race.txt.aside");
  try {
    const out = render(["path", "2", "1280", "720", `${dir}/a.ppm`]);
    assert.match(out, /^hud: race file missing$/m);
    assert.match(out, /^frame_ms_median \d+/m);
  } finally {
    if (saved) renameSync("out/race.txt.aside", "out/race.txt");
    else rmSync("out/race.txt", { force: true });
  }
});
