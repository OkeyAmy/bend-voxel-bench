// Bend lane: one fresh process of build/voxel per run.
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { run } from "../lib/exec.ts";

export type LaneRun = { ok: boolean; error?: string; wallMs: number; terrainMs: number; liquidMs: number; lightMs: number; peakKb: number; dump?: string };

// "mapgen_ms 1253" -> 1253
export function parseBendStdout(stdout: string): number {
  const m = /^mapgen_ms (\d+)$/m.exec(stdout);
  if (!m) throw new Error(`no mapgen_ms line in bend output: ${stdout.slice(0, 200)}`);
  return Number(m[1]);
}

export async function runBend(threads: number, seed: number, keepDump: boolean): Promise<LaneRun> {
  const dir = mkdtempSync(`${tmpdir()}/bvb-bend-`);
  const r = await run("build/voxel", ["--threads", String(threads), "--", "mapgen", String(seed), `${dir}/dump.txt`]);
  if (r.timedOut || r.code !== 0) {
    return { ok: false, error: r.timedOut ? "timeout" : `exit ${r.code}: ${r.stderr.slice(-500)}`, wallMs: r.wallMs, terrainMs: 0, liquidMs: 0, lightMs: 0, peakKb: r.peakKb };
  }
  const ms = parseBendStdout(r.stdout);
  // Bend Plan 1 generates terrain only: no liquid step, no lighting
  return { ok: true, wallMs: ms, terrainMs: ms, liquidMs: 0, lightMs: 0, peakKb: r.peakKb,
    dump: keepDump ? readFileSync(`${dir}/dump.txt`, "utf8") : undefined };
}
