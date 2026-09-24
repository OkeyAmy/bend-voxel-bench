// every lane run removes its temporary directory (they live in /tmp, which is RAM)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { runBend } from "../harness/lanes/bend.ts";
import { runLuanti } from "../harness/lanes/luanti.ts";
import { buildEngine } from "../harness/build.ts";

const count = (prefix: string) => readdirSync(tmpdir()).filter((n) => n.startsWith(prefix)).length;

test("runBend and runLuanti leave no temporary directories behind", async () => {
  buildEngine();
  const b0 = count("bvb-bend-"), l0 = count("bvb-luanti-");
  const b = await runBend(8, 42, true);
  const l = await runLuanti(8, 42, true);
  assert.equal(b.ok && l.ok, true);
  assert.ok(b.dump!.length > 1000 && l.dump!.length > 1000);
  assert.equal(count("bvb-bend-"), b0);
  assert.equal(count("bvb-luanti-"), l0);
});
