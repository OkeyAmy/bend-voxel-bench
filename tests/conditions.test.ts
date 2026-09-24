import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { conditions } from "../harness/lib/conditions.ts";

// a fake / with the files conditions() reads
function fakeRoot(files: Record<string, string>): string {
  const root = mkdtempSync(`${tmpdir()}/bvb-cond-`);
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(`${root}/${path.split("/").slice(0, -1).join("/")}`, { recursive: true });
    writeFileSync(`${root}/${path}`, text);
  }
  return root;
}

test("AC power, performance governor, load 0.42", () => {
  const root = fakeRoot({
    "sys/class/power_supply/AC/online": "1\n",
    "sys/devices/system/cpu/cpu0/cpufreq/scaling_governor": "performance\n",
    "proc/loadavg": "0.42 0.50 0.61 2/900 12345\n",
  });
  assert.deepEqual(conditions(root), { power: "ac", governor: "performance", load1: 0.42 });
});

test("battery and powersave", () => {
  const root = fakeRoot({
    "sys/class/power_supply/ADP1/online": "0\n",
    "sys/devices/system/cpu/cpu0/cpufreq/scaling_governor": "powersave\n",
    "proc/loadavg": "2.10 1.00 0.50 1/800 99\n",
  });
  assert.deepEqual(conditions(root), { power: "battery", governor: "powersave", load1: 2.1 });
});

test("missing files give unknown, not a crash", () => {
  assert.deepEqual(conditions(fakeRoot({})), { power: "unknown", governor: "unknown", load1: -1 });
});
