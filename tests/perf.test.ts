// G2: >= 30 FPS at 1280 x 720 on 8 threads, flying over the streamed 5 x 5 world.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { buildEngine, BUILD } from "../harness/build.ts";

before(() => buildEngine());

test("G2: median frame <= 33.3 ms on the path scene at 1280x720, 8 threads", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-p-`);
  const out = execFileSync("systemd-run", ["--user", "--scope", "-q", "-p", "MemoryMax=4G", "-p", "MemorySwapMax=0", "--",
    "timeout", "600", `${BUILD}/voxel`, "--threads", "8", "--gpu", "off", "--", "render", "path", "120", "1280", "720", `${dir}/p.ppm`], { encoding: "utf8" });
  const ms = Number(/frame_ms_median (\d+)/.exec(out)![1]);
  console.log(out.trim());
  assert.ok(ms <= 33, `median frame ${ms} ms`);
});
