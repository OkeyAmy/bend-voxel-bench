import { test } from "node:test";
import assert from "node:assert/strict";
import { parseBendStdout } from "../harness/lanes/bend.ts";
import { parseChunkTimes, parseProbeHeader } from "../harness/lanes/luanti.ts";

test("parseBendStdout", () => {
  assert.equal(parseBendStdout("mapgen_ms 1253\n"), 1253);
  assert.throws(() => parseBendStdout("crash"), /mapgen_ms/);
});

test("parseChunkTimes sums stages and flags mapchunks outside the area", () => {
  const s = [
    "2026-09-24 ACTION[Server]: something else",
    "BVB_CHUNK -32 -112 -32 terrain_us=1000 middle_us=5 liquid_us=20 light_us=0",
    "BVB_CHUNK 288 128 288 terrain_us=2000 middle_us=5 liquid_us=30 light_us=0",
    "BVB_CHUNK 368 -32 -32 terrain_us=4000 middle_us=5 liquid_us=40 light_us=0",
  ].join("\n");
  const t = parseChunkTimes(s);
  assert.equal(t.count, 3);
  assert.equal(t.terrainUs, 7000);
  assert.equal(t.liquidUs, 90);
  assert.deepEqual(t.outside, ["368 -32 -32"]);
});

test("parseProbeHeader", () => {
  assert.deepEqual(parseProbeHeader("emerge_us 812345 errors 0\n-32 -112 -32 80 0"), { emergeUs: 812345, errors: 0 });
  assert.throws(() => parseProbeHeader("-32 -112 -32"), /header/);
});
