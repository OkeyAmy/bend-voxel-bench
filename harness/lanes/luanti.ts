// Luanti lane: one fresh luantiserver process on a fresh world per run.
import { cpSync, mkdtempSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { run } from "../lib/exec.ts";
import type { LaneRun } from "./bend.ts";

const ROOT = resolve(import.meta.dirname, "../..");
// LUANTI in the environment overrides the path (tests use it to simulate a missing build)
export const LUANTI = process.env.LUANTI ?? resolve(ROOT, "luanti/src/bin/luantiserver");

export type ChunkTimes = { count: number; outside: string[]; terrainUs: number; middleUs: number; liquidUs: number; lightUs: number };

// Sums the BVB_CHUNK lines the timing patch prints, and lists mapchunks outside the area.
export function parseChunkTimes(stderr: string, ox = -32, oz = -32): ChunkTimes {
  const t: ChunkTimes = { count: 0, outside: [], terrainUs: 0, middleUs: 0, liquidUs: 0, lightUs: 0 };
  const re = /^BVB_CHUNK (-?\d+) (-?\d+) (-?\d+) terrain_us=(\d+) middle_us=(\d+) liquid_us=(\d+) light_us=(\d+)$/gm;
  for (const m of stderr.matchAll(re)) {
    const [x, y, z] = [Number(m[1]), Number(m[2]), Number(m[3])];
    const inside = x >= ox && x <= ox + 320 && z >= oz && z <= oz + 320 && y >= -112 && y <= 128
      && (x - ox) % 80 === 0 && (z - oz) % 80 === 0 && (y + 112) % 80 === 0;
    if (!inside) t.outside.push(`${x} ${y} ${z}`);
    t.count++;
    t.terrainUs += Number(m[4]);
    t.middleUs += Number(m[5]);
    t.liquidUs += Number(m[6]);
    t.lightUs += Number(m[7]);
  }
  return t;
}

// first line of bench_probe.txt: "emerge_us N errors E cancelled C passes P".
// cancelled: blocks another emerge thread was already generating (normal with
// several threads); the probe re-emerges until a pass has none, then stops the clock.
export function parseProbeHeader(text: string): { emergeUs: number; errors: number; cancelled: number; passes: number } {
  const m = /^emerge_us (\d+) errors (\d+) cancelled (\d+) passes (\d+)$/m.exec(text);
  if (!m) throw new Error(`bench_probe.txt has no header: ${text.slice(0, 120)}`);
  return { emergeUs: Number(m[1]), errors: Number(m[2]), cancelled: Number(m[3]), passes: Number(m[4]) };
}

// bench.conf.in with @THREADS@, @SEED@, @X0@ and @Z0@ filled in
export function renderConf(template: string, threads: number, seed: number, ox = -32, oz = -32): string {
  return template.replaceAll("@THREADS@", String(threads)).replaceAll("@SEED@", String(seed))
    .replaceAll("@X0@", String(ox)).replaceAll("@Z0@", String(oz));
}

// the "seed = N" line of a world's map_meta.txt (null when absent)
export function mapMetaSeed(mapMeta: string): string | null {
  return /^seed = (\d+)$/m.exec(mapMeta)?.[1] ?? null;
}

export async function runLuanti(threads: number, seed: number, keepDump: boolean, ox = -32, oz = -32): Promise<LaneRun & { chunks: ChunkTimes }> {
  const dir = mkdtempSync(`${tmpdir()}/bvb-luanti-`);
  const world = `${dir}/world`;
  cpSync(resolve(ROOT, "luanti/world_template"), world, { recursive: true });
  writeFileSync(`${dir}/bench.conf`, renderConf(readFileSync(resolve(ROOT, "luanti/bench.conf.in"), "utf8"), threads, seed, ox, oz));
  const r = await run(LUANTI, ["--config", `${dir}/bench.conf`, "--world", world, "--gameid", "devtest", "--logfile", `${dir}/debug.txt`], { timeoutMs: 600_000 });
  const chunks = parseChunkTimes(r.stderr, ox, oz);
  const fail = (error: string) => ({ ok: false, error, wallMs: r.wallMs, terrainMs: 0, liquidMs: 0, lightMs: 0, peakKb: r.peakKb, chunks });
  if (r.timedOut) return fail("timeout");
  if (r.code !== 0) return fail(`exit ${r.code}: ${r.stderr.slice(-500)}`);
  if (!existsSync(`${world}/bench_probe.txt`)) return fail("bench_probe.txt was not written");
  // the world must have been generated from the seed we asked for (Luanti stores it as u64)
  const usedSeed = existsSync(`${world}/map_meta.txt`) ? mapMetaSeed(readFileSync(`${world}/map_meta.txt`, "utf8")) : null;
  const wantSeed = BigInt.asUintN(64, BigInt(seed)).toString();
  if (usedSeed !== wantSeed) return fail(`world seed is ${usedSeed ?? "missing"}, expected ${wantSeed}`);
  const probe = readFileSync(`${world}/bench_probe.txt`, "utf8");
  const head = parseProbeHeader(probe);
  if (head.errors > 0) return fail(`${head.errors} blocks failed to emerge`);
  if (chunks.count !== 100 || chunks.outside.length > 0) return fail(`generated ${chunks.count} mapchunks, outside the area: ${chunks.outside.join(", ") || "none"}`);
  return { ok: true, wallMs: head.emergeUs / 1000, terrainMs: chunks.terrainUs / 1000, liquidMs: chunks.liquidUs / 1000, lightMs: chunks.lightUs / 1000,
    peakKb: r.peakKb, chunks, dump: keepDump ? probe.split("\n").slice(1).join("\n") : undefined };
}
