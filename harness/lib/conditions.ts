// The machine's state when a benchmark ran: power source, CPU governor, load.
// Battery power and background load both change results (see docs/bend-notes.md),
// so every result records them. `root` is "/" except in tests.
import { existsSync, readdirSync, readFileSync } from "node:fs";

export type Conditions = { power: "ac" | "battery" | "unknown"; governor: string; load1: number };

const read = (path: string): string | null => {
  try { return readFileSync(path, "utf8").trim(); } catch { return null; }
};

// a mains adapter exposes "online": 1 on AC, 0 on battery (batteries have no such file)
function power(root: string): Conditions["power"] {
  const dir = `${root}/sys/class/power_supply`;
  if (!existsSync(dir)) return "unknown";
  for (const name of readdirSync(dir)) {
    const online = read(`${dir}/${name}/online`);
    if (online === "1") return "ac";
    if (online === "0") return "battery";
  }
  return "unknown";
}

export function conditions(root = "/"): Conditions {
  const load = read(`${root}/proc/loadavg`);
  return {
    power: power(root),
    governor: read(`${root}/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`) ?? "unknown",
    load1: load === null ? -1 : Number(load.split(/\s+/)[0]),
  };
}
