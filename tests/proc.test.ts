// Proc.run: Bend's own effect for running a shell command (Bend has no process spawning).
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { bendBuild, BUILD } from "../harness/build.ts";

before(() => bendBuild("engine/tests/proc_test.bend", "proc_test"));

test("Proc.run returns each command's exit status and the command really runs", () => {
  const dir = mkdtempSync(`${tmpdir()}/bvb-proc-`);
  const out = execFileSync("systemd-run", ["--user", "--scope", "-q", "-p", "MemoryMax=1G", "--", "timeout", "30",
    `${BUILD}/proc_test`, "--", dir], { encoding: "utf8" });
  assert.deepEqual(out.trim().split("\n"), ["code 3", "code 0"]);
  assert.equal(existsSync(`${dir}/made`), true);
});
