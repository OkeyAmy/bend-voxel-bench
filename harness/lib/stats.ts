// Small statistics helpers for benchmark runs.

export function median(xs: number[]): number {
  if (xs.length === 0) throw new Error("median of empty list");
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

// (max - min) / min, as a percentage
export function spreadPct(xs: number[]): number {
  if (xs.length === 0) throw new Error("spread of empty list");
  const lo = Math.min(...xs);
  const hi = Math.max(...xs);
  return lo === 0 ? 0 : ((hi - lo) / lo) * 100;
}

export type Summary = { median: number; min: number; max: number; spreadPct: number };

export function summarize(xs: number[]): Summary {
  return { median: median(xs), min: Math.min(...xs), max: Math.max(...xs), spreadPct: spreadPct(xs) };
}
