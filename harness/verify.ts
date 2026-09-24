// Compares two world dumps. Each line: "x y z" then 6400 "stone water" pairs,
// one per column of that mapchunk in row-major order (z outer, x inner).

export type Mismatch = { chunk: string; column: number; bend: string; luanti: string };
export type Parity = { chunks: number; columns: number; mismatches: number; percent: number; missing: string[]; sample: Mismatch[] };

type Chunks = Map<string, string[]>;

export function parseDump(text: string): Chunks {
  const out: Chunks = new Map();
  for (const line of text.split("\n")) {
    const f = line.trim().split(/\s+/);
    if (f.length < 3 || f[0] === "") continue;
    if (f.length !== 3 + 2 * 6400) throw new Error(`dump line for ${f.slice(0, 3).join(" ")} has ${f.length} fields, want ${3 + 2 * 6400}`);
    const cols: string[] = [];
    for (let i = 3; i < f.length; i += 2) cols.push(`${f[i]} ${f[i + 1]}`);
    out.set(f.slice(0, 3).join(" "), cols);
  }
  return out;
}

export function compare(bendText: string, luantiText: string): Parity {
  const b = parseDump(bendText);
  const l = parseDump(luantiText);
  const keys = new Set([...b.keys(), ...l.keys()]);
  const missing: string[] = [];
  const sample: Mismatch[] = [];
  let columns = 0;
  let mismatches = 0;
  for (const k of [...keys].sort()) {
    const bc = b.get(k);
    const lc = l.get(k);
    if (!bc || !lc) {
      missing.push(`${k} (${bc ? "only in bend" : "only in luanti"})`);
      mismatches += 6400;
      columns += 6400;
      continue;
    }
    for (let i = 0; i < 6400; i++) {
      columns++;
      if (bc[i] !== lc[i]) {
        mismatches++;
        if (sample.length < 20) sample.push({ chunk: k, column: i, bend: bc[i], luanti: lc[i] });
      }
    }
  }
  const percent = columns === 0 ? 0 : ((columns - mismatches) / columns) * 100;
  return { chunks: keys.size, columns, mismatches, percent, missing, sample };
}
