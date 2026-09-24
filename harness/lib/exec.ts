// Runs a command under /usr/bin/time -v and returns its output, wall time and peak memory.
import { spawn } from "node:child_process";

export type Ran = { code: number; stdout: string; stderr: string; wallMs: number; peakKb: number; timedOut: boolean };

// "Maximum resident set size (kbytes): 123" -> 123 (0 when absent)
export function parsePeakKb(stderr: string): number {
  const m = /Maximum resident set size \(kbytes\): (\d+)/.exec(stderr);
  return m ? Number(m[1]) : 0;
}

export function run(cmd: string, args: string[], opts: { cwd?: string; timeoutMs?: number } = {}): Promise<Ran> {
  return new Promise((resolve, reject) => {
    const t0 = performance.now();
    // own process group, so a timeout kills the measured command too, not just /usr/bin/time
    const kid = spawn("/usr/bin/time", ["-v", cmd, ...args], { cwd: opts.cwd, stdio: ["ignore", "pipe", "pipe"], detached: true });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    kid.stdout.on("data", (d) => (stdout += d));
    kid.stderr.on("data", (d) => (stderr += d));
    const timer = setTimeout(() => {
      timedOut = true;
      try { process.kill(-kid.pid!, "SIGKILL"); } catch { kid.kill("SIGKILL"); }
    }, opts.timeoutMs ?? 300_000);
    kid.on("error", reject);
    kid.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? -1, stdout, stderr, wallMs: performance.now() - t0, peakKb: parsePeakKb(stderr), timedOut });
    });
  });
}
