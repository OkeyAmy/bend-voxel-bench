import { test } from "node:test";
import assert from "node:assert/strict";
import { median, spreadPct, summarize } from "../harness/lib/stats.ts";
import { parsePeakKb } from "../harness/lib/exec.ts";

// expected values from the definitions: median of an odd list is the middle
// element, of an even list the mean of the two middle ones
test("median", () => {
  assert.equal(median([3, 1, 2]), 2);
  assert.equal(median([4, 1, 3, 2]), 2.5);
  assert.throws(() => median([]));
});

test("spreadPct is (max-min)/min", () => {
  assert.equal(spreadPct([100, 105, 102]), 5);
  assert.equal(summarize([10, 20]).median, 15);
});

test("parsePeakKb reads GNU time -v output", () => {
  assert.equal(parsePeakKb("\tMaximum resident set size (kbytes): 29160\n"), 29160);
  assert.equal(parsePeakKb("nothing"), 0);
});

import { run } from "../harness/lib/exec.ts";

// a hung benchmark must not hang the harness: the timeout kills the measured process itself
test("run() timeout kills the command, not just /usr/bin/time", async () => {
  const t0 = Date.now();
  const r = await run("sleep", ["6"], { timeoutMs: 500 });
  assert.equal(r.timedOut, true);
  assert.ok(Date.now() - t0 < 2000, `took ${Date.now() - t0} ms`);
});
