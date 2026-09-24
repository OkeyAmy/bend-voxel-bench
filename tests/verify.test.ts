import { test } from "node:test";
import assert from "node:assert/strict";
import { compare } from "../harness/verify.ts";

function line(x: number, y: number, z: number, col: (i: number) => string): string {
  const cols: string[] = [];
  for (let i = 0; i < 6400; i++) cols.push(col(i));
  return `${x} ${y} ${z} ${cols.join(" ")}`;
}

test("compare: identical dumps are 100%", () => {
  const d = line(-32, -112, -32, () => "80 0") + "\n";
  const p = compare(d, d);
  assert.equal(p.percent, 100);
  assert.equal(p.mismatches, 0);
  assert.equal(p.columns, 6400);
});

test("compare: one different column is reported with its position", () => {
  const a = line(-32, -32, -32, () => "30 2");
  const b = line(-32, -32, -32, (i) => (i === 17 ? "31 1" : "30 2"));
  const p = compare(a, b);
  assert.equal(p.mismatches, 1);
  assert.deepEqual(p.sample[0], { chunk: "-32 -32 -32", column: 17, bend: "30 2", luanti: "31 1" });
});

test("compare: a mapchunk missing on one side counts all its columns", () => {
  const a = line(-32, -32, -32, () => "0 0") + "\n" + line(48, -32, -32, () => "0 0");
  const b = line(-32, -32, -32, () => "0 0");
  const p = compare(a, b);
  assert.equal(p.mismatches, 6400);
  assert.deepEqual(p.missing, ["48 -32 -32 (only in bend)"]);
});

test("compare: a short line is an error, not a silent pass", () => {
  assert.throws(() => compare("1 2 3 4 5", "1 2 3 4 5"), /fields/);
});

import { parityAll } from "../harness/verify.ts";

test("parityAll checks every lane against the reference, so a bad 8-thread dump is caught", () => {
  const good = line(-32, -32, -32, () => "30 2");
  const bad = line(-32, -32, -32, (i) => (i === 5 ? "0 0" : "30 2"));
  const dumps = new Map([["luanti·1t", good], ["bend·1t", good], ["bend·8t", bad], ["luanti·8t", good]]);
  const all = parityAll(dumps, "luanti·1t");
  assert.deepEqual(Object.keys(all).sort(), ["bend·1t", "bend·8t", "luanti·8t"]);
  assert.equal(all["bend·1t"].mismatches, 0);
  assert.equal(all["bend·8t"].mismatches, 1);
});
