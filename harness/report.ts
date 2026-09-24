// Results JSON (schema 1) and the terminal table.
import { execFileSync } from "node:child_process";
import { cpus, release } from "node:os";
import { readFileSync } from "node:fs";
import { summarize, type Summary } from "./lib/stats.ts";
import type { LaneRun } from "./lanes/bend.ts";
import type { Parity } from "./verify.ts";
import type { Conditions } from "./lib/conditions.ts";

export type LaneResult = { id: string; engine: "bend" | "luanti"; threads: number; runs: LaneRun[];
  terrain?: Summary; wall?: Summary; peakMb?: number };
export type Results = { schema: 1; date: string; commit: string; machine: Record<string, string | number>;
  versions: Record<string, string>; params: { seed: number; runs: number; threads: number[]; area: string };
  lanes: LaneResult[]; parity: { reference: string; lanes: Record<string, Parity> } | null; notes: string[];
  conditions?: Conditions };

const tryRun = (cmd: string, args: string[]) => {
  try { return execFileSync(cmd, args, { encoding: "utf8" }).trim().split("\n")[0]; } catch { return "unknown"; }
};

export function machine(): Record<string, string | number> {
  const os = /PRETTY_NAME="([^"]+)"/.exec(readFileSync("/etc/os-release", "utf8"))?.[1] ?? "unknown";
  return { cpu: cpus()[0]?.model ?? "unknown", threads: cpus().length, os, kernel: release() };
}

export function versions(bend: string, luanti: string | null): Record<string, string> {
  return { bend: tryRun(bend, ["version"]), luanti: luanti ? tryRun(luanti, ["--version"]) : "not run",
    clang: tryRun("clang", ["--version"]), gcc: tryRun("g++", ["--version"]), node: process.version };
}

export function commit(): string {
  const c = tryRun("git", ["rev-parse", "--short", "HEAD"]);
  return tryRun("git", ["status", "--porcelain", "--untracked-files=no"]) === "" ? c : `${c}-dirty`;
}

// fills terrain/wall summaries and peak memory from the successful runs
export function finish(l: LaneResult): LaneResult {
  const ok = l.runs.filter((r) => r.ok);
  if (ok.length === 0) return l;
  return { ...l, terrain: summarize(ok.map((r) => r.terrainMs)), wall: summarize(ok.map((r) => r.wallMs)),
    peakMb: Math.max(...ok.map((r) => r.peakKb)) / 1024 };
}

const f1 = (n: number) => n.toFixed(1);

export function table(res: Results): string {
  const c = res.conditions;
  const head = `World generation (terrain) · seed ${res.params.seed} · ${res.params.area} · ${res.machine.cpu}`
    + (c ? ` · power ${c.power}, governor ${c.governor}, load ${c.load1}` : "");
  const rows = [["lane", "terrain ms", "min", "max", "spread", "end-to-end ms", "peak MB", "terrain vs Luanti", "ok runs"]];
  for (const l of res.lanes) {
    const lu = res.lanes.find((x) => x.engine === "luanti" && x.threads === l.threads)?.terrain?.median;
    const t = l.terrain;
    // with several threads Luanti's terrain number is a sum of per-mapchunk thread time,
    // not wall time, so a ratio against Bend's wall time would mean nothing
    const vs = !t ? "-" : l.engine === "luanti" ? "reference" : l.threads > 1 ? "n/a (Luanti: thread time)"
      : lu ? `${(lu / t.median).toFixed(2)}× ${lu / t.median >= 1 ? "faster" : "slower"}` : "no Luanti lane";
    // Bend has no liquid step or emerge queue, so it has no end-to-end number to compare
    const e2e = l.engine === "bend" || !l.wall ? "-" : f1(l.wall.median);
    rows.push([l.id, t ? f1(t.median) : "FAILED", t ? f1(t.min) : "-", t ? f1(t.max) : "-", t ? `${f1(t.spreadPct)} %` : "-",
      e2e, l.peakMb ? f1(l.peakMb) : "-", vs, `${l.runs.filter((r) => r.ok).length}/${l.runs.length}`]);
  }
  const w = rows[0].map((_, i) => Math.max(...rows.map((r) => r[i].length)));
  const lines = rows.map((r) => r.map((c, i) => c.padEnd(w[i])).join("  "));
  const p = res.parity;
  const par = p ? Object.entries(p.lanes).map(([lane, q]) =>
    `parity (${lane} vs ${p.reference}): ${q.percent.toFixed(4)} % of ${q.columns} columns identical, ${q.mismatches} differ`)
    : ["parity: not checked (no Luanti reference dump)"];
  return [head, "", ...lines, "", ...par, ...res.notes.map((n) => `note: ${n}`)].join("\n");
}
