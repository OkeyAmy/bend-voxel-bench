// node harness/arena.ts race [--runs 5] [--seed 42] [--threads 1,8] [--no-luanti] [--any-bend]
// Builds the Bend engine, runs every lane once to warm up, then --runs rounds
// with the lanes interleaved, each run a fresh process. Checks parity on the
// first round, writes results/<date>_<commit>.json and prints the table.
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { BEND, buildEngine } from "./build.ts";
import { runBend, type LaneRun } from "./lanes/bend.ts";
import { runLuanti, LUANTI } from "./lanes/luanti.ts";
import { parityAll } from "./verify.ts";
import { finish, table, machine, versions, commit, type LaneResult, type Results } from "./report.ts";

const PARITY_MIN = 99.99;
const BEND_PIN = "2.0.27";

// every path in the harness is relative to the repo root
process.chdir(resolve(import.meta.dirname, ".."));

function flag(name: string, def: string): string {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
}

function need(cmd: string, hint: string): void {
  try { execFileSync("sh", ["-c", `command -v ${cmd}`], { stdio: "ignore" }); }
  catch { throw new Error(`missing ${cmd}: ${hint}`); }
}

async function race(): Promise<number> {
  const runs = Number(flag("--runs", "5"));
  const seed = Number(flag("--seed", "42"));
  const threads = flag("--threads", "1,8").split(",").map(Number);
  const withLuanti = !process.argv.includes("--no-luanti");
  if (!Number.isInteger(runs) || runs < 1) throw new Error("--runs must be a whole number ≥ 1");
  if (!Number.isInteger(seed)) throw new Error("--seed must be a whole number");
  if (threads.some((t) => !Number.isInteger(t) || t < 1)) throw new Error("--threads must be whole numbers ≥ 1, e.g. 1,8");

  need(BEND, `install Bend ${BEND_PIN}: curl -fsSL https://bend-lang.com/install.sh | sh`);
  const bendVersion = execFileSync(BEND, ["version"], { encoding: "utf8", env: { ...process.env, BEND_NO_TELEMETRY: "1" } }).trim();
  if (!bendVersion.includes(BEND_PIN) && !process.argv.includes("--any-bend")) {
    throw new Error(`Bend is pinned to ${BEND_PIN} but ${BEND} is "${bendVersion}" (pass --any-bend to run anyway)`);
  }
  need("clang", "sudo dnf install -y clang");
  need("/usr/bin/time", "sudo dnf install -y time");
  if (withLuanti && !existsSync(LUANTI)) throw new Error(`missing ${LUANTI}: run luanti/build.sh (or pass --no-luanti)`);
  buildEngine();

  type Lane = { res: LaneResult; go: (keep: boolean) => Promise<LaneRun> };
  const lanes: Lane[] = [];
  for (const t of threads) {
    lanes.push({ res: { id: `bend·${t}t`, engine: "bend", threads: t, runs: [] }, go: (k) => runBend(t, seed, k) });
    if (withLuanti) lanes.push({ res: { id: `luanti·${t}t`, engine: "luanti", threads: t, runs: [] }, go: (k) => runLuanti(t, seed, k) });
  }

  for (const l of lanes) { process.stderr.write(`warm-up ${l.res.id}\n`); await l.go(false); }
  const dumps = new Map<string, string>();
  for (let r = 0; r < runs; r++) {
    for (const l of lanes) {
      process.stderr.write(`round ${r + 1}/${runs} ${l.res.id}\n`);
      const run = await l.go(r === 0);
      if (run.dump) dumps.set(l.res.id, run.dump);
      delete run.dump;
      l.res.runs.push(run);
    }
  }

  // every lane's round-0 dump is checked against the first Luanti lane
  const reference = `luanti·${threads[0]}t`;
  const parity = withLuanti && dumps.has(reference) ? { reference, lanes: parityAll(dumps, reference) } : null;

  const res: Results = { schema: 1, date: new Date().toISOString(), commit: commit(), machine: machine(),
    versions: versions(BEND, withLuanti ? LUANTI : null),
    params: { seed, runs, threads, area: "x,z -32..367, y -112..207 (100 mapchunks)" },
    lanes: lanes.map((l) => finish(l.res)), parity,
    notes: [
      "terrain = noise maps + block fill per mapchunk (Luanti: MapgenV7::generateTerrain, summed over mapchunks; Bend: wall time of the whole parallel generation)",
      "with more than 1 thread, Luanti's terrain number is a sum of per-mapchunk thread time, not wall time, so there is no multi-thread terrain ratio",
      "Luanti end-to-end = emerge_area call to last callback (terrain, liquid step, queueing, and a re-emerge pass for cancelled blocks); Bend has no liquid step or queue, so it has no end-to-end number",
      "build flags: Luanti 5.17.0 CMake Release (-O3 -funroll-loops -fomit-frame-pointer -fno-math-errno -fno-trapping-math -fno-signed-zeros) + luanti/timing.patch; Bend: bend engine/main.bend -o build/voxel (Bend's own clang flags)",
    ] };
  mkdirSync("results", { recursive: true });
  const file = `results/${res.date.slice(0, 19).replace(/:/g, "-")}_${res.commit}.json`;
  writeFileSync(file, JSON.stringify(res, null, 2));
  console.log(table(res));
  console.log(`\nwrote ${file}`);

  const failed = res.lanes.some((l) => l.runs.some((r) => !r.ok));
  const low = parity ? Object.entries(parity.lanes).filter(([, q]) => q.percent < PARITY_MIN) : [];
  for (const [lane, q] of low) console.log(`PARITY BELOW ${PARITY_MIN} % for ${lane}: first mismatches ${JSON.stringify(q.sample.slice(0, 5))}`);
  const unchecked = withLuanti ? lanes.filter((l) => l.res.id !== reference && !parity?.lanes[l.res.id]).map((l) => l.res.id) : [];
  if (unchecked.length) console.log(`PARITY NOT CHECKED for ${unchecked.join(", ")} (no round-0 dump)`);
  const badParity = low.length > 0 || unchecked.length > 0 || (withLuanti && parity === null);
  return failed || badParity ? 1 : 0;
}

if (process.argv[2] === "race") {
  race().then((code) => process.exit(code), (e) => { console.error(`error: ${e.message}`); process.exit(2); });
} else {
  console.error("usage: node harness/arena.ts race [--runs 5] [--seed 42] [--threads 1,8] [--no-luanti] [--any-bend]");
  process.exit(2);
}
