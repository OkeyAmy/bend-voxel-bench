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
  assert.deepEqual(parseProbeHeader("emerge_us 812345 errors 0 cancelled 399 passes 2\n-32 -112 -32 80 0"),
    { emergeUs: 812345, errors: 0, cancelled: 399, passes: 2 });
  assert.throws(() => parseProbeHeader("emerge_us 812345 errors 0\n"), /header/);
  assert.throws(() => parseProbeHeader("-32 -112 -32"), /header/);
});

import { renderConf, mapMetaSeed } from "../harness/lanes/luanti.ts";
import { readFileSync } from "node:fs";

test("renderConf fills every placeholder, including the real setting lines", () => {
  const conf = renderConf(readFileSync("luanti/bench.conf.in", "utf8"), 8, 42);
  assert.match(conf, /^fixed_map_seed = 42$/m);
  assert.match(conf, /^num_emerge_threads = 8$/m);
  assert.doesNotMatch(conf, /@[A-Z]+@/);
});

test("mapMetaSeed reads the seed Luanti actually used", () => {
  assert.equal(mapMetaSeed("mg_name = v7\nseed = 42\n[end_of_params]\n"), "42");
  assert.equal(mapMetaSeed("mg_name = v7\n"), null);
});

import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

test("LUANTI resolves inside the repo even when imported from another directory", () => {
  const mod = resolve("harness/lanes/luanti.ts");
  const out = execFileSync("node", ["-e", `import(${JSON.stringify(mod)}).then(m => console.log(m.LUANTI))`], { cwd: "/tmp", encoding: "utf8" }).trim();
  assert.equal(out, resolve("luanti/src/bin/luantiserver"));
});
