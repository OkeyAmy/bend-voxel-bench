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
