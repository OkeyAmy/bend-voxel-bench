// node harness/live_race.ts <seed> <x> <z> [--runs 3] [--out out/live_race.txt]
// The Plan 1 race, here and now: the 5 x 4 x 5 mapchunks around (x, z), snapped to
// mapchunk origins. Lanes bend·1t, bend·8t, luanti·1t, luanti·8t; 1 warm-up and
// --runs interleaved runs, every run a fresh process; every lane's blocks are
// checked against luanti·1t. Writes results/live_<date>_<commit>.json and the
// panel's key-value file. The game runs this when you press G.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { buildEngine } from "./build.ts";
import { runBend, type LaneRun } from "./lanes/bend.ts";
import { runLuanti } from "./lanes/luanti.ts";
import { parityAll } from "./verify.ts";
import { finish, commit, type LaneResult } from "./report.ts";
import { conditions, type Conditions } from "./lib/conditions.ts";

const PARITY_MIN = 99.99;

// the origin of the mapchunk holding v: -32 + 80k
export const snap = (v: number): number => Math.floor((v + 32) / 80) * 80 - 32;

type Live = { seed: number; x0: number; z0: number; time: string; conditions: Conditions; lanes: LaneResult[];
  parity: { reference: string; lanes: Record<string, { percent: number }> } | null };

const ms10 = (v: number | undefined) => (v === undefined ? 0 : Math.round(v * 10));

export function liveTxt(r: Live): string {
  const lane = (id: string) => r.lanes.find((l) => l.id === id);
  const par = r.parity ? Math.min(...Object.values(r.parity.lanes).map((p) => p.percent)) : 0;
  const ok = r.lanes.length === 4 && r.lanes.every((l) => l.runs.length > 0 && l.runs.every((x) => x.ok))
    && r.parity !== null && par >= PARITY_MIN;
  return [
    `seed ${r.seed}`, `x0 ${r.x0}`, `z0 ${r.z0}`,
    `bend1_ms10 ${ms10(lane("bend·1t")?.terrain?.median)}`,
    `bend8_ms10 ${ms10(lane("bend·8t")?.terrain?.median)}`,
    `luanti1_ms10 ${ms10(lane("luanti·1t")?.terrain?.median)}`,
    `luanti8_e2e_ms10 ${ms10(lane("luanti·8t")?.wall?.median)}`,
    `parity_pct ${Math.floor(par * 100)}`,
    `power ${r.conditions.power}`, `load100 ${Math.round(r.conditions.load1 * 100)}`,
    `governor ${r.conditions.governor}`, `time ${r.time}`, `ok ${ok ? 1 : 0}`, "",
  ].join("\n");
}

async function main(): Promise<number> {
  const root = resolve(import.meta.dirname, "..");
  process.chdir(root);
  const flag = (n: string, d: string) => { const i = process.argv.indexOf(n); return i >= 0 ? process.argv[i + 1] : d; };
  const [seed, x, z] = process.argv.slice(2, 5).map(Number);
  const runs = Number(flag("--runs", "3"));
  const out = flag("--out", "out/live_race.txt");
  if (![seed, x, z].every(Number.isInteger) || !Number.isInteger(runs) || runs < 1) {
    console.error("usage: node harness/live_race.ts <seed> <x> <z> [--runs 3] [--out path]");
    return 2;
  }
  const x0 = snap(x), z0 = snap(z);
  const cond = conditions(); // before the race, so the race's own load isn't counted
  buildEngine();
  type Lane = { res: LaneResult; go: (keep: boolean) => Promise<LaneRun> };
  const lanes: Lane[] = [];
  for (const t of [1, 8]) {
    lanes.push({ res: { id: `bend·${t}t`, engine: "bend", threads: t, runs: [] }, go: (k) => runBend(t, seed, k, x0, z0) });
    lanes.push({ res: { id: `luanti·${t}t`, engine: "luanti", threads: t, runs: [] }, go: (k) => runLuanti(t, seed, k, x0, z0) });
  }
  for (const l of lanes) await l.go(false);
  const dumps = new Map<string, string>();
  for (let r = 0; r < runs; r++) {
    for (const l of lanes) {
      const run = await l.go(r === 0);
      if (run.dump) dumps.set(l.res.id, run.dump);
      delete run.dump;
      l.res.runs.push(run);
    }
  }
  const parity = dumps.has("luanti·1t") ? { reference: "luanti·1t", lanes: parityAll(dumps, "luanti·1t") } : null;
  const live: Live = { seed, x0, z0, time: new Date().toISOString(), conditions: cond,
    lanes: lanes.map((l) => finish(l.res)), parity };
  const txt = liveTxt(live);
  mkdirSync("results", { recursive: true });
  writeFileSync(`results/live_${live.time.slice(0, 19).replace(/:/g, "-")}_${commit()}.json`,
    JSON.stringify({ schema: 1, kind: "live", ...live }, null, 2));
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, txt);
  process.stdout.write(txt);
  return txt.includes("\nok 1\n") ? 0 : 1;
}

if (import.meta.filename === process.argv[1]) {
  main().then((c) => process.exit(c), (e) => { console.error(`error: ${e.message}`); process.exit(2); });
}
