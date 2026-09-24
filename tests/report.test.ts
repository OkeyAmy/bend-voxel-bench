import { test } from "node:test";
import assert from "node:assert/strict";
import { finish, table, type Results } from "../harness/report.ts";

const run = (terrainMs: number, ok = true) => ({ ok, wallMs: terrainMs, terrainMs, liquidMs: 0, lightMs: 0, peakKb: 2048 });

test("finish summarizes only successful runs", () => {
  const l = finish({ id: "bend·1t", engine: "bend", threads: 1, runs: [run(100), run(110), run(0, false)] });
  assert.equal(l.terrain!.median, 105);
  assert.equal(l.peakMb, 2);
});

test("table: Bend is compared with Luanti at the same thread count", () => {
  const res: Results = { schema: 1, date: "d", commit: "c", machine: { cpu: "cpu" }, versions: {},
    params: { seed: 42, runs: 2, threads: [1], area: "a" }, notes: [],
    lanes: [finish({ id: "bend·1t", engine: "bend", threads: 1, runs: [run(500), run(500)] }),
            finish({ id: "luanti·1t", engine: "luanti", threads: 1, runs: [run(1000), run(1000)] })],
    parity: { reference: "luanti·1t", lanes: { "bend·1t": { chunks: 100, columns: 640000, mismatches: 0, percent: 100, missing: [], sample: [] } } } };
  const t = table(res);
  assert.match(t, /bend·1t .*2\.00× faster/);
  assert.match(t, /luanti·1t .*reference/);
  assert.match(t, /parity \(bend·1t vs luanti·1t\): 100\.0000 % of 640000 columns identical, 0 differ/);
});

test("table: a lane with no successful run shows FAILED", () => {
  const res: Results = { schema: 1, date: "d", commit: "c", machine: { cpu: "cpu" }, versions: {},
    params: { seed: 42, runs: 1, threads: [1], area: "a" }, notes: [], parity: null,
    lanes: [finish({ id: "luanti·1t", engine: "luanti", threads: 1, runs: [run(0, false)] })] };
  assert.match(table(res), /luanti·1t\s+FAILED/);
  assert.match(table(res), /parity: not checked/);
});

test("table: multi-thread terrain is not ratioed against Luanti thread time; Bend has no end-to-end", () => {
  const res: Results = { schema: 1, date: "d", commit: "c", machine: { cpu: "cpu" }, versions: {},
    params: { seed: 42, runs: 1, threads: [8], area: "a" }, notes: [], parity: null,
    lanes: [finish({ id: "bend·8t", engine: "bend", threads: 8, runs: [run(500)] }),
            finish({ id: "luanti·8t", engine: "luanti", threads: 8, runs: [run(170)] })] };
  const row = table(res).split("\n").find((l) => l.startsWith("bend·8t"))!;
  assert.match(row, /n\/a \(Luanti: thread time\)/);
  assert.doesNotMatch(row, /slower|faster/);
  assert.match(row, /^bend·8t\s+500\.0\s+500\.0\s+500\.0\s+0\.0 %\s+-\s/);
});
