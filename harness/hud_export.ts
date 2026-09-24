// node harness/hud_export.ts [results.json] [out/race.txt]
// Writes the race numbers the game's panel shows: per-mapchunk terrain time in
// whole microseconds (the median over the race's 100 mapchunks / 100), parity x 100.
// Without a results path it uses the newest results/*.json that has a Luanti lane.
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

type Lane = { id: string; terrain?: { median: number } };
type Results = { commit: string; lanes: Lane[]; kind?: string; params?: unknown;
  parity: { percent?: number; lanes?: Record<string, { percent: number }> } | null };

const perChunkUs = (r: Results, id: string): number => {
  const t = r.lanes.find((l) => l.id === id)?.terrain?.median;
  if (t === undefined) throw new Error(`results have no terrain median for ${id}`);
  return Math.round((t * 1000) / 100);
};

// parity of bend·1t against Luanti, in either results schema
const parityPct = (r: Results): number => {
  const p = r.parity?.lanes?.["bend·1t"]?.percent ?? r.parity?.percent;
  if (p === undefined) throw new Error("results have no parity for bend·1t");
  return Math.round(p * 100);
};

export function raceTxt(r: Results): string {
  return `luanti_us_per_mapchunk ${perChunkUs(r, "luanti·1t")}\nbend1_us_per_mapchunk ${perChunkUs(r, "bend·1t")}\n`
    + `bend8_us_per_mapchunk ${perChunkUs(r, "bend·8t")}\nparity_pct ${parityPct(r)}\ncommit ${r.commit}\n`;
}

// the newest arena race (never a live race: those are a different area and run count)
export function newest(dir = resolve(import.meta.dirname, "../results")): string {
  const files = readdirSync(dir).filter((f) => f.endsWith(".json") && !f.startsWith("live_")).sort().reverse();
  for (const f of files) {
    const r = JSON.parse(readFileSync(`${dir}/${f}`, "utf8")) as Results;
    if (r.kind !== "live" && r.params && r.lanes.some((l) => l.id === "luanti·1t" && l.terrain) && r.parity) return `${dir}/${f}`;
  }
  throw new Error("no results/*.json with a Luanti lane: run `node harness/arena.ts race` first");
}

if (import.meta.filename === process.argv[1]) {
  const src = process.argv[2] ?? newest();
  const dst = process.argv[3] ?? resolve(import.meta.dirname, "../out/race.txt");
  mkdirSync(dirname(dst), { recursive: true });
  writeFileSync(dst, raceTxt(JSON.parse(readFileSync(src, "utf8"))));
  console.log(`wrote ${dst} from ${src}`);
}
