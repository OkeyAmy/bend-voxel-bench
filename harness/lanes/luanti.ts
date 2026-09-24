// Luanti lane: one fresh luantiserver process on a fresh world per run.
import { cpSync, mkdtempSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { run } from "../lib/exec.ts";
import type { LaneRun } from "./bend.ts";

export const LUANTI = resolve("luanti/src/bin/luantiserver");

export type ChunkTimes = { count: number; outside: string[]; terrainUs: number; middleUs: number; liquidUs: number; lightUs: number };

// Sums the BVB_CHUNK lines the timing patch prints, and lists mapchunks outside the area.
export function parseChunkTimes(stderr: string): ChunkTimes {
  const t: ChunkTimes = { count: 0, outside: [], terrainUs: 0, middleUs: 0, liquidUs: 0, lightUs: 0 };
  const re = /^BVB_CHUNK (-?\d+) (-?\d+) (-?\d+) terrain_us=(\d+) middle_us=(\d+) liquid_us=(\d+) light_us=(\d+)$/gm;
  for (const m of stderr.matchAll(re)) {
    const [x, y, z] = [Number(m[1]), Number(m[2]), Number(m[3])];
    const inside = x >= -32 && x <= 288 && z >= -32 && z <= 288 && y >= -112 && y <= 128 && (x + 32) % 80 === 0 && (z + 32) % 80 === 0 && (y + 112) % 80 === 0;
    if (!inside) t.outside.push(`${x} ${y} ${z}`);
    t.count++;
    t.terrainUs += Number(m[4]);
    t.middleUs += Number(m[5]);
    t.liquidUs += Number(m[6]);
    t.lightUs += Number(m[7]);
  }
  return t;
}

// first line of bench_probe.txt: "emerge_us N errors E"
export function parseProbeHeader(text: string): { emergeUs: number; errors: number } {
  const m = /^emerge_us (\d+) errors (\d+)$/m.exec(text);
  if (!m) throw new Error(`bench_probe.txt has no header: ${text.slice(0, 120)}`);
  return { emergeUs: Number(m[1]), errors: Number(m[2]) };
}

export async function runLuanti(threads: number, seed: number, keepDump: boolean): Promise<LaneRun & { chunks: ChunkTimes }> {
  const dir = mkdtempSync(`${tmpdir()}/bvb-luanti-`);
  const world = `${dir}/world`;
  cpSync("luanti/world_template", world, { recursive: true });
  writeFileSync(`${dir}/bench.conf`, readFileSync("luanti/bench.conf.in", "utf8").replace("@THREADS@", String(threads)).replace("@SEED@", String(seed)));
  const r = await run(LUANTI, ["--config", `${dir}/bench.conf`, "--world", world, "--gameid", "devtest", "--logfile", `${dir}/debug.txt`], { timeoutMs: 600_000 });
  const chunks = parseChunkTimes(r.stderr);
  const fail = (error: string) => ({ ok: false, error, wallMs: r.wallMs, terrainMs: 0, liquidMs: 0, lightMs: 0, peakKb: r.peakKb, chunks });
  if (r.timedOut) return fail("timeout");
  if (r.code !== 0) return fail(`exit ${r.code}: ${r.stderr.slice(-500)}`);
  if (!existsSync(`${world}/bench_probe.txt`)) return fail("bench_probe.txt was not written");
  const probe = readFileSync(`${world}/bench_probe.txt`, "utf8");
  const head = parseProbeHeader(probe);
  if (head.errors > 0) return fail(`${head.errors} blocks failed to emerge`);
  if (chunks.count !== 100 || chunks.outside.length > 0) return fail(`generated ${chunks.count} mapchunks, outside the area: ${chunks.outside.join(", ") || "none"}`);
  return { ok: true, wallMs: head.emergeUs / 1000, terrainMs: chunks.terrainUs / 1000, liquidMs: chunks.liquidUs / 1000, lightMs: chunks.lightUs / 1000,
    peakKb: r.peakKb, chunks, dump: keepDump ? probe.split("\n").slice(1).join("\n") : undefined };
}
